//
//  JSONLinesPipeHandler.swift
//  boringNotch
//
//  SPDX-License-Identifier: GPL-3.0-only
//
//  Shared source compiled into BOTH targets (via the Shared synchronized
//  group). There is intentionally one copy — edit once, both sides build it.
//

import Foundation

/// Streams newline-delimited JSON from a pipe, decoding each line.
/// Used by the app (mediaremote-adapter now-playing stream) and the XPC
/// helper (Lunar daemon event stream).
///
/// Reads whole chunks (whatever the kernel has buffered) and splits them on
/// `\n` here instead of appending one byte at a time: adapter payloads carry
/// base64 artwork of 100-500 KB per track change. Adapted from upstream
/// PR 1611 (TheBoredTeam/boring.notch), not yet merged there.
actor JSONLinesPipeHandler {
    nonisolated let outputPipe: Pipe
    nonisolated let fileHandle: FileHandle
    /// Consumed once; nil after `readJSONLines` starts (an AsyncStream must
    /// not be iterated twice).
    private var chunks: AsyncStream<Data>?
    private var consecutiveMalformedLines = 0

    /// A line longer than this counts as a malformed line instead of growing
    /// the buffer without bound.
    static let maxLineBytes = 8 * 1024 * 1024

    init(pipe: Pipe = Pipe()) {
        outputPipe = pipe
        fileHandle = pipe.fileHandleForReading
        chunks = Self.makeChunkStream(fileHandle)
    }

    private static func makeChunkStream(_ handle: FileHandle) -> AsyncStream<Data> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            handle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { // EOF
                    handle.readabilityHandler = nil
                    continuation.finish()
                    return
                }
                continuation.yield(data)
            }
            // Fires on cancellation, early return and finish, so the dispatch
            // source never outlives the read.
            continuation.onTermination = { _ in
                handle.readabilityHandler = nil
            }
        }
    }

    func readJSONLines<Value: Decodable & Sendable>(
        as type: Value.Type,
        onValue: @escaping @Sendable (Value) async -> Void
    ) async {
        guard let chunks else { return }
        self.chunks = nil

        var buffer = Data()
        let decoder = JSONDecoder()

        for await chunk in chunks {
            guard !Task.isCancelled else { return }
            // Only the new bytes can hold a newline the last pass did not see.
            var searchFrom = buffer.count
            buffer.append(chunk)

            while let newline = buffer[(buffer.startIndex + searchFrom)...].firstIndex(of: UInt8(ascii: "\n")) {
                var line = buffer[buffer.startIndex ..< newline]
                if line.last == UInt8(ascii: "\r") {
                    line = line.dropLast()
                }
                let decoded = line.isEmpty ? nil : try? decoder.decode(Value.self, from: Data(line))
                buffer.removeSubrange(buffer.startIndex ... newline)
                searchFrom = 0

                guard let decoded else {
                    consecutiveMalformedLines += 1
                    if consecutiveMalformedLines >= 3 {
                        return
                    }
                    continue
                }

                consecutiveMalformedLines = 0
                await onValue(decoded)
                guard !Task.isCancelled else { return }
            }

            if buffer.count > Self.maxLineBytes {
                consecutiveMalformedLines += 1
                buffer.removeAll(keepingCapacity: false)
                if consecutiveMalformedLines >= 3 {
                    return
                }
            }
        }
        // EOF: a trailing line without a newline is dropped, as before.
    }

    nonisolated func close() {
        fileHandle.readabilityHandler = nil
        try? fileHandle.close()
        try? outputPipe.fileHandleForWriting.close()
    }
}

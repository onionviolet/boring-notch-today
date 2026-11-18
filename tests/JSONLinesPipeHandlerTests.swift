import Foundation

// swiftc -parse-as-library Shared/JSONLinesPipeHandler.swift tests/JSONLinesPipeHandlerTests.swift -o work/pipe-tests && work/pipe-tests

struct Item: Decodable, Sendable, Equatable { let id: Int; let art: String? }

actor Collector {
    var items: [Item] = []
    func add(_ item: Item) { items.append(item) }
}

@main struct JSONLinesPipeHandlerTests {
    /// Writes `payload` in `chunk`-byte pieces, closes the pipe, returns what was decoded.
    static func run(_ payload: Data, chunk: Int) async -> [Item] {
        let handler = JSONLinesPipeHandler()
        let collector = Collector()
        let writer = handler.outputPipe.fileHandleForWriting
        let reading = Task { await handler.readJSONLines(as: Item.self) { await collector.add($0) } }
        // Write off the cooperative pool: a pipe holds 64 KB and blocks beyond it.
        Thread.detachNewThread {
            var offset = 0
            while offset < payload.count {
                let end = min(offset + chunk, payload.count)
                writer.write(payload.subdata(in: offset ..< end))
                offset = end
            }
            try? writer.close()
        }
        await reading.value
        return await collector.items
    }

    static func main() async {
        let art = String(repeating: "A", count: 400_000)
        let big = "{\"id\":2,\"art\":\"\(art)\"}"

        // Lines split across chunks, CRLF, a blank line and one bad line between good ones.
        let mixed = Data("{\"id\":1}\r\n\n\(big)\nnot json\n{\"id\":3}\n{\"id\":4}".utf8)
        for chunk in [1, 7, 4096, 1 << 20] {
            let got = await run(mixed, chunk: chunk)
            precondition(got.map(\.id) == [1, 2, 3], "chunk \(chunk): \(got.map(\.id))")
            precondition(got[1].art?.count == 400_000)
        }

        // Three malformed lines in a row end the read; a good line resets the count.
        let stops = await run(Data("{\"id\":1}\nx\ny\n{\"id\":2}\nx\ny\nz\n{\"id\":3}\n".utf8), chunk: 5)
        precondition(stops.map(\.id) == [1, 2], "\(stops.map(\.id))")

        // An over-long line is dropped as malformed without unbounded growth.
        var huge = Data(repeating: UInt8(ascii: "B"), count: JSONLinesPipeHandler.maxLineBytes + 1024)
        huge.append(Data("\n{\"id\":9}\n".utf8))
        let afterHuge = await run(huge, chunk: 1 << 16)
        precondition(afterHuge.map(\.id) == [9], "\(afterHuge.map(\.id))")

        print("JSONLinesPipeHandlerTests passed")
    }
}

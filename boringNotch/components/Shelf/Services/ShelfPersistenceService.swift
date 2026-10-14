//
//  ShelfPersistenceService.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import Foundation

// Access model types
@_exported import struct Foundation.URL

final class ShelfPersistenceService {
    static let shared = ShelfPersistenceService()

    private let writeQueue = DispatchQueue(label: "BoringNotch.ShelfPersistence", qos: .utility)
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            encoder.outputFormatting = [.prettyPrinted]
            decoder.dateDecodingStrategy = .iso8601
            encoder.dateEncodingStrategy = .iso8601
            return
        }
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (support ?? fm.temporaryDirectory).appendingPathComponent("boringNotch", isDirectory: true).appendingPathComponent("Shelf", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("items.json")
        encoder.outputFormatting = [.prettyPrinted]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func load() -> [ShelfItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        // Try to decode as array first (normal case)
        if let items = try? decoder.decode([ShelfItem].self, from: data) {
            return items
        }

        // If array decoding fails, try to decode individual items
        do {
            // Parse as JSON array to get individual item data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                Log.shelf.error("⚠️ Shelf persistence file is not a valid JSON array")
                return []
            }

            var validItems: [ShelfItem] = []
            var failedCount = 0

            for (index, jsonItem) in jsonArray.enumerated() {
                do {
                    let itemData = try JSONSerialization.data(withJSONObject: jsonItem)
                    let item = try decoder.decode(ShelfItem.self, from: itemData)
                    validItems.append(item)
                } catch {
                    failedCount += 1
                    Log.shelf.error("⚠️ Failed to decode shelf item at index \(index): \(error.localizedDescription)")
                }
            }

            if failedCount > 0 {
                Log.shelf.error("📦 Successfully loaded \(validItems.count) shelf items, discarded \(failedCount) corrupted items")
            }

            return validItems
        } catch {
            Log.shelf.error("❌ Failed to parse shelf persistence file: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ items: [ShelfItem]) {
        do {
            let data = try encoder.encode(items)
            try writeQueue.sync { try data.write(to: fileURL, options: .atomic) }
        } catch {
            Log.shelf.error("Failed to save shelf items: \(error.localizedDescription)")
        }
    }

    @MainActor
    func saveAsync(_ items: [ShelfItem]) async {
        do {
            // Encode before suspension. FIFO writes keep an older async save from
            // overtaking a newer snapshot or the synchronous shutdown flush.
            let data = try encoder.encode(items)
            await withCheckedContinuation { continuation in
                writeQueue.async { [fileURL] in
                    do { try data.write(to: fileURL, options: .atomic) }
                    catch { Log.shelf.error("Failed to save shelf items: \(error.localizedDescription)") }
                    continuation.resume()
                }
            }
        } catch { Log.shelf.error("Failed to encode shelf items: \(error.localizedDescription)") }
    }
}

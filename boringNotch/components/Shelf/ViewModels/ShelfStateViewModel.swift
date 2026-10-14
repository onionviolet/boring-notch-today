//
//  ShelfStateViewModel.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-09.

import Foundation
import AppKit

@MainActor
final class ShelfStateViewModel: ObservableObject {
    static let shared = ShelfStateViewModel()

    @Published private(set) var items: [ShelfItem] = [] {
        didSet { if hasLoaded, items != oldValue { schedulePersistence() } }
    }

    @Published var isLoading: Bool = false

    var isEmpty: Bool { items.isEmpty }

    // Debounced persistence
    private var hasLoaded = false
    private var cleanupTask: Task<Void, Never>?
    private var persistenceTask: Task<Void, Never>?
    private let persistenceDelay: Duration = .seconds(1)

    private let persistence: ShelfPersistenceService
    private let validateBookmark: (Data) async -> Bool

    init(persistence: ShelfPersistenceService = .shared,
         validateBookmark: @escaping (Data) async -> Bool = { await Bookmark(data: $0).validate() }) {
        self.persistence = persistence
        self.validateBookmark = validateBookmark
        items = persistence.load()
        hasLoaded = true
    }

    private func schedulePersistence() {
        persistenceTask?.cancel()
        persistenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.persistenceDelay ?? .seconds(1))
            guard let self = self, !Task.isCancelled else { return }
            await self.persistence.saveAsync(self.items)
        }
    }

    func add(_ newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        var merged = items
        // Deduplicate by identityKey while preserving order (existing first)
        var seen: Set<String> = Set(merged.map { $0.identityKey })
        for it in newItems {
            let key = it.identityKey
            if !seen.contains(key) {
                merged.append(it)
                seen.insert(key)
            }
        }
        if items != merged { items = merged }
    }

    func remove(_ item: ShelfItem) {
        item.cleanupStoredData()
        items.removeAll { $0.id == item.id }
    }

    func updateBookmark(for item: ShelfItem, bookmark: Data) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if case .file(let previous) = items[idx].kind, previous != bookmark {
            items[idx] = ShelfItem(id: items[idx].id, kind: .file(bookmark: bookmark), isTemporary: items[idx].isTemporary)
        }
    }

    func load(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        isLoading = true
        Task { [weak self] in
            let dropped = await ShelfDropService.items(from: providers)
            await MainActor.run {
                self?.add(dropped)
                self?.isLoading = false
            }
        }
    }

    func cleanupInvalidItems() {
        guard cleanupTask == nil else { return }
        cleanupTask = Task { [weak self] in
            guard let self else { return }
            defer { self.cleanupTask = nil }
            let snapshot = self.items
            var invalid: [ShelfItem] = []
            for item in snapshot {
                if case .file(let data) = item.kind,
                   !(await self.validateBookmark(data)) { invalid.append(item) }
            }
            // Reconcile removals against current values. A refreshed bookmark or
            // new drop during validation is newer than this snapshot and survives.
            let removed = self.items.filter { invalid.contains($0) }
            guard !removed.isEmpty else { return }
            removed.forEach { $0.cleanupStoredData() }
            self.items.removeAll { removed.contains($0) }
        }
    }

    /// Resolves the file URL for an item and updates the bookmark if stale.
    /// Use this for user-initiated actions where bookmark refresh is desired.
    func resolveAndUpdateBookmark(for item: ShelfItem) -> URL? {
        guard case .file(let bookmarkData) = item.kind else { return nil }
        let bookmark = Bookmark(data: bookmarkData)
        let result = bookmark.resolve()
        if let refreshed = result.refreshedData, refreshed != bookmarkData {
            NSLog("Bookmark for \(item) stale; refreshing")
            updateBookmark(for: item, bookmark: refreshed)
        }
        return result.url
    }

    func resolveFileURLs(for items: [ShelfItem]) -> [URL] {
        items.compactMap { $0.fileURL }
    }

    @MainActor
    func flushSync() {
        // Cancel any scheduled persistence task (we'll save synchronously now)
        persistenceTask?.cancel()
        persistenceTask = nil

        // Perform a synchronous, atomic save to disk
        persistence.save(self.items)
    }
}

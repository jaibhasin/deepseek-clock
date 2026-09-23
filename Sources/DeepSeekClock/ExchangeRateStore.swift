//
//  ExchangeRateStore.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Remembers the last good `ExchangeRates` snapshot on disk.                    │
//  │                                                                              │
//  │ Why cache at all? It keeps the app useful without a network connection and    │
//  │ avoids a request on every launch - we only refetch once the snapshot is 12   │
//  │ hours old.                                                                   │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import Foundation

/// Persists a single `ExchangeRates` snapshot in `UserDefaults` as JSON.
struct ExchangeRateStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "exchangeRates") {
        self.defaults = defaults
        self.key = key
    }

    /// The cached snapshot, or `nil` if none has ever been stored.
    func load() -> ExchangeRates? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ExchangeRates.self, from: data)
    }

    /// Stores the newest snapshot, replacing any previous one.
    func save(_ rates: ExchangeRates) {
        guard let data = try? JSONEncoder().encode(rates) else { return }
        defaults.set(data, forKey: key)
    }
}

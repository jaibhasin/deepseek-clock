//
//  ExchangeRates.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Fetches the latest USD exchange rates so prices can be shown in the user's    │
//  │ chosen currency.                                                             │
//  │                                                                              │
//  │ DESIGN: an immutable `ExchangeRates` snapshot plus an injectable              │
//  │ `ExchangeRateService`. The model depends on the protocol, so tests use a      │
//  │ stub and never hit the network.                                              │
//  │                                                                              │
//  │ The snapshot is cached on disk (`ExchangeRateStore`) so the app still shows   │
//  │ sensible prices offline and only refetches when the data is 12 hours old.     │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
//  DATA SOURCE
//  -----------
//  https://www.exchangerate-api.com/ - the free, key-less "open access" endpoint
//      GET https://open.er-api.com/v6/latest/USD
//
//  It returns a JSON object whose `rates` map is "units of currency per 1 USD".
import Foundation

/// An immutable snapshot of "how many units of each currency one US dollar buys",
/// together with when the upstream provider last updated it.
struct ExchangeRates: Codable, Equatable {
    /// The base currency the rates are quoted in. Always `"USD"` for us.
    let baseCode: String

    /// Currency code → units per 1 USD, e.g. `["INR": 83.4, "EUR": 0.92]`.
    let rates: [String: Double]

    /// When the provider says the rates were last refreshed.
    let updatedAt: Date

    /// The multiplier to convert a USD amount into `code`, if known.
    func rate(for code: String) -> Decimal? {
        guard let value = rates[code] else { return nil }
        // Go through the string form to avoid `Double`'s binary rounding noise.
        return Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Whether the snapshot is old enough to justify a refetch.
    func isStale(now: Date, maximumAge: TimeInterval = 12 * 60 * 60) -> Bool {
        now.timeIntervalSince(updatedAt) > maximumAge
    }
}

/// Anything that can fetch fresh exchange rates.
///
/// Kept small and asynchronous so the real implementation can use `URLSession`
/// while tests inject a stub that returns instantly.
protocol ExchangeRateService {
    /// Fetches the latest USD-based rates, or throws if the request fails.
    func fetchLatest() async throws -> ExchangeRates
}

/// The network-backed implementation.
final class LiveExchangeRateService: ExchangeRateService {

    /// The free endpoint: no API key, refreshed daily, returns every major
    /// currency in one request.
    private static let endpoint = URL(string: "https://open.er-api.com/v6/latest/USD")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLatest() async throws -> ExchangeRates {
        var request = URLRequest(url: Self.endpoint)
        request.timeoutInterval = 15
        // Never serve a stale cached response: the whole point is fresher data.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ExchangeRateError.badResponse
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.result == "success" else {
            throw ExchangeRateError.providerError(payload.errorType ?? "unknown")
        }

        return ExchangeRates(
            baseCode: payload.baseCode,
            rates: payload.rates,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(payload.lastUpdateUnix))
        )
    }

    // MARK: - Wire format

    private struct Payload: Decodable {
        let result: String
        let baseCode: String
        let lastUpdateUnix: Int
        let rates: [String: Double]
        let errorType: String?

        enum CodingKeys: String, CodingKey {
            case result
            case baseCode = "base_code"
            case lastUpdateUnix = "time_last_update_unix"
            case rates
            case errorType = "error-type"
        }
    }
}

/// Why a rate refresh failed. Deliberately coarse: the UI only needs to know that
/// it should keep showing the last good snapshot.
enum ExchangeRateError: Error {
    case badResponse
    case providerError(String)
}

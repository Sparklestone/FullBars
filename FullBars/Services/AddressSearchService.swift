import Foundation
import MapKit
import Observation

/// Provides address autocomplete suggestions using Apple's MKLocalSearchCompleter.
/// No API key required — uses the same backend as Apple Maps.
@Observable
@MainActor
final class AddressSearchService: NSObject {
    /// The current search query (bind to a TextField).
    var query: String = "" {
        didSet {
            if query.isEmpty {
                suggestions = []
            } else {
                completer.queryFragment = query
            }
        }
    }

    /// Address suggestions updated as the user types.
    var suggestions: [AddressSuggestion] = []

    /// Whether a search is in progress.
    var isSearching: Bool = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Prioritize addresses over points of interest
        completer.pointOfInterestFilter = .excludingAll
    }

    /// Resolve a selected suggestion into a full address string + ZIP code.
    func resolve(_ suggestion: AddressSuggestion) async -> ResolvedAddress? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            guard let item = response.mapItems.first, let placemark = item.placemark as? MKPlacemark else {
                return nil
            }

            let street = [placemark.subThoroughfare, placemark.thoroughfare]
                .compactMap { $0 }
                .joined(separator: " ")
            let city = placemark.locality ?? ""
            let state = placemark.administrativeArea ?? ""
            let zip = placemark.postalCode ?? ""

            var parts: [String] = []
            if !street.isEmpty { parts.append(street) }
            if !city.isEmpty { parts.append(city) }
            if !state.isEmpty { parts.append(state) }
            if !zip.isEmpty { parts.append(zip) }

            return ResolvedAddress(
                fullAddress: parts.joined(separator: ", "),
                street: street,
                city: city,
                state: state,
                zipCode: zip
            )
        } catch {
            return nil
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension AddressSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results.map { result in
                AddressSuggestion(
                    title: result.title,
                    subtitle: result.subtitle,
                    completion: result
                )
            }
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }
}

// MARK: - Models

struct AddressSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion
}

struct ResolvedAddress {
    let fullAddress: String
    let street: String
    let city: String
    let state: String
    let zipCode: String
}

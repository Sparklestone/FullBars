import Foundation

/// Controls the visualization complexity throughout the app.
/// Basic mode is consumer-friendly; Technical mode shows all raw metrics.
enum DisplayMode: String, CaseIterable, Codable {
    case basic
    case technical

    var label: String {
        switch self {
        case .basic: return "Basic"
        case .technical: return "Technical"
        }
    }

    var icon: String {
        switch self {
        case .basic: return "eye"
        case .technical: return "waveform.path.ecg.rectangle"
        }
    }
}

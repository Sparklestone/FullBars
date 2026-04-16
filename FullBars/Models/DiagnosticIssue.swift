import Foundation
import SwiftUI

enum IssueSeverity: String, CaseIterable, Codable, Comparable {
    case info
    case warning
    case critical

    // Comparable: info < warning < critical
    static func < (lhs: IssueSeverity, rhs: IssueSeverity) -> Bool {
        let order: [IssueSeverity] = [.info, .warning, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
    
    var color: Color {
        switch self {
        case .critical:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .critical:
            return "exclamationmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var label: String {
        switch self {
        case .critical:
            return "Critical"
        case .warning:
            return "Warning"
        case .info:
            return "Info"
        }
    }
}

enum IssueCategory: String, CaseIterable, Codable {
    case signalStrength
    case latency
    case packetLoss
    case congestion
    case interference
    case speed
    case general
}

struct DiagnosticIssue: Identifiable, Codable {
    var id: UUID
    var title: String
    var description: String
    var severity: IssueSeverity
    var category: IssueCategory
    var suggestion: String
    var detectedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String = "",
        description: String = "",
        severity: IssueSeverity = .info,
        category: IssueCategory = .general,
        suggestion: String = "",
        detectedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.severity = severity
        self.category = category
        self.suggestion = suggestion
        self.detectedAt = detectedAt
    }
}

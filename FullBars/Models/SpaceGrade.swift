import Foundation
import SwiftData
import SwiftUI

// MARK: - Grade Letter

enum GradeLetter: String, Codable, CaseIterable {
    case A, B, C, D, F

    var color: Color {
        switch self {
        case .A: return .green
        case .B: return FullBars.Design.Colors.accentCyan
        case .C: return .yellow
        case .D: return .orange
        case .F: return .red
        }
    }

    var summary: String {
        switch self {
        case .A: return "Exceptional"
        case .B: return "Good"
        case .C: return "Adequate"
        case .D: return "Poor"
        case .F: return "Failing"
        }
    }

    var basicDescription: String {
        switch self {
        case .A: return "This space has excellent WiFi coverage with strong signal everywhere."
        case .B: return "This space has good WiFi with only minor weak spots."
        case .C: return "This space has adequate WiFi but some areas have noticeable issues."
        case .D: return "This space has poor WiFi with significant weak spots or speed problems."
        case .F: return "This space has major WiFi connectivity issues throughout."
        }
    }

    static func from(score: Double) -> GradeLetter {
        switch score {
        case 90...100: return .A
        case 80..<90:  return .B
        case 70..<80:  return .C
        case 60..<70:  return .D
        default:       return .F
        }
    }
}

// MARK: - Category Scores

struct GradeCategoryScore: Codable, Identifiable {
    var id: String { category }
    let category: String
    let score: Double
    let weight: Double
    let details: String

    var weightedScore: Double { score * weight }

    var color: Color {
        GradeLetter.from(score: score).color
    }
}

// MARK: - Room Grade

struct RoomGrade: Codable, Identifiable {
    var id: String { name }
    let name: String
    let score: Double
    let pointCount: Int
    let averageSignal: Int
    let averageLatency: Double

    var grade: GradeLetter { GradeLetter.from(score: score) }
}

// MARK: - Space Grade (SwiftData Model)

@Model
final class SpaceGrade {
    var id: UUID
    var sessionId: UUID
    var timestamp: Date
    var overallScore: Double
    var signalCoverageScore: Double
    var speedPerformanceScore: Double
    var reliabilityScore: Double
    var latencyScore: Double
    var interferenceScore: Double
    var pointCount: Int
    var durationSeconds: Double
    var averageSignalStrength: Int
    var averageLatency: Double
    var averageDownloadSpeed: Double

    // Stored as JSON
    var roomGradesJSON: Data?

    init(
        id: UUID = UUID(),
        sessionId: UUID = UUID(),
        timestamp: Date = .now,
        overallScore: Double = 0,
        signalCoverageScore: Double = 0,
        speedPerformanceScore: Double = 0,
        reliabilityScore: Double = 0,
        latencyScore: Double = 0,
        interferenceScore: Double = 0,
        pointCount: Int = 0,
        durationSeconds: Double = 0,
        averageSignalStrength: Int = 0,
        averageLatency: Double = 0,
        averageDownloadSpeed: Double = 0,
        roomGradesJSON: Data? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.overallScore = overallScore
        self.signalCoverageScore = signalCoverageScore
        self.speedPerformanceScore = speedPerformanceScore
        self.reliabilityScore = reliabilityScore
        self.latencyScore = latencyScore
        self.interferenceScore = interferenceScore
        self.pointCount = pointCount
        self.durationSeconds = durationSeconds
        self.averageSignalStrength = averageSignalStrength
        self.averageLatency = averageLatency
        self.averageDownloadSpeed = averageDownloadSpeed
        self.roomGradesJSON = roomGradesJSON
    }

    var grade: GradeLetter { GradeLetter.from(score: overallScore) }

    var categoryScores: [GradeCategoryScore] {
        [
            GradeCategoryScore(category: "Signal Coverage", score: signalCoverageScore, weight: 0.30, details: "Percentage of points with good signal"),
            GradeCategoryScore(category: "Speed", score: speedPerformanceScore, weight: 0.25, details: "Average speed relative to thresholds"),
            GradeCategoryScore(category: "Reliability", score: reliabilityScore, weight: 0.20, details: "Packet loss & jitter assessment"),
            GradeCategoryScore(category: "Latency", score: latencyScore, weight: 0.15, details: "Average & worst-case latency"),
            GradeCategoryScore(category: "Interference", score: interferenceScore, weight: 0.10, details: "BLE congestion & competing networks")
        ]
    }

    var roomGrades: [RoomGrade] {
        guard let data = roomGradesJSON else { return [] }
        return (try? JSONDecoder().decode([RoomGrade].self, from: data)) ?? []
    }
}

// MARK: - Saved Walkthrough Session

@Model
final class WalkthroughSession {
    var id: UUID
    var timestamp: Date
    var durationSeconds: Double
    var pointCount: Int
    var gradeId: UUID?

    // Floor plan bounds
    var minX: Double
    var maxX: Double
    var minY: Double
    var maxY: Double

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        durationSeconds: Double = 0,
        pointCount: Int = 0,
        gradeId: UUID? = nil,
        minX: Double = 0,
        maxX: Double = 0,
        minY: Double = 0,
        maxY: Double = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
        self.pointCount = pointCount
        self.gradeId = gradeId
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }
}

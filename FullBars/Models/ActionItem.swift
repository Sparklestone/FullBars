import Foundation
import SwiftData
import SwiftUI

@Model
final class ActionItem {
    var id: UUID
    var title: String
    var itemDescription: String
    var priority: Int
    var isCompleted: Bool
    var createdAt: Date
    var relatedIssueTitle: String
    
    init(
        id: UUID = UUID(),
        title: String = "",
        itemDescription: String = "",
        priority: Int = 2,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        relatedIssueTitle: String = ""
    ) {
        self.id = id
        self.title = title
        self.itemDescription = itemDescription
        self.priority = priority
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.relatedIssueTitle = relatedIssueTitle
    }
    
    var priorityLabel: String {
        switch priority {
        case 1:
            return "High"
        case 2:
            return "Medium"
        case 3:
            return "Low"
        default:
            return "Unknown"
        }
    }
    
    var priorityColor: Color {
        switch priority {
        case 1:
            return .red
        case 2:
            return .orange
        case 3:
            return .yellow
        default:
            return .gray
        }
    }
}

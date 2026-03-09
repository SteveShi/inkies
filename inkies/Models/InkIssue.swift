import Foundation

struct InkIssue: Identifiable, Sendable, Equatable {
    let id = UUID()
    let type: IssueType
    let lineNumber: Int
    let message: String
    
    enum IssueType: String, Sendable {
        case error = "ERROR"
        case warning = "WARNING"
    }
}

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Unified Export Document
struct InkExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.ink, .json, .html, .plainText] }

    var content: String
    var utType: UTType

    init(content: String, utType: UTType) {
        self.content = content
        self.utType = utType
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
            let text = String(data: data, encoding: .utf8)
        {
            content = text
        } else {
            content = ""
        }
        utType = .plainText
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

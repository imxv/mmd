import Foundation

enum FileEncodingError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        "无法识别 Markdown 文件的文本编码。建议将文件保存为 UTF-8。"
    }
}

enum FileEncodingDetector {
    static func decode(_ data: Data) throws -> String {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(decoding: data.dropFirst(3), as: UTF8.self)
        }

        if data.starts(with: [0xFF, 0xFE]), let value = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) {
            return value
        }

        if data.starts(with: [0xFE, 0xFF]), let value = String(data: data.dropFirst(2), encoding: .utf16BigEndian) {
            return value
        }

        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }

        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }

        throw FileEncodingError.unreadable
    }
}

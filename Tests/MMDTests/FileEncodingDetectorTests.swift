import Foundation
import Testing
@testable import MMD

struct FileEncodingDetectorTests {
    @Test func decodesUTF8AndBOM() throws {
        #expect(try FileEncodingDetector.decode(Data("你好 Markdown".utf8)) == "你好 Markdown")

        var bom = Data([0xEF, 0xBB, 0xBF])
        bom.append(Data("hello".utf8))
        #expect(try FileEncodingDetector.decode(bom) == "hello")
    }

    @Test func decodesUTF16LittleEndianBOM() throws {
        var data = Data([0xFF, 0xFE])
        data.append("阅读器".data(using: .utf16LittleEndian)!)
        #expect(try FileEncodingDetector.decode(data) == "阅读器")
    }
}

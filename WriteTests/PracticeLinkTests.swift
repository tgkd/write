import XCTest
@testable import Write

final class PracticeLinkTests: XCTestCase {

    func testURLRoundTrips() {
        let url = PracticeLink.url(codePoint: "5c71")

        XCTAssertEqual(url.absoluteString, "kakijun://practice?cp=5c71")
        XCTAssertEqual(PracticeLink.codePoint(from: url), "5c71")
    }

    func testSchemeAndHostAreCaseInsensitiveAndCodePointIsLowercased() {
        let url = URL(string: "KAKIJUN://PRACTICE?cp=5C71")!

        XCTAssertEqual(PracticeLink.codePoint(from: url), "5c71")
    }

    func testRejectsMalformedLinks() {
        let rejected = [
            "https://practice?cp=5c71",
            "kakijun://notebook?cp=5c71",
            "kakijun://practice",
            "kakijun://practice?cp=",
            "kakijun://practice?cp=zzzz",
            "kakijun://practice?cp=%EF%BC%95c71",
            "kakijun://practice?cp=1234567",
        ]

        for link in rejected {
            XCTAssertNil(PracticeLink.codePoint(from: URL(string: link)!), link)
        }
    }
}

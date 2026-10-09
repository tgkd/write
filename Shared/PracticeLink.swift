import Foundation

enum PracticeLink {
    static let scheme = "kakijun"
    private static let host = "practice"
    private static let codePointName = "cp"

    static func url(codePoint: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: codePointName, value: codePoint)]
        guard let url = components.url else {
            fatalError("Invalid practice link for code point: \(codePoint)")
        }
        return url
    }

    static func codePoint(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == scheme,
              components.host?.lowercased() == host,
              let value = components.queryItems?.first(where: { $0.name == codePointName })?.value,
              (1...6).contains(value.count),
              value.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            return nil
        }
        return value.lowercased()
    }
}

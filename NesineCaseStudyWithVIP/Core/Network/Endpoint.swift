import Foundation

struct Endpoint: Equatable {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]

    var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = path
        components.queryItems = queryItems
        return components.url
    }

    static func softwareSearch(term: String) -> Endpoint {
        Endpoint(
            path: "/search",
            method: .get,
            queryItems: [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "media", value: "software")
            ]
        )
    }
}

import Foundation

struct ITunesSearchResponse: Decodable, Equatable {
    let resultCount: Int
    let results: [SoftwareResult]
}

struct SoftwareResult: Decodable, Equatable {
    let trackName: String?
    let screenshotUrls: [URL]

    private enum CodingKeys: String, CodingKey {
        case trackName
        case screenshotUrls
    }

    init(trackName: String?, screenshotUrls: [URL]) {
        self.trackName = trackName
        self.screenshotUrls = screenshotUrls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackName = try container.decodeIfPresent(String.self, forKey: .trackName)
        screenshotUrls = try container.decodeIfPresent(
            [URL].self,
            forKey: .screenshotUrls
        ) ?? []
    }
}

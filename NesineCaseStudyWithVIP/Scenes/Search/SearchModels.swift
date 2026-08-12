import Foundation

enum Search {
    struct Screenshot: Equatable {
        let id: String
        let imageURL: URL
        let appName: String?
    }

    struct ScreenshotItem {
        let id: String
        let imageURL: URL
        let appName: String
    }

    enum Load {
        struct Request {
            let term: String
        }

        struct Response {
            enum State {
                case initial
                case loading
                case success([Screenshot])
                case failure
            }

            let state: State
        }

        struct ViewModel {
            enum State {
                case initial(message: String)
                case loading
                case content([ScreenshotItem])
                case empty(message: String)
                case error(message: String)
            }

            let state: State
        }
    }
}

import Foundation

/// A printed `\(error)` for a URLError includes the request URL, and Last.fm and Discogs URLs carry the api_key,
/// signature or token in the query; the localised description does not.
enum ErrorLog {
    static func line(_ context: String, _ error: Error) -> String {
        "\(context): \(error.localizedDescription)"
    }
}

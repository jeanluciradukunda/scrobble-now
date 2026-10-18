import Foundation

extension String {
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// Percent-encodes everything outside RFC 3986's unreserved set. `.urlQueryAllowed` leaves `&`, `+` and `=` raw,
    /// which splits or alters a query or form field ("Simon & Garfunkel").
    var queryValueEncoded: String {
        addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? self
    }
}

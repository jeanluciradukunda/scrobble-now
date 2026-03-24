import Foundation

actor WikidataService {

    func searchAlbum(album: String, artist: String) async throws -> [WikidataAlbum] {
        // SPARQL: find albums with this title that have a MusicBrainz release group ID
        let sparql = """
        SELECT ?album ?albumLabel ?mbid ?artistLabel WHERE {
          ?album rdfs:label "\(album)"@en ;
                 wdt:P31/wdt:P279* wd:Q482994 .
          OPTIONAL { ?album wdt:P436 ?mbid . }
          OPTIONAL { ?album wdt:P175 ?artist . }
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . }
        } LIMIT 5
        """
        let encoded = sparql.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://query.wikidata.org/sparql?format=json&query=\(encoded)")!

        var request = URLRequest(url: url)
        request.setValue("ScrobbleNow/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.trackedData(for: request, service: "Wikidata")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let results = (json?["results"] as? [String: Any])?["bindings"] as? [[String: Any]] else { return [] }

        return results.compactMap { binding -> WikidataAlbum? in
            guard let label = (binding["albumLabel"] as? [String: Any])?["value"] as? String else { return nil }
            let mbid = (binding["mbid"] as? [String: Any])?["value"] as? String
            let artistLabel = (binding["artistLabel"] as? [String: Any])?["value"] as? String
            return WikidataAlbum(title: label, artist: artistLabel ?? "", mbid: mbid)
        }
    }

    struct WikidataAlbum {
        let title: String
        let artist: String
        let mbid: String?
    }
}

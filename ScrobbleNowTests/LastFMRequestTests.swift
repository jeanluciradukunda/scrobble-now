import Testing
@testable import Scrobble_Now

struct LastFMRequestTests {
    @Test func reservedCharactersAreEscaped() {
        #expect("Simon & Garfunkel".queryValueEncoded == "Simon%20%26%20Garfunkel")
        #expect("Florence + the Machine".queryValueEncoded == "Florence%20%2B%20the%20Machine")
        #expect("a=b?c/d#e".queryValueEncoded == "a%3Db%3Fc%2Fd%23e")
    }

    @Test func unreservedAndNonLatinText() {
        #expect("Sigur_Rós-1.0~".queryValueEncoded == "Sigur_R%C3%B3s-1.0~")
        #expect("東京".queryValueEncoded == "%E6%9D%B1%E4%BA%AC")
    }

    @Test func formBodyKeepsEachFieldIntact() {
        let body = LastFMService.formBody(["artist": "Simon & Garfunkel", "track": "Mrs. Robinson", "method": "track.scrobble"])
        #expect(body == "artist=Simon%20%26%20Garfunkel&method=track.scrobble&track=Mrs.%20Robinson")
    }

    @Test func signatureUsesRawValuesSortedByKey() {
        let params = ["method": "m", "artist": "Simon & Garfunkel", "api_key": "k"]
        #expect(LastFMService.signature(params: params, secret: "s") == "9e9b61137ea04ea867ba276bb15ebae4")
    }
}

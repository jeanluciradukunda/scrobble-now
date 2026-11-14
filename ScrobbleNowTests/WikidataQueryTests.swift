import Foundation
import Testing
@testable import Scrobble_Now

struct WikidataQueryTests {
    @Test func quotesAndBackslashesStayInsideTheLiteral() {
        #expect(WikidataService.sparqlStringContent(#"12" Mix"#) == #"12\" Mix"#)
        #expect(WikidataService.sparqlStringContent(#"a\b"#) == #"a\\b"#)
        #expect(WikidataService.sparqlStringContent("one\ntwo") == #"one\ntwo"#)
    }

    @Test func plainTitlesAreUnchanged() {
        #expect(WikidataService.sparqlStringContent("OK Computer") == "OK Computer")
    }
}

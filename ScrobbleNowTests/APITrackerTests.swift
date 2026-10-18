import Testing
@testable import Scrobble_Now

struct APITrackerTests {
    @Test func onlyTwoHundredsCountAsSuccess() {
        #expect(APITracker.isSuccess(statusCode: 200))
        #expect(APITracker.isSuccess(statusCode: 204))
        #expect(!APITracker.isSuccess(statusCode: 403))
        #expect(!APITracker.isSuccess(statusCode: 503))
        #expect(APITracker.isSuccess(statusCode: nil))
    }
}

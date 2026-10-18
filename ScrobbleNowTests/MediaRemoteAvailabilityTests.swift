import Foundation
import Testing
@testable import Scrobble_Now

struct MediaRemoteAvailabilityTests {
    private func version(_ major: Int, _ minor: Int) -> OperatingSystemVersion {
        OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: 0)
    }

    @Test func restrictedFromMacOS15Point4() {
        #expect(!MediaRemoteBridge.restrictsMediaRemote(version(14, 7)))
        #expect(!MediaRemoteBridge.restrictsMediaRemote(version(15, 3)))
        #expect(MediaRemoteBridge.restrictsMediaRemote(version(15, 4)))
        #expect(MediaRemoteBridge.restrictsMediaRemote(version(26, 2)))
    }

    @MainActor @Test func theFeedHasOneSharedModel() {
        #expect(NowPlayingViewModel.shared === NowPlayingViewModel.shared)
    }
}

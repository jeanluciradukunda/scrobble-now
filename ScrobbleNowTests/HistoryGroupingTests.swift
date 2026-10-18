import Foundation
import Testing
@testable import Scrobble_Now

private var capeTown: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Africa/Johannesburg")!
    return calendar
}

private func at(_ text: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: text)!
}

private func track(_ name: String, _ time: String, artist: String = "A") -> ScrobbledTrack {
    ScrobbledTrack(id: name + time, name: name, artistName: artist, albumName: "X", albumArtworkURL: nil,
                   timestamp: at(time), isNowPlaying: false, loved: false, lastfmURL: nil, mbid: nil)
}

struct HistoryGroupingTests {
    @Test func aFullPageDropsItsPartialOldestDay() {
        let tracks = [track("a", "2026-10-18T10:00:00Z"), track("b", "2026-10-17T10:00:00Z")]
        let full = HistoryGrouping.completeDays(from: tracks, pageWasFull: true, calendar: capeTown)
        #expect(full.map(\.id) == ["2026-10-18"])
        let partial = HistoryGrouping.completeDays(from: tracks, pageWasFull: false, calendar: capeTown)
        #expect(partial.count == 2)
    }

    @Test func mergingAPartialDayNoLongerShrinksACompleteOne() {
        let month = HistoryGrouping.days((0..<40).map { track("t\($0)", "2026-10-14T0\($0 % 10):0\($0 % 6):00Z") }
                                         + [track("x", "2026-10-15T10:00:00Z")], calendar: capeTown)
        let latest = HistoryGrouping.completeDays(
            from: [track("x", "2026-10-15T10:00:00Z"), track("t1", "2026-10-14T05:00:00Z")], pageWasFull: true, calendar: capeTown)
        let merged = HistoryGrouping.merging(month, with: latest)
        #expect(merged.first { $0.id == "2026-10-14" }?.tracks.count == 40)
    }

    @Test func dayKeysFollowTheLocalCalendarDay() {
        // 23:30 UTC on the 17th is 01:30 on the 18th in Cape Town.
        #expect(HistoryGrouping.dayKey(at("2026-10-17T23:30:00Z"), calendar: capeTown) == "2026-10-18")
    }

    @Test func tracksGroupIntoDaysNewestFirst() {
        let days = HistoryGrouping.days([
            track("late", "2026-10-17T21:59:00Z"),
            track("after midnight", "2026-10-17T22:01:00Z"),
            track("morning", "2026-10-17T06:00:00Z")
        ], calendar: capeTown)
        #expect(days.map(\.id) == ["2026-10-18", "2026-10-17"])
        #expect(days[1].tracks.map(\.name) == ["late", "morning"])
    }

    @Test func aGapOfMoreThanThirtyMinutesStartsANewSession() {
        let sessions = HistoryGrouping.sessions([
            track("c", "2026-10-17T12:40:00Z"),
            track("b", "2026-10-17T12:10:00Z"),
            track("a", "2026-10-17T11:00:00Z")
        ])
        #expect(sessions.map { $0.tracks.map(\.name) } == [["c", "b"], ["a"]])
    }

    @Test func streakCountsBackFromToday() {
        let today = at("2026-10-18T10:00:00Z")
        let days: Set = ["2026-10-18", "2026-10-17", "2026-10-16", "2026-10-14"]
        #expect(HistoryGrouping.streak(days: days, today: today, calendar: capeTown) == 3)
    }

    @Test func streakStillCountsBeforeTodaysFirstScrobble() {
        let today = at("2026-10-18T06:00:00Z")
        #expect(HistoryGrouping.streak(days: ["2026-10-17", "2026-10-16"], today: today, calendar: capeTown) == 2)
        #expect(HistoryGrouping.streak(days: ["2026-10-15"], today: today, calendar: capeTown) == 0)
    }

    @Test func mergingReplacesDaysAndKeepsTheRest() {
        let old = HistoryGrouping.days([track("x", "2026-10-16T10:00:00Z"), track("y", "2026-10-17T10:00:00Z")],
                                       calendar: capeTown)
        let fresh = HistoryGrouping.days([track("z", "2026-10-17T11:00:00Z")], calendar: capeTown)
        let merged = HistoryGrouping.merging(old, with: fresh)
        #expect(merged.map(\.id) == ["2026-10-17", "2026-10-16"])
        #expect(merged[0].tracks.map(\.name) == ["z"])
    }
}

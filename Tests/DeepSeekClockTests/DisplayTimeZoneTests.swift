//
//  DisplayTimeZoneTests.swift
//  DeepSeekClockTests
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Tests the pure mapping between a stored time-zone identifier and the usable   │
//  │ `TimeZone` used for display. The rules are tiny but load-bearing: an unknown  │
//  │ identifier must never crash or blank the countdown.                           │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import XCTest
@testable import DeepSeekClock

final class DisplayTimeZoneTests: XCTestCase {

    /// The default selection follows the Mac's zone.
    func testSystemFollowsAutoupdatingCurrent() {
        XCTAssertTrue(DisplayTimeZone.system.isSystem)
        XCTAssertEqual(DisplayTimeZone.system.timeZone, .autoupdatingCurrent)
    }

    /// A known identifier resolves to exactly that zone.
    func testKnownIdentifierResolvesToThatZone() {
        let zone = DisplayTimeZone(identifier: "Asia/Kolkata")
        XCTAssertFalse(zone.isSystem)
        XCTAssertEqual(zone.timeZone.identifier, "Asia/Kolkata")
    }

    /// An unknown identifier (e.g. a zone removed by an OS update) safely falls
    /// back to the system zone rather than crashing.
    func testUnknownIdentifierFallsBackToSystem() {
        let zone = DisplayTimeZone(identifier: "Not/AZone")
        XCTAssertEqual(zone.timeZone, .autoupdatingCurrent)
    }

    /// Offsets render with a sign and zero-padded minutes.
    func testOffsetLabels() {
        XCTAssertEqual(DisplayTimeZone.offsetLabel(TimeZone(identifier: "Asia/Kolkata")!), "GMT+5:30")
        XCTAssertEqual(DisplayTimeZone.offsetLabel(TimeZone(identifier: "UTC")!), "GMT+0:00")
        XCTAssertEqual(DisplayTimeZone.offsetLabel(TimeZone(identifier: "Etc/GMT+5")!), "GMT-5:00")
    }

    /// The picker is populated from the system's known zones.
    func testSelectableIdentifiersAreSortedAndNonEmpty() {
        let identifiers = DisplayTimeZone.selectableIdentifiers
        XCTAssertFalse(identifiers.isEmpty)
        XCTAssertEqual(identifiers, identifiers.sorted())
        XCTAssertTrue(identifiers.contains("Asia/Kolkata"))
    }

    /// Grouping puts each zone under its region, sorted, with region-less zones
    /// under "Other".
    func testGroupingByRegion() {
        let identifiers = DisplayTimeZone.selectableIdentifiers
        let groups = DisplayTimeZone.groupedIdentifiers()
        XCTAssertEqual(groups.map(\.region), groups.map(\.region).sorted())

        XCTAssertEqual(groups.flatMap(\.identifiers).sorted(), identifiers)
        for group in groups {
            if group.region == "Other" {
                XCTAssertTrue(group.identifiers.allSatisfy { !$0.contains("/") })
            } else {
                XCTAssertTrue(group.identifiers.allSatisfy { $0.hasPrefix("\(group.region)/") })
            }
        }
    }
}

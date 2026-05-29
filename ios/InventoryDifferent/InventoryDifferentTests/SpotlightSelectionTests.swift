//
//  SpotlightSelectionTests.swift
//  InventoryDifferentTests
//
//  NOTE: To run these tests, add InventoryDifferentWidgets as a testable target:
//  Edit Scheme → Test → Info → + → InventoryDifferentWidgets
//

import XCTest
@testable import InventoryDifferentWidgets

final class SpotlightSelectionTests: XCTestCase {

    private let nonFavorite = SpotlightDevice(
        id: 1, name: "Plain Mac", manufacturer: "Apple", releaseYear: 1990,
        estimatedValue: 100, functionalStatus: "YES", isFavorite: false,
        cpu: nil, ram: nil, thumbnailURL: nil
    )
    private let favorite = SpotlightDevice(
        id: 2, name: "Fave Mac", manufacturer: "Apple", releaseYear: 1989,
        estimatedValue: 420, functionalStatus: "YES", isFavorite: true,
        cpu: "68030", ram: "4MB", thumbnailURL: nil
    )

    func test_pickDevice_returnsNil_forEmptyPool() {
        XCTAssertNil(SpotlightProvider.pickDevice(from: [], for: Date()))
    }

    func test_pickDevice_isDeterministic_sameDateSameResult() {
        let pool = [nonFavorite, favorite]
        let date = Date(timeIntervalSince1970: 1_000_000)
        let first = SpotlightProvider.pickDevice(from: pool, for: date)
        let second = SpotlightProvider.pickDevice(from: pool, for: date)
        XCTAssertEqual(first?.id, second?.id)
    }

    func test_pickDevice_differsByDate() {
        let pool = [nonFavorite, favorite]
        let results = (0..<30).compactMap { offset -> Int? in
            let date = Date(timeIntervalSince1970: Double(offset) * 86400)
            return SpotlightProvider.pickDevice(from: pool, for: date)?.id
        }
        XCTAssertTrue(results.contains(nonFavorite.id), "Non-favorites should appear sometimes")
        XCTAssertTrue(results.contains(favorite.id), "Favorites should appear")
    }

    func test_pickDevice_favoritesBiased() {
        let pool = [nonFavorite, favorite]
        let results = (0..<100).compactMap { offset -> Int? in
            let date = Date(timeIntervalSince1970: Double(offset) * 86400)
            return SpotlightProvider.pickDevice(from: pool, for: date)?.id
        }
        let favoriteCount = results.filter { $0 == favorite.id }.count
        XCTAssertGreaterThan(Double(favoriteCount) / 100.0, 0.6,
                             "Favorites should appear >60% of the time with 3x weighting")
    }

    func test_pickDevice_allNonFavorite_stillPicks() {
        let pool = [nonFavorite,
                    SpotlightDevice(id: 3, name: "Other", manufacturer: nil, releaseYear: nil,
                                    estimatedValue: nil, functionalStatus: nil, isFavorite: false,
                                    cpu: nil, ram: nil, thumbnailURL: nil)]
        let result = SpotlightProvider.pickDevice(from: pool, for: Date(timeIntervalSince1970: 0))
        XCTAssertNotNil(result)
    }
}

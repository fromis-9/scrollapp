//
//  ScrollappTests.swift
//  ScrollappTests
//

import Foundation
import Testing
@testable import Scrollapp

struct ScrollappTests {

    @Test func axisAmountPreservesExistingVerticalBehavior() {
        #expect(ScrollPhysics.amount(for: 0, sensitivity: 1.0, inverted: false) == nil)
        #expect(ScrollPhysics.amount(for: 5, sensitivity: 1.0, inverted: false) == nil)
        #expect(ScrollPhysics.amount(for: 55, sensitivity: 1.0, inverted: false) == 2.5)
        #expect(ScrollPhysics.amount(for: -55, sensitivity: 1.0, inverted: false) == -2.5)
        #expect(ScrollPhysics.amount(for: 55, sensitivity: 1.0, inverted: true) == -2.5)
        #expect(ScrollPhysics.amount(for: 205, sensitivity: 1.0, inverted: false) == 30.0)
    }

    @Test func axisAmountAppliesSensitivity() {
        #expect(ScrollPhysics.amount(for: 55, sensitivity: 2.0, inverted: false) == 5.0)

        let expected = 2.5 * CGFloat(pow(0.5, 1.5))
        let actual = ScrollPhysics.amount(for: 55, sensitivity: 0.5, inverted: false)
        #expect(actual != nil)
        guard let actual else { return }
        #expect(abs(actual - expected) < 0.000_001)
    }

    @Test func amountsSupportIndependentAndDiagonalScrolling() {
        let horizontalOnly = ScrollPhysics.amounts(
            deltaX: 55,
            deltaY: 0,
            sensitivity: 1.0,
            inverted: false
        )
        #expect(horizontalOnly.horizontal == 2.5)
        #expect(horizontalOnly.vertical == nil)
        #expect(horizontalOnly.hasScroll)

        let verticalOnly = ScrollPhysics.amounts(
            deltaX: 0,
            deltaY: -55,
            sensitivity: 1.0,
            inverted: false
        )
        #expect(verticalOnly.horizontal == nil)
        #expect(verticalOnly.vertical == -2.5)
        #expect(verticalOnly.hasScroll)

        let diagonal = ScrollPhysics.amounts(
            deltaX: 55,
            deltaY: -55,
            sensitivity: 1.0,
            inverted: true
        )
        #expect(diagonal.horizontal == -2.5)
        #expect(diagonal.vertical == 2.5)
        #expect(diagonal.hasScroll)
    }
}

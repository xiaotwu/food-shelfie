import XCTest
import UIKit

/// Uses the dedicated QA shelf; mutation tests create and remove only their uniquely named data.
@MainActor
final class LayoutFlowTests: XCTestCase {
    private let dedicatedSimulator = "10D4A587-B93A-4931-93A6-FB6333055804"

    override func setUpWithError() throws {
        continueAfterFailure = false
        let current = ProcessInfo.processInfo.environment["SIMULATOR_UDID"]
        let adaptivePhone = (name.contains("testAdaptiveToolbar") || name.contains("testSettingsSubpageTitles")) && current == "FF62A285-23F2-40CB-9F25-7ADFC7F285AD"
        guard current == dedicatedSimulator || adaptivePhone else {
            throw XCTSkip("Layout verification is restricted to the dedicated iPad and designated phone navigation tests.")
        }
    }

    func testExistingShelfWorksInLandscapeAndPortraitAtConfiguredTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }

        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            let expectsLandscape = orientation != .portrait
            let rotationSettled = NSPredicate { _, _ in
                let frame = app.frame
                return frame.width > 0 && frame.height > 0 && ((frame.width > frame.height) == expectsLandscape)
            }
            XCTAssertTrue(waitFor(rotationSettled, timeout: 8), "The app must finish rotating before interacting or capturing evidence.")
            // A second observation avoids capturing the geometry transition itself.
            let settleWindow = Date().addingTimeInterval(0.7)
            XCTAssertTrue(waitFor(NSPredicate { _, _ in
                Date() >= settleWindow && ((app.frame.width > app.frame.height) == expectsLandscape)
            }, timeout: 3))
            let orientationName = orientation == .portrait ? "portrait" : "landscape"
            let useFirst = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "shelf.useFirst.")).firstMatch
            XCTAssertTrue(useFirst.waitForExistence(timeout: 8), "Existing Milk should appear in Use first.")
            reveal(useFirst, in: app)
            capture(app, name: "iPad-\(orientationName)-shelf")
            // The center must be actionable, including the gap between the name and expiry.
            useFirst.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5), "Center tap must open the food detail.")
            for label in ["Package expiry", "Date opened", "After opening, use by", "Reminder date"] {
                let text = app.staticTexts[label]
                reveal(text, in: app)
                XCTAssertTrue(text.isHittable, "Detail should expose \(label) without silently combining deadlines.")
            }
            capture(app, name: "iPad-\(orientationName)-detail-dates")
            app.buttons["detail.close"].tap()

            let shopping = app.buttons["Shopping list"].firstMatch
            reveal(shopping, in: app, scrollDown: true)
            XCTAssertTrue(shopping.isHittable)
            shopping.tap()
            XCTAssertTrue(app.textFields["shopping.name"].waitForExistence(timeout: 5))
            capture(app, name: "iPad-\(orientationName)-shopping")

            // Toggle the already completed QA item and restore its original state.
            let restorePending = app.buttons["Mark Milk as to buy"]
            reveal(restorePending, in: app)
            XCTAssertTrue(restorePending.isHittable, "The completed QA shopping item must be revealed and actionable; no data will be created.")
            restorePending.tap()
            addTeardownBlock {
                await MainActor.run {
                    let restore = app.buttons["Mark Milk as bought"]
                    if restore.exists {
                        self.reveal(restore, in: app)
                        if restore.isHittable { self.markBoughtOnly(restore, in: app) }
                    }
                }
            }
            let markBought = app.buttons["Mark Milk as bought"]
            XCTAssertTrue(markBought.waitForExistence(timeout: 5))
            defer {
                if markBought.exists {
                    reveal(markBought, in: app)
                    if markBought.isHittable { markBoughtOnly(markBought, in: app) }
                }
            }
            reveal(markBought, in: app)
            XCTAssertTrue(markBought.isHittable)
            XCTAssertEqual(markBought.value as? String, "To buy")
            capture(app, name: "iPad-\(orientationName)-shopping-pending")
            markBoughtOnly(markBought, in: app)
            XCTAssertTrue(restorePending.waitForExistence(timeout: 5))
            XCTAssertEqual(restorePending.value as? String, "Bought")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            let history = app.buttons["Food history"].firstMatch
            reveal(history, in: app, scrollDown: true)
            XCTAssertTrue(history.isHittable)
            history.tap()
            XCTAssertTrue(app.navigationBars["Food history"].waitForExistence(timeout: 5))
            capture(app, name: "iPad-\(orientationName)-history")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    func testGlobalNavigationAtConfiguredTextSize() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let settleWindow = Date().addingTimeInterval(0.7)
        XCTAssertTrue(waitFor(NSPredicate { _, _ in
            Date() >= settleWindow && app.frame.height > app.frame.width
        }, timeout: 8))
        verifyGlobalNavigation(in: app)
    }

    func testAdaptiveToolbarExpandsAndCollapsesWhenRotating() {
        let app = launchEnglishApp()
        defer { XCUIDevice.shared.orientation = .portrait }
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["Notifications"].firstMatch.tap()
        XCTAssertTrue(app.buttons["global.more"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(waitFor(NSPredicate { _, _ in app.frame.width > app.frame.height }, timeout: 8))
        XCTAssertTrue(app.buttons["global.search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["global.search"].isHittable)
        XCTAssertTrue(app.buttons["global.sort"].isHittable)
        XCTAssertTrue(app.buttons["global.add"].isHittable)
        XCTAssertFalse(app.buttons["global.more"].exists)
        capture(app, name: "adaptive-notifications-landscape-expanded")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(waitFor(NSPredicate { _, _ in app.frame.height > app.frame.width }, timeout: 8))
        XCTAssertTrue(app.buttons["global.more"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["global.more"].isHittable)
        capture(app, name: "adaptive-notifications-portrait-collapsed")
    }

    func testAdaptiveToolbarKeepsLongTitleAndRoutesCollapsedActions() {
        let app = launchEnglishApp()
        app.buttons["Settings"].firstMatch.tap()
        func openNotifications() {
            if !app.navigationBars["Notifications"].exists {
                let row = app.buttons["Notifications"].firstMatch
                reveal(row, in: app)
                XCTAssertTrue(row.isHittable)
                row.tap()
            }
            XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["global.more"].waitForExistence(timeout: 5))
            let title = app.navigationBars["Notifications"].staticTexts["Notifications"].firstMatch
            XCTAssertTrue(title.isHittable)
            let naturalWidth = ("Notifications" as NSString).size(withAttributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]).width
            XCTAssertGreaterThanOrEqual(title.frame.width, naturalWidth - 2,
                                        "Notifications must have room for its full title.")
            capture(app, name: "adaptive-notifications-collapsed")
        }
        openNotifications()
        app.buttons["global.more"].tap()
        let search = app.buttons["global.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3) && search.isHittable)
        search.tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
        app.navigationBars["Search"].buttons.element(boundBy: 0).tap()
        let settingsDock = app.buttons["Settings"].firstMatch
        XCTAssertTrue(waitForStableHittable(settingsDock, in: app, timeout: 8))
        settingsDock.tap()
        openNotifications()
        app.buttons["global.more"].tap()
        let sort = app.buttons["global.sort"]
        XCTAssertTrue(sort.waitForExistence(timeout: 3) && sort.isHittable)
        sort.tap()
        let byName = app.buttons["Name"].firstMatch
        XCTAssertTrue(byName.waitForExistence(timeout: 3) && byName.isHittable)
        byName.tap()
        XCTAssertTrue(app.navigationBars["Shelf"].waitForExistence(timeout: 5))
        tapGlobalAction("global.sort", in: app)
        app.buttons["Expiry date"].firstMatch.tap()
        XCTAssertTrue(waitForStableHittable(settingsDock, in: app, timeout: 8))
        settingsDock.tap()
        openNotifications()
        app.buttons["global.more"].tap()
        let add = app.buttons["global.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 3) && add.isHittable)
        add.tap()
        let manual = app.buttons["global.add.manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 3) && manual.isHittable)
        manual.tap()
        XCTAssertTrue(app.textFields["entry.name"].waitForExistence(timeout: 5))
        capture(app, name: "adaptive-add-from-overflow")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Shelf"].waitForExistence(timeout: 5))
        assertGlobalToolbar(in: app, title: "Shelf")
    }

    func testSettingsSubpageTitlesAreCenteredAndActionsSymmetric() {
        let app = launchEnglishApp()
        defer { XCUIDevice.shared.orientation = .portrait }
        app.buttons["Settings"].firstMatch.tap()
        assertGlobalToolbar(in: app, title: "Settings")
        for title in ["Notifications", "Appearance", "Data", "More", "About Shelfie"] {
            let row = app.buttons[title].firstMatch
            reveal(row, in: app, scrollDown: title == "Notifications")
            XCTAssertTrue(row.isHittable, "The Settings destination must remain actionable.")
            row.tap()
            assertGlobalToolbar(in: app, title: title)
            capture(app, name: "centered-settings-" + title.lowercased().replacingOccurrences(of: " ", with: "-"))
            assertToolbarInsetsAndTouchAreas(in: app)
            if app.buttons["global.more"].exists {
                app.buttons["global.more"].tap()
                for action in ["global.search", "global.sort", "global.add"] {
                    let item = app.buttons[action]
                    XCTAssertTrue(item.waitForExistence(timeout: 3) && item.isHittable,
                                  "Collapsing actions must preserve every destination.")
                }
                capture(app, name: "centered-settings-" + title.lowercased().replacingOccurrences(of: " ", with: "-") + "-menu")
                // Tap the page below the native menu, outside its anchored popover.
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.72)).tap()
                XCTAssertTrue(waitFor(NSPredicate { _, _ in !app.buttons["global.search"].exists }, timeout: 3))
            }
            let back = app.navigationBars[title].buttons.allElementsBoundByIndex.first {
                !["global.search", "global.sort", "global.add", "global.more"].contains($0.identifier)
                    && $0.isHittable
            }
            XCTAssertNotNil(back, "Each settings subpage must preserve its native Back action.")
            back?.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        }
    }

    func testNewFoodWithoutExpiryAndSaveAnotherResetsForm() {
        let app = launchEnglishApp()
        let token = String(UUID().uuidString.prefix(6))
        let names = ["QA First " + token, "QA Second " + token]
        addTeardownBlock { await MainActor.run { self.removeOwnedFoods(names, in: app) } }
        openManualEntry(in: app)
        enterName(names[0], in: app)
        let hasExpiry = app.switches["entry.hasExpiry"]
        reveal(hasExpiry, in: app)
        XCTAssertEqual(hasExpiry.value as? String, "0", "Manual entry must start without an invented expiry date.")
        let more = app.buttons["entry.moreInformation"].firstMatch
        reveal(more, in: app)
        XCTAssertTrue(more.isHittable)
        XCTAssertFalse(app.switches["Opened"].exists, "Optional information must start collapsed.")
        more.tap()
        let opened = app.switches["Opened"]
        reveal(opened, in: app)
        XCTAssertTrue(opened.isHittable, "Expanding More information must expose the actual controls.")
        reveal(more, in: app, scrollDown: true)
        more.tap()
        XCTAssertTrue(waitFor(NSPredicate { _, _ in !opened.exists }, timeout: 3))
        let continueButton = app.buttons["entry.saveAndContinue"]
        reveal(continueButton, in: app)
        XCTAssertTrue(continueButton.isHittable && continueButton.isEnabled)
        continueButton.tap()
        let nameField = app.textFields["entry.name"]
        XCTAssertTrue(waitFor(NSPredicate { _, _ in
            nameField.exists && ["", "Item name"].contains(nameField.value as? String ?? "invalid")
        }, timeout: 5), "Successful Save and add another must retain the sheet and clear the name.")
        reveal(nameField, in: app, scrollDown: true)
        XCTAssertTrue(nameField.isHittable)
        XCTAssertEqual(app.textFields["entry.quantity"].value as? String, "1")
        reveal(hasExpiry, in: app)
        XCTAssertEqual(hasExpiry.value as? String, "0")
        XCTAssertFalse(opened.exists, "Optional information must collapse for the next item.")
        capture(app, name: "entry-save-another-reset")
        enterName(names[1], in: app)
        app.navigationBars["Add item"].buttons["Save"].tap()
        XCTAssertTrue(waitFor(NSPredicate { _, _ in !nameField.exists }, timeout: 5))
        for name in names {
            let card = foodCard(named: name, in: app)
            reveal(card, in: app)
            XCTAssertTrue(card.isHittable, "Both explicitly saved QA foods must appear in inventory.")
            capture(app, name: "entry-before-card-center-" + name)
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            capture(app, name: "entry-after-card-center-" + name)
            XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5))
            let unknown = app.staticTexts["Unknown"].firstMatch
            reveal(unknown, in: app)
            XCTAssertTrue(unknown.isHittable, "The saved package expiry must remain unknown.")
            capture(app, name: "entry-no-expiry-" + name)
            app.buttons["detail.close"].tap()
        }
    }

    func testShoppingConversionRequiresConfirmationAndCreatesOneBatch() {
        let app = launchEnglishApp()
        let name = "QA Shop " + String(UUID().uuidString.prefix(6))
        addTeardownBlock { await MainActor.run {
            self.removeOwnedFoods([name], in: app)
            self.removeOwnedShopping(name, in: app)
        } }
        openShopping(in: app)
        let field = app.textFields["shopping.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        let add = app.buttons["Add"].firstMatch
        reveal(add, in: app)
        XCTAssertTrue(add.isHittable && add.isEnabled)
        add.tap()
        let markBought = app.buttons["Mark " + name + " as bought"]
        reveal(markBought, in: app)
        XCTAssertTrue(markBought.isHittable)
        markBought.tap()
        let convert = app.buttons["Add to shelf"].firstMatch
        XCTAssertTrue(convert.waitForExistence(timeout: 3) && convert.isHittable)
        // Native iPad confirmation popovers dismiss by tapping outside; they omit a Cancel row.
        app.navigationBars["Shopping list"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(waitFor(NSPredicate { _, _ in !convert.exists }, timeout: 3))
        XCTAssertTrue(markBought.exists)
        XCTAssertEqual(markBought.value as? String, "To buy", "Cancelling purchase confirmation must keep the item pending.")
        markBought.tap()
        XCTAssertTrue(convert.waitForExistence(timeout: 3))
        convert.tap()
        XCTAssertTrue(app.textFields["entry.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["entry.name"].value as? String, name)
        let save = app.navigationBars["Add item"].buttons["Save"]
        XCTAssertFalse(save.isEnabled, "A shopping conversion must require an explicit date choice.")
        let confirm = app.switches["entry.confirmExpiry"]
        reveal(confirm, in: app)
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let bought = app.buttons["Mark " + name + " as to buy"]
        XCTAssertTrue(bought.waitForExistence(timeout: 5), "Food save must commit the purchase state atomically.")
        reveal(bought, in: app)
        XCTAssertTrue(bought.isHittable)
        let actions = app.buttons["Actions for " + name].firstMatch
        reveal(actions, in: app)
        XCTAssertTrue(actions.isHittable)
        actions.tap()
        let already = app.buttons["Already added to shelf"]
        XCTAssertTrue(already.waitForExistence(timeout: 3))
        XCTAssertFalse(already.isEnabled, "The same shopping source must not create another batch.")
        capture(app, name: "shopping-conversion-linked-once")
        app.navigationBars["Shopping list"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.navigationBars["Shopping list"].buttons.element(boundBy: 0).tap()
        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name))
        XCTAssertEqual(cards.count, 1, "Only one food batch should result from the confirmed shopping conversion.")
        let card = foodCard(named: name, in: app)
        reveal(card, in: app)
        XCTAssertTrue(card.isHittable)
        card.tap()
        XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5))
        capture(app, name: "shopping-converted-food")
        app.buttons["detail.close"].tap()
    }

    private func launchEnglishApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Shelf"].waitForExistence(timeout: 8))
        return app
    }

    private func openManualEntry(in app: XCUIApplication) {
        tapGlobalAction("global.add", in: app)
        let manual = app.buttons["global.add.manual"].firstMatch
        XCTAssertTrue(manual.waitForExistence(timeout: 3) && manual.isHittable)
        manual.tap()
        XCTAssertTrue(app.textFields["entry.name"].waitForExistence(timeout: 5))
    }

    private func enterName(_ name: String, in app: XCUIApplication) {
        let field = app.textFields["entry.name"]
        reveal(field, in: app, scrollDown: true)
        XCTAssertTrue(field.isHittable)
        field.tap(); field.typeText(name)
        // A keyboard must not cover the controls subsequently under test.
        if app.keyboards.buttons["Hide keyboard"].exists { app.keyboards.buttons["Hide keyboard"].tap() }
    }

    private func foodCard(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    private func openShopping(in app: XCUIApplication) {
        let shopping = app.buttons["Shopping list"].firstMatch
        reveal(shopping, in: app, scrollDown: true)
        XCTAssertTrue(shopping.isHittable)
        shopping.tap()
        XCTAssertTrue(app.navigationBars["Shopping list"].waitForExistence(timeout: 5))
    }

    private func markBoughtOnly(_ button: XCUIElement, in app: XCUIApplication) {
        button.tap()
        let choice = app.buttons["Mark as bought only"].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 3) && choice.isHittable)
        choice.tap()
    }

    private func removeOwnedFoods(_ names: [String], in app: XCUIApplication) {
        app.terminate(); app.launch()
        guard app.navigationBars["Shelf"].waitForExistence(timeout: 5) else { return }
        for name in names {
            let card = foodCard(named: name, in: app)
            // Only unique names generated by this test can be selected or deleted.
            guard card.exists else { continue }
            reveal(card, in: app)
            XCTAssertTrue(card.isHittable)
            card.press(forDuration: 1.1)
            let actions = app.buttons["Actions"].firstMatch
            let hasActions = actions.waitForExistence(timeout: 3) && actions.isHittable
            XCTAssertTrue(hasActions, "Long press on an owned food must expose selection actions.")
            guard hasActions else { capture(app, name: "owned-cleanup-missing-actions"); return }
            actions.tap()
            let delete = app.buttons["Delete"].firstMatch
            XCTAssertTrue(delete.waitForExistence(timeout: 3))
            delete.tap()
            let confirm = app.buttons["Delete"].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 3) && confirm.isHittable)
            confirm.tap()
            XCTAssertTrue(waitFor(NSPredicate { _, _ in !card.exists }, timeout: 5), "Cleanup must remove only this test's food.")
        }
    }

    private func removeOwnedShopping(_ name: String, in app: XCUIApplication) {
        app.terminate(); app.launch()
        guard app.navigationBars["Shelf"].waitForExistence(timeout: 5) else { return }
        openShopping(in: app)
        let row = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Mark " + name + " as bought", "Mark " + name + " as to buy")).firstMatch
        guard row.exists else { return }
        reveal(row, in: app)
        XCTAssertTrue(row.isHittable)
        row.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3) && delete.isHittable)
        delete.tap()
        XCTAssertTrue(waitFor(NSPredicate { _, _ in !row.exists }, timeout: 5))
    }

    private func verifyGlobalNavigation(in app: XCUIApplication) {
        assertGlobalToolbar(in: app, title: "Shelf")
        app.buttons["Insights"].firstMatch.tap()
        assertGlobalToolbar(in: app, title: "Insights")
        for kind in ["expired", "expiring"] {
            let card = app.descendants(matching: .any).matching(identifier: "insights.\(kind).card").firstMatch
            let number = app.descendants(matching: .any).matching(identifier: "insights.\(kind).count").firstMatch
            XCTAssertTrue(card.exists)
            XCTAssertTrue(number.exists)
            XCTAssertFalse(card.frame.isEmpty)
            XCTAssertFalse(number.frame.isEmpty)
            XCTAssertTrue(card.frame.contains(number.frame), "Large-font counts must remain inside their Insights cards.")
        }
        capture(app, name: "global-insights-toolbar")
        verifySortRouting(in: app)
        app.buttons["Settings"].firstMatch.tap()
        assertGlobalToolbar(in: app, title: "Settings")
        let appearance = app.buttons["Appearance"].firstMatch
        reveal(appearance, in: app)
        XCTAssertTrue(appearance.isHittable)
        appearance.tap()
        assertGlobalToolbar(in: app, title: "Appearance")
        let back = app.navigationBars["Appearance"].buttons.element(boundBy: 0)
        XCTAssertTrue(back.isHittable, "Appearance must retain its native Back button beside the shared toolbar.")
        XCTAssertFalse(["global.search", "global.sort", "global.add"].contains(back.identifier))
        capture(app, name: "global-appearance-back-and-toolbar")

        tapGlobalAction("global.search", in: app)
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5), "Shared search must navigate from Settings to the shelf search.")
        capture(app, name: "global-search-from-settings")
        app.navigationBars["Search"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Shelf"].waitForExistence(timeout: 5), "Search must return to Shelf before switching tabs.")
        let insightsDock = app.buttons["Insights"].firstMatch
        XCTAssertTrue(waitForStableHittable(insightsDock, in: app, timeout: 8),
                      "The Insights dock button must be visible inside the app and hold a stable frame for at least half a second.")
        capture(app, name: "global-before-insights-after-search")
        insightsDock.tap()
        capture(app, name: "global-after-insights-after-search")
        assertGlobalToolbar(in: app, title: "Insights")
        tapGlobalAction("global.add", in: app)
        let manual = app.buttons["global.add.manual"].firstMatch
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        XCTAssertTrue(manual.isHittable)
        manual.tap()
        XCTAssertTrue(app.textFields["entry.quantity"].waitForExistence(timeout: 5), "Shared Add must open the manual entry form from Insights.")
        capture(app, name: "global-add-from-insights")
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.isHittable)
        cancel.tap()
        XCTAssertTrue(waitFor(NSPredicate { _, _ in !app.textFields["entry.quantity"].exists }, timeout: 5))
    }

    private func verifySortRouting(in app: XCUIApplication) {
        // The dedicated shelf has one Milk batch, so verify native selection state and routing rather
        // than inventing extra inventory merely to check alphabetical order.
        addTeardownBlock {
            await MainActor.run {
                if !app.buttons["Expiry date"].exists,
                   app.buttons["global.sort"].isHittable || app.buttons["global.more"].isHittable {
                    self.tapGlobalAction("global.sort", in: app)
                }
                let expiry = app.buttons["Expiry date"].firstMatch
                if expiry.exists && expiry.isHittable { expiry.tap() }
            }
        }
        tapGlobalAction("global.sort", in: app)
        let byName = app.buttons["Name"].firstMatch
        XCTAssertTrue(byName.waitForExistence(timeout: 5), "The localized sort option is Name.")
        XCTAssertTrue(byName.isHittable)
        byName.tap()
        assertGlobalToolbar(in: app, title: "Shelf")
        capture(app, name: "global-sort-name-from-insights")
        tapGlobalAction("global.sort", in: app)
        let selectedName = app.buttons["Name"].firstMatch
        XCTAssertTrue(selectedName.waitForExistence(timeout: 5))
        capture(app, name: "global-sort-name-selection")
        XCTAssertTrue(waitFor(NSPredicate { _, _ in
            selectedName.isSelected || (selectedName.value as? NSNumber)?.boolValue == true
                || ["1", "selected"].contains((selectedName.value as? String ?? "").lowercased())
        }, timeout: 3), "The menu must expose Name as the active sort choice.")
        let expiry = app.buttons["Expiry date"].firstMatch
        XCTAssertTrue(expiry.isHittable)
        expiry.tap()
        assertGlobalToolbar(in: app, title: "Shelf")
    }

    private func tapGlobalAction(_ identifier: String, in app: XCUIApplication) {
        let action = app.buttons[identifier]
        if !(action.exists && action.isHittable) {
            let more = app.buttons["global.more"]
            XCTAssertTrue(more.waitForExistence(timeout: 5) && more.isHittable,
                          "The folded toolbar must offer its action menu.")
            more.tap()
        }
        XCTAssertTrue(action.waitForExistence(timeout: 3) && action.isHittable,
                      "The requested action must remain accessible in either toolbar presentation.")
        action.tap()
    }

    private func toolbarControls(in app: XCUIApplication) -> [XCUIElement] {
        if app.buttons["global.more"].exists { return [app.buttons["global.more"]] }
        return ["global.search", "global.sort", "global.add"].map { app.buttons[$0] }
    }

    private func assertGlobalToolbar(in app: XCUIApplication, title: String) {
        let navigationBar = app.navigationBars[title].firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        let principalPages = ["Settings", "Notifications", "Appearance", "Data", "More", "About Shelfie"]
        let inlineTitle = principalPages.contains(title)
            ? navigationBar.staticTexts["global.title"].firstMatch
            : navigationBar.staticTexts[title].firstMatch
        var lastFrames: [CGRect]?
        var stableSince: Date?
        let settled = waitFor(NSPredicate { _, _ in
            guard inlineTitle.exists, inlineTitle.isHittable, !inlineTitle.frame.isEmpty,
                  navigationBar.frame.contains(inlineTitle.frame) else {
                lastFrames = nil; stableSince = nil; return false
            }
            let visibleControls = self.toolbarControls(in: app)
            guard visibleControls.allSatisfy({ $0.exists && $0.isHittable && !($0.frame.isEmpty) }) else {
                lastFrames = nil; stableSince = nil; return false
            }
            let frames = [inlineTitle.frame] + visibleControls.map(\.frame)
            if lastFrames != frames { lastFrames = frames; stableSince = Date(); return false }
            guard let stableSince else { return false }
            return Date().timeIntervalSince(stableSince) >= 0.5
        }, timeout: 20)
        if !settled { capture(app, name: "toolbar-not-settled-" + title.lowercased()) }
        XCTAssertTrue(settled, "The actual principal title and visible controls must finish their navigation transition and hold stable frames.")
        let controls = toolbarControls(in: app)
        for control in controls {
            XCTAssertTrue(control.exists)
            XCTAssertTrue(control.isHittable, "Shared actions must remain actionable on \(title).")
        }
        XCTAssertTrue(inlineTitle.exists, "The inline title must be present on \(title).")
        XCTAssertFalse(inlineTitle.frame.isEmpty)
        XCTAssertTrue(inlineTitle.isHittable, "The title must remain visible.")
        XCTAssertTrue(navigationBar.frame.contains(inlineTitle.frame))
        if (principalPages.contains(title) && abs(inlineTitle.frame.midX - app.frame.midX) > 2) || abs(inlineTitle.frame.midY - controls[0].frame.midY) > 24 {
            capture(app, name: "toolbar-geometry-failure-" + title.lowercased())
        }
        if principalPages.contains(title) {
            XCTAssertEqual(inlineTitle.frame.midX, app.frame.midX, accuracy: 2,
                           "Every Settings title must be centered in the screen, independent of action widths.")
        }
        XCTAssertEqual(inlineTitle.frame.midY, controls[0].frame.midY, accuracy: 24,
                       "Title and controls must share one navigation row.")
        let naturalWidth = (title as NSString).size(withAttributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]).width
        XCTAssertGreaterThanOrEqual(inlineTitle.frame.width, naturalWidth - 2,
                                    "The complete title must fit without truncating its text.")
        for control in controls {
            let overlap = inlineTitle.frame.intersection(control.frame)
            XCTAssertTrue(overlap.isNull || overlap.isEmpty, "Title must not collide with toolbar controls.")
        }
        for leadingButton in navigationBar.buttons.allElementsBoundByIndex
            where !["global.search", "global.sort", "global.add", "global.more"].contains(leadingButton.identifier)
                && leadingButton.isHittable {
            let overlap = inlineTitle.frame.intersection(leadingButton.frame)
            XCTAssertTrue(overlap.isNull || overlap.isEmpty, "Title must not collide with native Back.")
        }
    }

    private func assertToolbarInsetsAndTouchAreas(in app: XCUIApplication) {
        let controls = toolbarControls(in: app)
        for control in controls {
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertTrue(control.isHittable)
            XCTAssertTrue(app.frame.contains(control.frame))
            if let icon = control.images.allElementsBoundByIndex.first(where: { !$0.frame.isEmpty }) {
                XCTAssertEqual(icon.frame.midX, control.frame.midX, accuracy: 1,
                               "Each visible icon should be centered inside its touch area.")
            }
        }
        let container = app.descendants(matching: .any).matching(identifier: "global.actions.container").firstMatch
        XCTAssertTrue(container.exists, "The toolbar visual group must expose its measurable bounds.")
        XCTAssertFalse(container.frame.isEmpty)
        let first = controls.map(\.frame.minX).min()!
        let last = controls.map(\.frame.maxX).max()!
        let leadingInset = first - container.frame.minX
        let trailingInset = container.frame.maxX - last
        XCTAssertEqual(leadingInset, 8, accuracy: 1, "The visual group must retain its eight-point leading inset.")
        XCTAssertEqual(trailingInset, 8, accuracy: 1, "The visual group must retain its eight-point trailing inset.")
        XCTAssertEqual(leadingInset, trailingInset, accuracy: 1,
                       "The navigation action group must have equal left and right inner padding.")
    }

    private func waitFor(_ predicate: NSPredicate, timeout: TimeInterval) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    private func waitForStableHittable(_ element: XCUIElement, in app: XCUIApplication,
                                       timeout: TimeInterval) -> Bool {
        var lastFrame: CGRect?
        var stableSince: Date?
        return waitFor(NSPredicate { _, _ in
            guard element.exists, element.isHittable else {
                lastFrame = nil
                stableSince = nil
                return false
            }
            let frame = element.frame
            guard !frame.isEmpty, app.frame.contains(frame) else {
                lastFrame = nil
                stableSince = nil
                return false
            }
            if lastFrame != frame {
                lastFrame = frame
                stableSince = Date()
                return false
            }
            guard let stableSince else { return false }
            return Date().timeIntervalSince(stableSince) >= 0.5
        }, timeout: timeout)
    }

    private func scrollingContainer(in app: XCUIApplication) -> XCUIElement {
        let isEntry = app.textFields["entry.name"].exists
        let isDetail = app.buttons["detail.close"].exists
        let isShopping = app.navigationBars["Shopping list"].exists || app.textFields["shopping.name"].exists
        let isHistory = app.navigationBars["Food history"].exists
        let isOtherPage = ["Settings", "Notifications", "Appearance", "Data", "More", "About Shelfie", "Insights", "Search"].contains { app.navigationBars[$0].exists }
        let identifier = isEntry ? "entry.scroll" : (isDetail ? "detail.scroll" : (isShopping ? "shopping.scroll" : (isHistory ? "history.scroll" : (isOtherPage ? "page.scroll" : "shelf.scroll"))))
        // A SwiftUI List is generally a CollectionView; identifiers are not restricted to ScrollView AX types.
        let named = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        if named.exists, named.isHittable { return named }

        // Never drag the underlying shelf when a navigation destination or sheet is active.
        let excluded: Set<String> = (isEntry || isDetail || isShopping || isHistory || isOtherPage) ? ["shelf.scroll"] : []
        for query in [app.collectionViews, app.tables, app.scrollViews] {
            for view in query.allElementsBoundByIndex where view.isHittable && !excluded.contains(view.identifier) {
                return view
            }
        }
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, scrollDown: Bool = false) {
        var searchDown = scrollDown
        var previousFrame: CGRect?
        var unchangedCount = 0
        for _ in 0..<32 {
            let container = scrollingContainer(in: app)
            var viewport = container.frame.intersection(app.frame).insetBy(dx: 12, dy: 12)
            if app.buttons["detail.close"].exists {
                // Account for the fixed action footer if AX exposes an oversized scroll frame.
                let footer = app.buttons.matching(NSPredicate(format: "label == %@", "Mark as eaten"))
                    .allElementsBoundByIndex.filter { $0.isHittable }.map(\.frame.minY).min()
                if let footer, footer > viewport.minY {
                    viewport.size.height = min(viewport.height, footer - viewport.minY - 12)
                }
            }
            guard !viewport.isEmpty else { return }
            let frame = element.exists ? element.frame : .zero
            let meaningfulFrame = !frame.isEmpty && frame.origin.x.isFinite && frame.origin.y.isFinite
            if meaningfulFrame, element.isHittable,
               viewport.contains(CGPoint(x: frame.midX, y: frame.midY)) { return }

            if meaningfulFrame {
                if frame.midY < viewport.minY { searchDown = true }
                else if frame.midY > viewport.maxY { searchDown = false }
                // When the center is in the viewport but covered, try a small nudge toward its center.
                else { searchDown = frame.midY < viewport.midY }
            }
            // Off-screen List rows can be absent from AX until materialized. A missing frame is not evidence
            // that scrolling stopped: reversing every two drags would oscillate inside the long add form.
            if meaningfulFrame, previousFrame == frame { unchangedCount += 1 } else { unchangedCount = 0 }
            if unchangedCount >= 2 {
                searchDown.toggle()
                unchangedCount = 0
            }
            previousFrame = frame
            let distance = min(100, max(30, viewport.height * 0.18))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.midY))
            let end = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.midY + (searchDown ? distance : -distance)))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        let hierarchy = XCTAttachment(string: scrollingContainer(in: app).debugDescription)
        hierarchy.name = "Unrevealed-\(element.label)-AX"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + "-AX"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}

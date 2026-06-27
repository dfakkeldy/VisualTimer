# Turn Timer Phase 2: $4.99 Pro Unlock Implementation Plan

> **For Dan / Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to work this plan task by task. Do not skip verification gates. This branch is stacked on `codex/turn-timer-phase1`; open the PR against that branch unless Phase 1 has merged into `main`.

**Goal:** Add a StoreKit 2 non-consumable Pro unlock for Turn Timer without blocking basic timer use. Free users keep quick timer, starter templates, and one custom saved template. Pro unlocks additional saved templates, full history/export, and provides the purchase/restore foundation for later sync, sharing, and widgets.

**Branch / Worktree:** `/Users/dfakkeldy/Developer/VisualTimer-turn-timer-phase2` on `codex/turn-timer-phase2`, based on `codex/turn-timer-phase1`.

**Product ID:** `turntimer.pro.unlock`

**Product Type:** Non-consumable in-app purchase.

**Price:** $4.99 one-time unlock.

**Project Constraints:**
- Preserve iOS 18.0 and watchOS 11.0 deployment targets.
- Preserve Swift 5.0 project settings.
- Use StoreKit 2; no backend and no third-party frameworks.
- Keep the existing MVVM shape: view models own logic, SwiftUI views render state and emit actions.
- Keep basic timer start/play paths free and never show a launch-blocking paywall.
- Existing internal `GameSequence`/`GameRecord` names can remain in Phase 2.

**Pre-existing Verification Note:**
- The local simulator XCTest runner can hang before test execution. Use `build-for-testing` as the primary compile check and wrap any `test-without-building` attempt in `gtimeout`.

---

## Task 1: StoreKit Configuration and Product Constants

**Files:**
- Create: `TurnTimer.storekit`
- Create: `Visual Timer/ProProduct.swift`
- Modify only if required by Xcode: `Visual Timer.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces local StoreKit config with product `turntimer.pro.unlock`.
- Produces product constants consumed by StoreKit and paywall UI.

### Step 1: Create StoreKit config first

Create `TurnTimer.storekit` at the project root.

It must contain one non-consumable product:

```text
Product ID: turntimer.pro.unlock
Reference Name: Turn Timer Pro
Display Name: Turn Timer Pro
Description: Unlock unlimited templates, full history export, and Pro features.
Price: 4.99 USD
Family Sharing: off for Phase 2
```

If creating the file manually, use the minimal modern `.storekit` JSON structure Xcode accepts for a non-consumable product. After adding it, run:

```bash
python3 -m json.tool TurnTimer.storekit >/dev/null
```

Expected: command exits 0.

If Xcode refuses to use a manually created file later, recreate the file from Xcode with File > New > File > StoreKit Configuration File, then preserve the same product ID and price.

### Step 2: Add product constants

Create `Visual Timer/ProProduct.swift`:

```swift
import Foundation

enum ProProduct {
    static let unlockID = "turntimer.pro.unlock"
    static let unlockIDs: Set<String> = [unlockID]
    static let fallbackDisplayPrice = "$4.99"
}
```

### Step 3: Verify config and build

Run:

```bash
python3 -m json.tool TurnTimer.storekit >/dev/null
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected:
- StoreKit config lints.
- Build-for-testing ends with `** TEST BUILD SUCCEEDED **`.

### Step 4: Commit

```bash
git add TurnTimer.storekit 'Visual Timer/ProProduct.swift' 'Visual Timer.xcodeproj/project.pbxproj'
git commit -m "Add StoreKit Pro product configuration"
```

---

## Task 2: Central StoreKit 2 Pro Access Model

**Files:**
- Create: `Visual Timer/ProAccessViewModel.swift`
- Modify: `Visual Timer/SettingsView.swift`
- Modify: `Visual Timer/GamePlaybackView.swift`
- Modify: `Visual Timer/MainTabView.swift`

**Interfaces:**
- Produces `ProAccessViewModel: ObservableObject`.
- Produces purchase, restore, product loading, entitlement refresh, and transaction listener.
- Settings shows Pro status, purchase CTA, and Restore Purchases.

### Step 1: Add `ProAccessViewModel`

Create `Visual Timer/ProAccessViewModel.swift`:

```swift
import Foundation
import StoreKit

@MainActor
final class ProAccessViewModel: ObservableObject {

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case purchased
        case pending
        case failed(String)
    }

    @Published private(set) var product: Product?
    @Published private(set) var isProUnlocked = false
    @Published private(set) var purchaseState: PurchaseState = .idle

    private var transactionTask: Task<Void, Never>?

    var displayPrice: String {
        product?.displayPrice ?? ProProduct.fallbackDisplayPrice
    }

    init() {
        transactionTask = observeTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionTask?.cancel()
    }

    func loadProducts() async {
        purchaseState = .loading
        do {
            let products = try await Product.products(for: Array(ProProduct.unlockIDs))
            product = products.first { $0.id == ProProduct.unlockID }
            purchaseState = isProUnlocked ? .purchased : .idle
        } catch {
            purchaseState = .failed("Unable to load Pro purchase.")
        }
    }

    func purchasePro() async {
        guard let product else {
            await loadProducts()
            guard self.product != nil else { return }
            await purchasePro()
            return
        }

        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = verifiedTransaction(from: verification) else {
                    purchaseState = .failed("The purchase could not be verified.")
                    return
                }
                await grantEntitlement(for: transaction)
                await transaction.finish()
                purchaseState = .purchased
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = isProUnlocked ? .purchased : .idle
            @unknown default:
                purchaseState = .failed("The purchase could not be completed.")
            }
        } catch {
            purchaseState = .failed("The purchase could not be completed.")
        }
    }

    func restorePurchases() async {
        purchaseState = .loading
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = isProUnlocked ? .purchased : .idle
        } catch {
            purchaseState = .failed("Restore failed. Please try again.")
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result),
                  ProProduct.unlockIDs.contains(transaction.productID),
                  transaction.revocationDate == nil
            else { continue }
            unlocked = true
        }
        isProUnlocked = unlocked
        if unlocked {
            purchaseState = .purchased
        }
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard let transaction = verifiedTransaction(from: transactionResult) else { return }
        if ProProduct.unlockIDs.contains(transaction.productID), transaction.revocationDate == nil {
            await grantEntitlement(for: transaction)
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func grantEntitlement(for transaction: Transaction) async {
        if ProProduct.unlockIDs.contains(transaction.productID), transaction.revocationDate == nil {
            isProUnlocked = true
        }
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }
}
```

If the compiler requires `Product.PurchaseResult.success` or `VerificationResult` handling changes under this Xcode, adjust to the local SDK while preserving:
- product loading from `Product.products(for:)`
- transaction listener from `Transaction.updates`
- entitlement refresh from `Transaction.currentEntitlements`
- `transaction.finish()` after verified transactions
- `AppStore.sync()` for restore

### Step 2: Wire model into the root

In `MainTabView`, add:

```swift
    @StateObject private var proAccess = ProAccessViewModel()
```

Pass `proAccess` into `GamePlaybackView`, `GameEditorView`, and `HistoryView`.

### Step 3: Add restore and purchase entry point in Settings

Update `SettingsView` to accept:

```swift
    @ObservedObject var proAccess: ProAccessViewModel
```

Add a `Turn Timer Pro` section below the sound section:

```swift
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(proAccess.isProUnlocked ? "Unlocked" : "Free")
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                    }

                    if !proAccess.isProUnlocked {
                        Button {
                            Task { await proAccess.purchasePro() }
                        } label: {
                            Text("Unlock Pro \(proAccess.displayPrice)")
                        }
                    }

                    Button {
                        Task { await proAccess.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                    }
                } header: {
                    Text("Turn Timer Pro")
                } footer: {
                    Text("Pro unlocks unlimited templates, full history export, and future sync, sharing, and widgets.")
                }
```

Keep this section dismissible and never show it on launch automatically.

### Step 4: Verify build

Run:

```bash
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** TEST BUILD SUCCEEDED **`.

### Step 5: Commit

```bash
git add 'Visual Timer/ProAccessViewModel.swift' 'Visual Timer/SettingsView.swift' 'Visual Timer/GamePlaybackView.swift' 'Visual Timer/MainTabView.swift'
git commit -m "Add Pro access StoreKit model"
```

---

## Task 3: Pro Paywall and Template Save Gate

**Files:**
- Create: `Visual Timer/ProPaywallView.swift`
- Create: `Visual Timer/ProFeature.swift`
- Create: `Visual Timer/TemplateSavePolicy.swift`
- Modify: `Visual Timer/GameEditorViewModel.swift`
- Modify: `Visual Timer/GameEditorView.swift`
- Modify: `Visual Timer/Theme.swift`
- Modify: `Visual TimerTests/Visual_TimerTests.swift`

**Interfaces:**
- Produces a dismissible paywall sheet for natural upgrade points.
- Produces a one-custom-template free limit.
- Free users can start built-in templates and run timers without interruption.

### Step 1: Add feature reasons

Create `Visual Timer/ProFeature.swift`:

```swift
import Foundation

enum ProFeature: Identifiable, Equatable {
    case unlimitedTemplates
    case historyExport
    case fullHistory

    var id: String {
        switch self {
        case .unlimitedTemplates: return "unlimited-templates"
        case .historyExport: return "history-export"
        case .fullHistory: return "full-history"
        }
    }

    var title: String {
        switch self {
        case .unlimitedTemplates: return "Save unlimited templates"
        case .historyExport: return "Export session history"
        case .fullHistory: return "View full history"
        }
    }

    var message: String {
        switch self {
        case .unlimitedTemplates:
            return "Free includes starter templates and one custom saved template. Pro unlocks unlimited saved templates."
        case .historyExport:
            return "Pro unlocks exporting completed sessions for sharing or archiving."
        case .fullHistory:
            return "Free keeps recent sessions. Pro unlocks your full local history."
        }
    }
}
```

### Step 2: Add template save policy

Create `Visual Timer/TemplateSavePolicy.swift`:

```swift
import Foundation

enum TemplateSavePolicy {
    static func canSaveTemplate(
        isProUnlocked: Bool,
        lastSavedFileName: String,
        proposedFileName: String
    ) -> Bool {
        guard !isProUnlocked else { return true }
        guard !lastSavedFileName.isEmpty else { return true }
        return lastSavedFileName == proposedFileName
    }
}
```

This matches the current Phase 1 storage model, where the app has one user-facing last saved template but does not yet have a full template library browser. The full saved-template library can land with Phase 3 sync/shared templates.

### Step 3: Add tests for template policy

In `Visual TimerTests/Visual_TimerTests.swift`, add:

```swift
    // MARK: - TemplateSavePolicy

    func testTemplateSavePolicy_freeAllowsFirstTemplate() {
        XCTAssertTrue(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: false,
            lastSavedFileName: "",
            proposedFileName: "Game Night.vtgame"
        ))
    }

    func testTemplateSavePolicy_freeAllowsOverwritingExistingTemplate() {
        XCTAssertTrue(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: false,
            lastSavedFileName: "Game Night.vtgame",
            proposedFileName: "Game Night.vtgame"
        ))
    }

    func testTemplateSavePolicy_freeBlocksSecondTemplate() {
        XCTAssertFalse(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: false,
            lastSavedFileName: "Game Night.vtgame",
            proposedFileName: "Recipe Steps.vtgame"
        ))
    }

    func testTemplateSavePolicy_proAllowsSecondTemplate() {
        XCTAssertTrue(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: true,
            lastSavedFileName: "Game Night.vtgame",
            proposedFileName: "Recipe Steps.vtgame"
        ))
    }
```

### Step 4: Gate explicit Save, not timer Start

In `GameEditorViewModel`, add:

```swift
    enum TemplateSaveResult: Equatable {
        case saved
        case requiresPro
        case failed([ParseError])
    }
```

Add a helper:

```swift
    private var currentTemplateFileName: String {
        "\(gameTitle).vtgame"
    }
```

Replace `saveToDocuments()` with:

```swift
    func saveToDocuments(isProUnlocked: Bool) -> TemplateSaveResult {
        guard TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: isProUnlocked,
            lastSavedFileName: lastGameFileName,
            proposedFileName: currentTemplateFileName
        ) else {
            return .requiresPro
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(currentTemplateFileName)
        let result = save(to: url)
        if result.0 {
            lastGameFileName = currentTemplateFileName
            return .saved
        }
        return .failed(result.1)
    }
```

Keep `autoSave()` ungated so Start never shows a paywall. If needed, update it to use `currentTemplateFileName` but do not call `TemplateSavePolicy` there.

### Step 5: Add paywall view

Create `Visual Timer/ProPaywallView.swift`:

```swift
import SwiftUI

struct ProPaywallView: View {
    let feature: ProFeature
    @ObservedObject var proAccess: ProAccessViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(feature.title)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ColorValue.textPrimary)
                    Text(feature.message)
                        .font(.body)
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Unlimited saved templates", systemImage: "rectangle.stack.badge.plus")
                    Label("Full history and export", systemImage: "square.and.arrow.up")
                    Label("Ready for sync, sharing, and widgets", systemImage: "icloud")
                }
                .foregroundStyle(Theme.ColorValue.textPrimary)

                Spacer()

                Button {
                    Task { await proAccess.purchasePro() }
                } label: {
                    Text("Unlock Pro \(proAccess.displayPrice)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(proAccess.purchaseState == .purchasing)

                Button {
                    Task { await proAccess.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Theme.ColorValue.appBackground)
            .navigationTitle("Turn Timer Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
            .onChange(of: proAccess.isProUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }
}
```

If the paywall needs error/pending feedback, add a compact status text below the primary button using `proAccess.purchaseState`.

### Step 6: Wire Save to paywall

Update `GameEditorView` to accept:

```swift
    @ObservedObject var proAccess: ProAccessViewModel
    @State private var requestedProFeature: ProFeature?
```

In `saveGame()`:

```swift
        let result = editor.saveToDocuments(isProUnlocked: proAccess.isProUnlocked)
        switch result {
        case .saved:
            saveAlertMessage = "Template saved to Documents."
            showSaveAlert = true
        case .requiresPro:
            requestedProFeature = .unlimitedTemplates
        case .failed(let errors):
            saveAlertMessage = errors.map(\.message).joined(separator: "\n")
            showSaveAlert = true
        }
```

Add a sheet:

```swift
            .sheet(item: $requestedProFeature) { feature in
                ProPaywallView(feature: feature, proAccess: proAccess)
            }
```

### Step 7: Verify and commit

Run:

```bash
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected:
- Build-for-testing succeeds.
- App build succeeds.

Commit:

```bash
git add 'Visual Timer/ProFeature.swift' 'Visual Timer/TemplateSavePolicy.swift' 'Visual Timer/ProPaywallView.swift' 'Visual Timer/GameEditorViewModel.swift' 'Visual Timer/GameEditorView.swift' 'Visual Timer/Theme.swift' 'Visual TimerTests/Visual_TimerTests.swift'
git commit -m "Gate extra templates behind Pro"
```

---

## Task 4: History Export and Full History Gate

**Files:**
- Create: `Visual Timer/HistoryAccessPolicy.swift`
- Modify: `Visual Timer/HistoryViewModel.swift`
- Modify: `Visual Timer/HistoryView.swift`
- Modify: `Visual Timer/SessionDetailView.swift`
- Modify: `Visual Timer/MainTabView.swift`
- Modify: `Visual TimerTests/Visual_TimerTests.swift`

**Interfaces:**
- Free users see recent local history only.
- Pro users see full local history.
- Export requires Pro.

### Step 1: Add history policy

Create `Visual Timer/HistoryAccessPolicy.swift`:

```swift
import Foundation

enum HistoryAccessPolicy {
    static let freeRecordLimit = 5

    static func visibleRecords(_ records: [GameRecord], isProUnlocked: Bool) -> [GameRecord] {
        guard !isProUnlocked else { return records }
        return Array(records.prefix(freeRecordLimit))
    }

    static func isLimited(records: [GameRecord], isProUnlocked: Bool) -> Bool {
        !isProUnlocked && records.count > freeRecordLimit
    }
}
```

### Step 2: Add tests

Add tests with lightweight `GameRecord` factories:

```swift
    // MARK: - HistoryAccessPolicy

    func testHistoryAccessPolicy_freeLimitsRecords() {
        let records = makeHistoryRecords(count: 7)

        let visible = HistoryAccessPolicy.visibleRecords(records, isProUnlocked: false)

        XCTAssertEqual(visible.count, HistoryAccessPolicy.freeRecordLimit)
        XCTAssertTrue(HistoryAccessPolicy.isLimited(records: records, isProUnlocked: false))
    }

    func testHistoryAccessPolicy_proShowsAllRecords() {
        let records = makeHistoryRecords(count: 7)

        let visible = HistoryAccessPolicy.visibleRecords(records, isProUnlocked: true)

        XCTAssertEqual(visible.count, 7)
        XCTAssertFalse(HistoryAccessPolicy.isLimited(records: records, isProUnlocked: true))
    }

    private func makeHistoryRecords(count: Int) -> [GameRecord] {
        (0..<count).map { index in
            GameRecord(
                id: UUID(),
                gameTitle: "Session \(index)",
                session: GameSession(events: []),
                playerNames: [],
                playedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
    }
```

Place helper near the bottom of `Visual_TimerTests`.

### Step 3: Update history screen

Update `HistoryView` to accept:

```swift
    @ObservedObject var proAccess: ProAccessViewModel
    @State private var requestedProFeature: ProFeature?
```

Use:

```swift
    private var visibleRecords: [GameRecord] {
        HistoryAccessPolicy.visibleRecords(history.records, isProUnlocked: proAccess.isProUnlocked)
    }
```

In the list, iterate `visibleRecords` and adjust delete offsets accordingly:

```swift
            ForEach(visibleRecords) { record in
                NavigationLink {
                    SessionDetailView(record: record, history: history, proAccess: proAccess)
                } label: {
                    recordRow(record)
                }
                .listRowBackground(Theme.ColorValue.circleBackground)
            }
```

After the records, show a Pro row when limited:

```swift
            if HistoryAccessPolicy.isLimited(records: history.records, isProUnlocked: proAccess.isProUnlocked) {
                Button {
                    requestedProFeature = .fullHistory
                } label: {
                    Label("Unlock full history", systemImage: "lock.open")
                }
                .listRowBackground(Theme.ColorValue.circleBackground)
            }
```

Add:

```swift
            .sheet(item: $requestedProFeature) { feature in
                ProPaywallView(feature: feature, proAccess: proAccess)
            }
```

### Step 4: Gate export in detail screen

Update `SessionDetailView` to accept:

```swift
    @ObservedObject var proAccess: ProAccessViewModel
    @State private var requestedProFeature: ProFeature?
```

Change export button action:

```swift
                    guard proAccess.isProUnlocked else {
                        requestedProFeature = .historyExport
                        return
                    }
                    if history.exportURL(for: record) != nil {
                        showExporter = true
                    }
```

Add a paywall sheet:

```swift
        .sheet(item: $requestedProFeature) { feature in
            ProPaywallView(feature: feature, proAccess: proAccess)
        }
```

Keep delete free.

### Step 5: Verify and commit

Run:

```bash
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: both succeed.

Commit:

```bash
git add 'Visual Timer/HistoryAccessPolicy.swift' 'Visual Timer/HistoryViewModel.swift' 'Visual Timer/HistoryView.swift' 'Visual Timer/SessionDetailView.swift' 'Visual Timer/MainTabView.swift' 'Visual TimerTests/Visual_TimerTests.swift'
git commit -m "Gate history export behind Pro"
```

---

## Task 5: Final StoreKit Verification, Docs, and PR

**Files:**
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `CLAUDE.md`
- Modify: no source files unless verification exposes a bug.

**Interfaces:**
- Produces Phase 2 docs and GitHub PR.

### Step 1: Update docs

Update `README.md` Product Roadmap / Core Features to say Phase 2 adds:
- $4.99 one-time Pro unlock.
- Free includes starter templates and one custom saved template.
- Pro unlocks additional saved templates plus full history/export.
- StoreKit config is available for local testing.

Update `CONTRIBUTING.md` with:

```markdown
## Monetization Rules

Turn Timer uses a non-consumable StoreKit 2 Pro unlock with product ID
`turntimer.pro.unlock`. Do not block quick timer or built-in starter templates
behind Pro. Pro gates reuse and portability: additional saved templates, full
history/export, sync, sharing, widgets, and advanced customization.
```

Update `CLAUDE.md` with a matching note under Project Context or Architecture.

### Step 2: Final scans

Run:

```bash
rg -n "turntimer\\.pro\\.unlock|Turn Timer Pro|StoreKit|Restore Purchases|Unlock Pro" 'Visual Timer' README.md CONTRIBUTING.md CLAUDE.md TurnTimer.storekit
rg -n '"Game Editor"|"Visual Game Timer"|No games|Complete a game|Game over|Game started|Player name|Counts as player|Players \\(' 'Visual Timer' README.md CLAUDE.md CONTRIBUTING.md 'Visual Timer.xcodeproj/project.pbxproj' || true
git diff --check origin/codex/turn-timer-phase1...HEAD
```

Expected:
- Product ID appears in StoreKit/config/docs/Pro code.
- Stale public copy scan has no user-facing hits.
- Diff check passes.

### Step 3: Final builds

Run:

```bash
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Expected:
- `** TEST BUILD SUCCEEDED **`
- iOS `** BUILD SUCCEEDED **`
- watchOS `** BUILD SUCCEEDED **`

Optional focused test attempt:

```bash
gtimeout 120s xcodebuild test-without-building -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'Visual TimerTests/Visual_TimerTests/testTemplateSavePolicy_freeBlocksSecondTemplate'
```

If this times out before execution, record it as the known local simulator/XCTest launch issue.

### Step 4: Commit docs if changed

```bash
git add README.md CONTRIBUTING.md CLAUDE.md
git commit -m "Document Pro unlock behavior"
```

### Step 5: Push and open stacked PR

```bash
git push -u origin codex/turn-timer-phase2
gh pr create --base codex/turn-timer-phase1 --head codex/turn-timer-phase2 --title "Add Turn Timer Pro unlock" --body-file -
```

PR body must include:
- Summary of StoreKit Pro unlock.
- What free users can still do.
- What Pro unlocks.
- Verification commands and outcomes.
- Note that the PR is stacked on Phase 1.

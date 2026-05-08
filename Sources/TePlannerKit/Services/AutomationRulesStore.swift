import Foundation
import Combine

/// Fetches automation rules from the backend, exposes them for the
/// engine + UI, and handles one-shot migration of legacy SettingsStore
/// thresholds on first successful fetch.
///
/// Phase 10.3.B: replaces the hardcoded `PresetSpecs.allPresets`
/// registry that 10.2.B used as a placeholder. The visual builder
/// (10.3.C) is the primary write path; this store handles the read +
/// initial migration.
@MainActor
public final class AutomationRulesStore: ObservableObject {
    @Published public private(set) var rules: [RuleRecord] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: String?

    private let apiService: APIServiceProtocol
    private let settings: SettingsStore
    private let migrationFlagKey = "automations_settings_migration_done_v1"
    private let leftUnlockedMigrationFlagKey = "automations_left_unlocked_lock_migration_v1"

    public init(apiService: APIServiceProtocol, settings: SettingsStore) {
        self.apiService = apiService
        self.settings = settings
    }

    /// Pull from /api/v1/automations. On first ever success, migrate
    /// any user-customized SettingsStore thresholds into the matching
    /// preset rules so the user doesn't lose their slider setting.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let result = await apiService.listAutomations()
        switch result {
        case .success(let fetched):
            await applyAndMaybeMigrate(fetched)
            lastError = nil
        case .failure(let error):
            Log.api.error("automations list failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    /// Update one rule's spec / enabled / name on backend, then
    /// refresh the local cache from the response.
    public func update(id: String, name: String? = nil, enabled: Bool? = nil, spec: RuleSpec? = nil) async -> Bool {
        let result = await apiService.updateAutomation(id: id, name: name, enabled: enabled, spec: spec)
        switch result {
        case .success(let updated):
            if let idx = rules.firstIndex(where: { $0.id == id }) {
                rules[idx] = updated
            }
            return true
        case .failure(let error):
            Log.api.error("automation update failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            return false
        }
    }

    public func delete(id: String) async -> Bool {
        let result = await apiService.deleteAutomation(id: id)
        switch result {
        case .success:
            rules.removeAll { $0.id == id }
            return true
        case .failure(let error):
            Log.api.error("automation delete failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            return false
        }
    }

    public func create(name: String, enabled: Bool = true, spec: RuleSpec) async -> RuleRecord? {
        let result = await apiService.createAutomation(name: name, enabled: enabled, spec: spec)
        switch result {
        case .success(let new):
            rules.append(new)
            return new
        case .failure(let error):
            Log.api.error("automation create failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Internals

    /// Match a preset by id and return a new spec with `for_minutes`
    /// (or `enabled`) overridden to the user's saved SettingsStore
    /// preference.
    private func applyAndMaybeMigrate(_ fetched: [RuleRecord]) async {
        rules = fetched
        await maybeUpgradeLeftUnlockedLockCapability(fetched)
        let alreadyMigrated = UserDefaults.standard.bool(forKey: migrationFlagKey)
        guard !alreadyMigrated else { return }

        // Snapshot the user's SettingsStore values before we touch
        // anything. Defaults match preset thresholds — nothing to
        // migrate if a user never moved the slider.
        let storedCamp = settings.campModeReminderMinutes
        let storedSentry = settings.sentryReminderMinutes
        let storedCabin = settings.cabinOverheatReminderMinutes
        let storedChargeCompleteOn = settings.chargeCompleteReminderEnabled

        for record in fetched {
            switch record.presetId {
            case "camp_mode_overstay":
                if storedCamp != 120 {
                    await migratePresetThreshold(record, minutes: storedCamp)
                }
            case "sentry_mode_overstay":
                if storedSentry != 1440 {
                    await migratePresetThreshold(record, minutes: storedSentry)
                }
            case "cabin_overheat_alert":
                if storedCabin != 60 {
                    await migratePresetThreshold(record, minutes: storedCabin)
                }
            case "charge_complete_reminder":
                if storedChargeCompleteOn != record.enabled {
                    _ = await update(id: record.id, enabled: storedChargeCompleteOn)
                }
            default:
                break
            }
        }
        UserDefaults.standard.set(true, forKey: migrationFlagKey)
        Log.app.notice("automations: migrated SettingsStore thresholds → backend")
    }

    /// One-shot migration: upgrade the leftUnlocked preset rule's
    /// primary action from `automation.dismiss` (the original
    /// 「我知道了」behaviour) to `tesla.security.door_lock`
    /// (「锁车」). Only fires when the rule's spec EXACTLY matches
    /// the canonical legacy form — any user customisation (different
    /// title, body, label, severity, threshold) suppresses the
    /// migration so we don't overwrite intentional changes.
    ///
    /// Run-once: persists `leftUnlockedMigrationFlagKey` after first
    /// successful (or skipped-as-customised) attempt.
    private func maybeUpgradeLeftUnlockedLockCapability(_ fetched: [RuleRecord]) async {
        guard !UserDefaults.standard.bool(forKey: leftUnlockedMigrationFlagKey) else {
            return
        }
        guard let record = fetched.first(where: {
            $0.presetId == "left_unlocked_warning"
        }) else {
            UserDefaults.standard.set(true, forKey: leftUnlockedMigrationFlagKey)
            return
        }

        // The canonical legacy spec we know how to safely upgrade.
        // Any user customisation diverges from this and we bail.
        guard isLegacyLeftUnlockedSpec(record.spec) else {
            Log.app.notice("automations: leftUnlocked rule customised — skipping lock-capability migration")
            UserDefaults.standard.set(true, forKey: leftUnlockedMigrationFlagKey)
            return
        }

        // Build the upgraded spec — preserve everything except the
        // primary_action_label + capability inside actions_above[0].
        guard var spec = record.spec as RuleSpec?,
              case .array(var aboveArr) = spec["actions_above"] ?? .null,
              !aboveArr.isEmpty,
              case .object(var actionDict) = aboveArr[0] else {
            UserDefaults.standard.set(true, forKey: leftUnlockedMigrationFlagKey)
            return
        }
        actionDict["primary_action_label"] = .string("锁车")
        actionDict["capability"] = .string("tesla.security.door_lock")
        aboveArr[0] = .object(actionDict)
        spec["actions_above"] = .array(aboveArr)

        let ok = await update(id: record.id, spec: spec)
        if ok {
            Log.app.notice("automations: leftUnlocked upgraded → 锁车 / tesla.security.door_lock")
        } else {
            Log.app.error("automations: leftUnlocked upgrade failed: \(self.lastError ?? "?", privacy: .public)")
        }
        UserDefaults.standard.set(true, forKey: leftUnlockedMigrationFlagKey)
    }

    private func isLegacyLeftUnlockedSpec(_ spec: RuleSpec) -> Bool {
        guard case .array(let arr) = spec["actions_above"] ?? .null,
              arr.count == 1,
              case .object(let action) = arr[0] else { return false }
        return action.string("primary_action_label") == "我知道了"
            && action.string("capability") == "automation.dismiss"
    }

    private func migratePresetThreshold(_ record: RuleRecord, minutes: Int) async {
        // Mutate the trigger.for_minutes of the spec, leaving the rest
        // alone. If minutes==0 we instead disable the rule (matches
        // the legacy SettingsStore semantic where threshold==0 meant
        // "rule off").
        var spec = record.spec
        if minutes == 0 {
            _ = await update(id: record.id, enabled: false)
            return
        }
        if case .object(var trigger) = spec["trigger"] ?? .null {
            trigger["for_minutes"] = .int(minutes)
            spec["trigger"] = .object(trigger)
        }
        _ = await update(id: record.id, spec: spec)
    }
}

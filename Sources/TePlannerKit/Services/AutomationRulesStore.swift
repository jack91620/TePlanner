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

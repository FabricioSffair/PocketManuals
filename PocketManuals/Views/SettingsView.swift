//
//  SettingsView.swift
//  PocketManuals
//

import SwiftUI

/// The provider and keys, then Pocket Manuals' own options.
struct SettingsView: View {
    @Environment(ProviderSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Toggle("Run agents on Apple Intelligence", isOn: $settings.agentsOnDevice)
                    Toggle("Fall back to \(settings.cloudProvider.title) when the context is full", isOn: $settings.fallsBackWhenContextFull)
                        .disabled(!settings.agentsOnDevice)
                } footer: {
                    Text(agentsFooter)
                }

                Section {
                    Picker("Cloud provider", selection: $settings.cloudProvider) {
                        ForEach(CloudProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                } footer: {
                    Text(settings.agentsOnDevice
                         ? "Not used while the agents run on Apple Intelligence."
                         : "The provider that answers questions about your manuals.")
                }

                Section("API keys") {
                    ForEach(CloudProvider.allCases) { provider in
                        KeyField(provider: provider)
                    }
                }

                Section {
                    RailtownKeyField(
                        title: "Logs",
                        stored: settings.railtownLogsKey,
                        isAccepted: settings.isLoggerConfigured,
                        save: settings.setRailtownLogsKey
                    )
                    RailtownKeyField(
                        title: "Agent runs",
                        stored: settings.conductrAgentRunsKey,
                        isAccepted: settings.isTraceUploadConfigured,
                        save: settings.setConductrAgentRunsKey
                    )
                } header: {
                    Text("Railtown")
                } footer: {
                    Text(railtownFooter)
                }

                Section {
                    Toggle("Allow OpenAI embeddings", isOn: $settings.allowsCloudEmbeddings)
                } footer: {
                    Text("The index uses Apple's on-device embedding model. On: when that model is missing, it embeds with OpenAI instead, which sends the indexed text to OpenAI and needs an OpenAI key. Off: indexing never leaves the device, and search is unavailable without the on-device model.")
                }

                ManualsSettingsSection()
            }
            .groupedFormOnMac()
            .navigationTitle("Settings")
        }
    }

    private var agentsFooter: String {
        let status = ProviderSettings.onDeviceStatusText
        guard settings.agentsOnDevice else {
            return "Off: the agents run on the cloud provider below. \(status)"
        }
        return "On: the Answerer and the Verifier run on-device. \(status)"
            + (ProviderSettings.onDeviceAvailable ? "" : " Questions cannot run until it is available.")
            + " " + fallbackNote
    }

    /// What the fallback switch does, and whether it can act right now.
    private var fallbackNote: String {
        guard settings.fallsBackWhenContextFull else {
            return "Cloud fallback is off: an agent whose prompt outgrows the on-device context window fails the run."
        }
        let provider = settings.cloudProvider.title
        return settings.hasCloudKey
            ? "When one agent's prompt outgrows the on-device context window, that agent alone reruns on \(provider)."
            : "Cloud fallback needs a \(provider) API key; without one, an agent whose prompt outgrows the on-device context window fails the run."
    }

    private var railtownFooter: String {
        func state(_ key: String, _ accepted: Bool) -> String {
            accepted ? "on" : (key.isEmpty ? "off, no key" : "off, key not accepted")
        }
        return "Logs: the app's logs, and the errors RailtracksSwift reports when a run fails (railtown-swift-logger). Agent runs: each run's agent trace, prompts and tool results included, uploaded to Conductr. Logs are \(state(settings.railtownLogsKey, settings.isLoggerConfigured)); agent runs are \(state(settings.conductrAgentRunsKey, settings.isTraceUploadConfigured))."
    }
}

private struct KeyField: View {
    @Environment(ProviderSettings.self) private var settings
    let provider: CloudProvider
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(provider.title).frame(width: 90, alignment: .leading)
            SecureField("paste key", text: $draft)
                .focused($focused)
                .neverCapitalizes()
                .autocorrectionDisabled()
                .onSubmit { settings.setKey(draft, for: provider) }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { settings.setKey(draft, for: provider) }
                }
            if !settings.key(for: provider).isEmpty {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .onAppear { draft = settings.key(for: provider) }
    }
}

/// One Railtown key: saved to the Keychain on submit or when the field loses focus, which
/// reconfigures its pipeline right away. A checkmark when accepted, a warning when not.
private struct RailtownKeyField: View {
    let title: String
    let stored: String
    let isAccepted: Bool
    let save: (String) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(title).frame(width: 90, alignment: .leading)
            SecureField("paste key", text: $draft)
                .focused($focused)
                .neverCapitalizes()
                .autocorrectionDisabled()
                .onSubmit { commit() }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
            if isAccepted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if !stored.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
        .onAppear { draft = stored }
    }

    private func commit() {
        guard draft != stored else { return }
        save(draft)
    }
}

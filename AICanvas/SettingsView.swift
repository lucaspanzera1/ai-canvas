import SwiftUI

struct SettingsView: View {
    @ObservedObject var syncManager: SyncManager
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var localization = LocalizationManager.shared
    @State private var showSyncSettings = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Idioma", selection: $localization.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                } header: {
                    Text("Idioma")
                } footer: {
                    Text("Muda o idioma do app na hora, independente do idioma do sistema.")
                }

                Section {
                    Button {
                        showSyncSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .frame(width: 20)
                            Text("Sincronização")
                            Spacer()
                            if !SyncSettings.load().isConfigured {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 12))
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Servidor")
                }
            }
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .sheet(isPresented: $showSyncSettings) {
                SyncSettingsView(syncManager: syncManager)
            }
        }
    }
}

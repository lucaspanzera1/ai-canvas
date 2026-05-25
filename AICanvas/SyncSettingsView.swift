import SwiftUI

struct SyncSettingsView: View {
    @ObservedObject var syncManager: SyncManager
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL: String = ""
    @State private var apiKey: String = ""
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var resultIsError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://sync.seudominio.com", text: $serverURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("URL do Servidor")
                } footer: {
                    Text("Endereço do seu homelab via Cloudflare Tunnel. Sem barra no final.")
                }

                Section {
                    SecureField("API Key", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Chave de Autenticação")
                } footer: {
                    Text("A chave gerada pelo script setup.sh no servidor.")
                }

                Section {
                    Button {
                        saveAndSync()
                    } label: {
                        HStack {
                            if syncManager.isSyncing {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(syncManager.isSyncing ? "Sincronizando…" : "Salvar e Sincronizar")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(serverURL.isEmpty || apiKey.isEmpty || syncManager.isSyncing)
                }

                if let lastSync = syncManager.lastSyncDate {
                    Section("Último Sync") {
                        Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = syncManager.lastError {
                    Section("Erro") {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Sincronização")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear {
                let s = SyncSettings.load()
                serverURL = s.serverURL
                apiKey = s.apiKey
            }
            .alert(resultMessage, isPresented: $showResult) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func saveAndSync() {
        var settings = SyncSettings(serverURL: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                    apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        // Remove trailing slash from URL
        while settings.serverURL.hasSuffix("/") {
            settings.serverURL = String(settings.serverURL.dropLast())
        }
        settings.save()

        Task {
            let result = await syncManager.sync()
            switch result {
            case .success(let pushed, let pulled):
                resultMessage = "Sync concluído! Enviados: \(pushed) | Baixados: \(pulled)"
                resultIsError = false
            case .failure(let msg):
                resultMessage = "Falha: \(msg)"
                resultIsError = true
            }
            showResult = true
        }
    }
}

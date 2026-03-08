import SwiftUI

/// Onboarding screen shown on first launch to collect the Groq API key.
struct APIKeyOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showKey = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "cpu")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                // Title
                VStack(spacing: 8) {
                    Text("AI Canvas")
                        .font(.largeTitle.bold())

                    Text("Configure sua API Key do Groq para\nusar o assistente de IA.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Groq API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Group {
                            if showKey {
                                TextField("gsk_...", text: $apiKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("gsk_...", text: $apiKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                        .textFieldStyle(.plain)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 40)

                // Button
                Button {
                    saveKey()
                } label: {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Continuar")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(apiKey.isEmpty ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(apiKey.isEmpty || isValidating)
                .padding(.horizontal, 40)

                // Link
                Link("Obter API Key no Groq Console →",
                     destination: URL(string: "https://console.groq.com/keys")!)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
                Spacer()
            }
        }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Informe a API Key."
            return
        }

        isValidating = true
        errorMessage = nil

        // Quick validation call to Groq
        Task {
            let isValid = await GroqService.shared.validateKey(trimmed)

            await MainActor.run {
                isValidating = false
                if isValid {
                    KeychainManager.shared.saveKey(trimmed)
                    withAnimation {
                        isPresented = false
                    }
                } else {
                    errorMessage = "API Key inválida. Verifique e tente novamente."
                }
            }
        }
    }
}

#Preview {
    APIKeyOnboardingView(isPresented: .constant(true))
}

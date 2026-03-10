import SwiftUI

/// Legacy single-provider onboarding screen — Game Edition.
struct APIKeyOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showKey = false

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 80, height: 80)

                    Image(systemName: "cpu.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(AppTheme.surface)
                }

                // Title
                VStack(spacing: 12) {
                    Text("AI Canvas")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Configure sua API Key do Groq para\nusar o assistente de IA.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Input
                VStack(alignment: .leading, spacing: 10) {
                    Text("GROQ API KEY")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)

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
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                apiKey.isEmpty ? AppTheme.border : AppTheme.borderActive,
                                lineWidth: 1
                            )
                    )

                    if let errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(errorMessage)
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(AppTheme.danger)
                    }
                }
                .padding(.horizontal, 40)

                // Button
                Button {
                    saveKey()
                } label: {
                    HStack(spacing: 8) {
                        if isValidating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "key.fill")
                                .font(.system(size: 13, weight: .medium))
                        }
                        Text(isValidating ? "Validando..." : "Continuar")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        apiKey.isEmpty
                        ? AppTheme.borderHover
                        : AppTheme.accent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(apiKey.isEmpty || isValidating)
                .animation(.easeInOut(duration: 0.2), value: apiKey.isEmpty)
                .padding(.horizontal, 40)

                // Link
                Link(destination: URL(string: "https://console.groq.com/keys")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                        Text("Obter API Key no Groq Console")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.link)
                }

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

        Task {
            let isValid = await AIService.shared.validateKeyWithDebug(trimmed, for: .groq)

            await MainActor.run {
                isValidating = false
                if isValid {
                    KeychainManager.shared.saveKey(trimmed, for: .groq)
                    withAnimation(.spring(response: 0.4)) {
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

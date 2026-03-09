import SwiftUI

/// Legacy single-provider onboarding screen — Game Edition.
struct APIKeyOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showKey = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            GameTheme.background
                .ignoresSafeArea()

            // Background glow effect
            Circle()
                .fill(GameTheme.neonPurple.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(y: -100)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glowPulse)
                .scaleEffect(glowPulse ? 1.2 : 1.0)

            VStack(spacing: 32) {
                Spacer()

                // Icon with glow
                ZStack {
                    Circle()
                        .fill(GameTheme.primaryGradient)
                        .frame(width: 90, height: 90)
                        .shadow(color: GameTheme.neonPurple.opacity(0.8), radius: 20)
                        .shadow(color: GameTheme.neonCyan.opacity(0.4), radius: 40)

                    Image(systemName: "cpu.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Title
                VStack(spacing: 10) {
                    Text("AI Canvas")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(GameTheme.primaryGradient)
                        .shadow(color: GameTheme.neonPurple.opacity(0.5), radius: 10)

                    Text("Configure sua API Key do Groq para\nusar o assistente de IA.")
                        .font(.system(size: 15))
                        .foregroundStyle(GameTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Input
                VStack(alignment: .leading, spacing: 10) {
                    Text("GROQ API KEY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(GameTheme.textMuted)
                        .tracking(2)

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
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(GameTheme.textPrimary)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 14))
                                .foregroundStyle(GameTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(GameTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                apiKey.isEmpty ? GameTheme.border : GameTheme.neonPurple.opacity(0.5),
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
                        .foregroundStyle(GameTheme.neonPink)
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
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(isValidating ? "Validando..." : "Continuar")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        apiKey.isEmpty
                        ? AnyView(GameTheme.surfaceElevated)
                        : AnyView(GameTheme.primaryGradient)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(apiKey.isEmpty ? GameTheme.border : Color.clear, lineWidth: 1)
                    )
                    .shadow(
                        color: apiKey.isEmpty ? .clear : GameTheme.neonPurple.opacity(0.5),
                        radius: 12
                    )
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
                    .foregroundStyle(GameTheme.neonCyan)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation { glowPulse = true }
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

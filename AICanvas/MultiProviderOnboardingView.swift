import SwiftUI

/// Onboarding screen — Game Edition.
struct MultiProviderOnboardingView: View {
    @Binding var isPresented: Bool
    @ObservedObject var aiConfig: AIConfiguration
    @State private var selectedTab = 0
    @State private var hasConfiguredAny = false
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            // Subtle glowing orb top-center
            Circle()
                .fill(AppTheme.accent.opacity(0.04))
                .blur(radius: 80)
                .frame(width: 400, height: 400)
                .offset(y: -250)
            
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 60)
                
                // Provider cards
                TabView(selection: $selectedTab) {
                    ForEach(Array(AIProvider.allCases.enumerated()), id: \.element) { index, provider in
                        ProviderOnboardingCard(
                            provider: provider,
                            aiConfig: aiConfig,
                            onConfigured: {
                                hasConfiguredAny = true
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                navigationView
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Logo icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [.init(color: AppTheme.accent.opacity(0.8), location: 0), .init(color: AppTheme.accent, location: 1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 5)
                
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppTheme.surface)
            }
            
            VStack(spacing: 8) {
                // Title
                Text("AI Canvas")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("Configure seu arsenal de IA")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            // Step indicators
            HStack(spacing: 8) {
                ForEach(Array(AIProvider.allCases.enumerated()), id: \.element.id) { index, provider in
                    Capsule()
                        .fill(
                            selectedTab == index
                            ? AnyShapeStyle(AppTheme.textPrimary)
                            : AnyShapeStyle(
                                KeychainManager.shared.hasAPIKey(for: provider)
                                ? AppTheme.action
                                : AppTheme.border
                              )
                        )
                        .frame(width: selectedTab == index ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: selectedTab)
                }
            }
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Navigation
    
    private var navigationView: some View {
        HStack(spacing: 16) {
            if selectedTab > 0 {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        selectedTab -= 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("Anterior")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            if selectedTab < AIProvider.allCases.count - 1 {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        selectedTab += 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Próximo")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else if hasConfiguredAny || KeychainManager.shared.hasAnyAPIKey {
                Button {
                    aiConfig.updateAvailableModels()
                    withAnimation(.spring(response: 0.4)) {
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Concluir")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 50)
    }
}

// MARK: - Star Particle Removed

// MARK: - Provider Card

struct ProviderOnboardingCard: View {
    let provider: AIProvider
    @ObservedObject var aiConfig: AIConfiguration
    let onConfigured: () -> Void
    
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showKey = false
    @State private var isConfigured = false
    @State private var cardAppear = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)
                
                // Provider badge
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.08))
                        .frame(width: 100, height: 100)
                        
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 72, height: 72)
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 6)
                    
                    Image(systemName: provider.icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(AppTheme.surface)
                }
                .scaleEffect(cardAppear ? 1 : 0.6)
                .opacity(cardAppear ? 1 : 0)
                
                // Title
                VStack(spacing: 8) {
                    Text(provider.displayName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Configure sua API Key para\ndesbloquear os modelos do \(provider.displayName).")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(cardAppear ? 1 : 0)
                .offset(y: cardAppear ? 0 : 10)
                
                // Status or Input
                if isConfigured || KeychainManager.shared.hasAPIKey(for: provider) {
                    configuredView
                        .opacity(cardAppear ? 1 : 0)
                } else {
                    inputView
                        .opacity(cardAppear ? 1 : 0)
                }
                
                // Doc link
                Link(destination: URL(string: provider.keyDocURL)!) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                        Text("Como obter API Key")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.link)
                }
                .opacity(cardAppear ? 1 : 0)
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            isConfigured = KeychainManager.shared.hasAPIKey(for: provider)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
                cardAppear = true
            }
        }
        .onDisappear { cardAppear = false }
    }
    
    // MARK: - Configured
    
    private var configuredView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.action.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(AppTheme.action.opacity(0.3), lineWidth: 1))
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.action)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Configurado!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.action)
                    Text("API Key salva com sucesso")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(AppTheme.action.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.action.opacity(0.2), lineWidth: 1))
            
            Button(role: .destructive) {
                KeychainManager.shared.deleteKey(for: provider)
                isConfigured = false
                apiKey = ""
                errorMessage = nil
            } label: {
                Text("Reconfigurar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.danger)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Input
    
    private var inputView: some View {
        VStack(spacing: 16) {
            // Key input
            VStack(alignment: .leading, spacing: 8) {
                Text("API KEY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                
                HStack {
                    Group {
                        if showKey {
                            TextField(provider.keyPlaceholder, text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField(provider.keyPlaceholder, text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textPrimary)
                    
                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            apiKey.isEmpty ? AppTheme.border : AppTheme.accent.opacity(0.5),
                            lineWidth: apiKey.isEmpty ? 1 : 2
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
            
            // Save button
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
                    Text(isValidating ? "Validando..." : "Salvar \(provider.displayName)")
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
                .clipShape(Capsule())
                .shadow(color: apiKey.isEmpty ? .clear : AppTheme.accent.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(apiKey.isEmpty || isValidating)
            .animation(.easeInOut(duration: 0.2), value: apiKey.isEmpty)
            
            // Skip
            Button("Configurar depois") {
                // Just move on
            }
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textSecondary)
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Actions
    
    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            errorMessage = "Informe a API Key."
            return
        }
        
        isValidating = true
        errorMessage = nil
        
        Task {
            let isValid = await AIService.shared.validateKeyWithDebug(trimmed, for: provider)
            
            await MainActor.run {
                isValidating = false
                if isValid {
                    KeychainManager.shared.saveKey(trimmed, for: provider)
                    isConfigured = true
                    onConfigured()
                    aiConfig.updateAvailableModels()
                    
                    if aiConfig.availableModels.count == provider.defaultModels.count {
                        if let firstModel = provider.defaultModels.first {
                            aiConfig.setSelectedModel(firstModel)
                        }
                    }
                } else {
                    errorMessage = "API Key inválida. Verifique e tente novamente."
                }
            }
        }
    }
}

#Preview {
    MultiProviderOnboardingView(
        isPresented: .constant(true),
        aiConfig: AIConfiguration()
    )
}
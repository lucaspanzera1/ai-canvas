import SwiftUI

/// Onboarding screen — Premium Edition with real provider logos.
struct MultiProviderOnboardingView: View {
    @Binding var isPresented: Bool
    @ObservedObject var aiConfig: AIConfiguration
    @State private var selectedTab = 0
    @State private var hasConfiguredAny = false
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            // Subtle brand-colored glow that changes with selected provider
            Circle()
                .fill(currentProvider.brandColor.opacity(0.06))
                .blur(radius: 80)
                .frame(width: 400, height: 400)
                .offset(y: -250)
                .animation(.easeInOut(duration: 0.5), value: selectedTab)
            
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
    
    private var currentProvider: AIProvider {
        let allProviders = AIProvider.allCases
        guard selectedTab >= 0 && selectedTab < allProviders.count else {
            return allProviders[0]
        }
        return allProviders[selectedTab]
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Logo icon
            Image("AppImage")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 5)
            
            VStack(spacing: 8) {
                // Title
                Text("AI Canvas")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("Configure seu arsenal de IA")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            // Step indicators with logos
            HStack(spacing: 12) {
                ForEach(Array(AIProvider.allCases.enumerated()), id: \.element.id) { index, provider in
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            selectedTab = index
                        }
                    } label: {
                        HStack(spacing: 6) {
                            ProviderLogoView(provider: provider, size: 20, cornerRadius: 5)
                            
                            if selectedTab == index {
                                Text(provider.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, selectedTab == index ? 10 : 6)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == index
                            ? provider.brandColorLight
                            : (KeychainManager.shared.hasAPIKey(for: provider)
                               ? Color.green.opacity(0.1)
                               : AppTheme.surfaceElevated)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                selectedTab == index
                                ? provider.brandColor.opacity(0.4)
                                : (KeychainManager.shared.hasAPIKey(for: provider)
                                   ? Color.green.opacity(0.3)
                                   : AppTheme.border),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
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
                    .background(currentProvider.brandColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: currentProvider.brandColor.opacity(0.3), radius: 6, y: 3)
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
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.green.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 50)
    }
}

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
                
                // Provider logo with branded glow
                ZStack {
                    Circle()
                        .fill(provider.brandColor.opacity(0.08))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    ProviderLogoView(provider: provider, size: 80, cornerRadius: 20)
                        .shadow(color: provider.brandColor.opacity(0.4), radius: 16, y: 8)
                }
                .scaleEffect(cardAppear ? 1 : 0.6)
                .opacity(cardAppear ? 1 : 0)
                
                // Title
                VStack(spacing: 8) {
                    Text(provider.displayName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(provider.tagline)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(provider.brandColor)
                    
                    Text("Configure sua API Key para\ndesbloquear os modelos do \(provider.displayName).")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 4)
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
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                        Text("Como obter API Key")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(provider.brandColor)
                }
                .opacity(cardAppear ? 1 : 0)
                
                // Models preview
                if !provider.defaultModels.isEmpty {
                    modelsPreview
                        .opacity(cardAppear ? 1 : 0)
                }
                
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
    
    // MARK: - Models Preview
    
    private var modelsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODELOS DISPONÍVEIS")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textMuted)
            
            VStack(spacing: 4) {
                ForEach(provider.defaultModels) { model in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(provider.brandColor.opacity(0.5))
                            .frame(width: 5, height: 5)
                        Text(model.name)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.border.opacity(0.5), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Configured
    
    private var configuredView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color.green.opacity(0.3), lineWidth: 1))
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Configurado!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.green)
                    Text("API Key salva com sucesso")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                ProviderLogoView(provider: provider, size: 28, cornerRadius: 7)
                    .opacity(0.5)
            }
            .padding(16)
            .background(Color.green.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.2), lineWidth: 1))
            
            Button(role: .destructive) {
                KeychainManager.shared.deleteKey(for: provider)
                isConfigured = false
                apiKey = ""
                errorMessage = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                    Text("Reconfigurar")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(AppTheme.textSecondary)
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
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 15, design: .monospaced))
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
                            errorMessage != nil
                            ? AppTheme.danger
                            : (apiKey.isEmpty ? AppTheme.border : provider.brandColor.opacity(0.6)),
                            lineWidth: errorMessage != nil || !apiKey.isEmpty ? 2 : 1
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: apiKey.isEmpty)
                
                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text(errorMessage)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(AppTheme.danger)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            
            // Save button with provider brand color
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
                    : provider.brandColor
                )
                .clipShape(Capsule())
                .shadow(color: apiKey.isEmpty ? .clear : provider.brandColor.opacity(0.3), radius: 8, y: 4)
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
                    withAnimation(.spring(response: 0.4)) {
                        isConfigured = true
                    }
                    onConfigured()
                    aiConfig.updateAvailableModels()
                    
                    if aiConfig.availableModels.count == provider.defaultModels.count {
                        if let firstModel = provider.defaultModels.first {
                            aiConfig.setSelectedModel(firstModel)
                        }
                    }
                } else {
                    withAnimation {
                        errorMessage = "API Key inválida. Verifique e tente novamente."
                    }
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
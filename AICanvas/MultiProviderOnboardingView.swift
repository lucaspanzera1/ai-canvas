import SwiftUI

/// Onboarding screen — Game Edition.
struct MultiProviderOnboardingView: View {
    @Binding var isPresented: Bool
    @ObservedObject var aiConfig: AIConfiguration
    @State private var selectedTab = 0
    @State private var hasConfiguredAny = false
    @State private var starParticles: [StarParticle] = (0..<30).map { _ in StarParticle() }
    @State private var animateStars = false
    
    var body: some View {
        ZStack {
            // Dark background
            GameTheme.background
                .ignoresSafeArea()
            
            // Star particles
            ForEach(starParticles) { star in
                Circle()
                    .fill(.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x, y: star.y)
                    .animation(
                        .easeInOut(duration: star.duration)
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                        value: animateStars
                    )
                    .opacity(animateStars ? star.opacity : star.opacity * 0.3)
            }
            
            // Glow orbs
            ZStack {
                Circle()
                    .fill(GameTheme.neonPurple.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(GameTheme.neonCyan.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 150, y: 200)
            }
            
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
        .onAppear {
            withAnimation { animateStars = true }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Logo icon with glow
            ZStack {
                Circle()
                    .fill(GameTheme.primaryGradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: GameTheme.neonPurple.opacity(0.8), radius: 20)
                    .shadow(color: GameTheme.neonCyan.opacity(0.4), radius: 40)
                
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                // Title with gradient
                Text("AI Canvas")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameTheme.primaryGradient)
                    .shadow(color: GameTheme.neonPurple.opacity(0.5), radius: 10)
                
                Text("Configure seu arsenal de IA")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(GameTheme.textSecondary)
            }
            
            // Step indicators
            HStack(spacing: 8) {
                ForEach(Array(AIProvider.allCases.enumerated()), id: \.element.id) { index, provider in
                    Capsule()
                        .fill(
                            selectedTab == index
                            ? AnyShapeStyle(GameTheme.primaryGradient)
                            : AnyShapeStyle(
                                KeychainManager.shared.hasAPIKey(for: provider)
                                ? GameTheme.neonGreen.opacity(0.6)
                                : Color.white.opacity(0.1)
                              )
                        )
                        .frame(width: selectedTab == index ? 24 : 8, height: 8)
                        .shadow(color: selectedTab == index ? GameTheme.neonPurple.opacity(0.8) : .clear, radius: 6)
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
                            .font(.system(size: 12, weight: .bold))
                        Text("Anterior")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(GameTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(GameTheme.surfaceElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(GameTheme.border, lineWidth: 1))
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
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(GameTheme.primaryGradient)
                    .clipShape(Capsule())
                    .shadow(color: GameTheme.neonPurple.opacity(0.5), radius: 10)
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
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Entrar no jogo!")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(GameTheme.primaryGradient)
                    .clipShape(Capsule())
                    .shadow(color: GameTheme.neonPurple.opacity(0.7), radius: 16)
                    .shadow(color: GameTheme.neonCyan.opacity(0.3), radius: 30)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 50)
    }
}

// MARK: - Star Particle

struct StarParticle: Identifiable {
    let id = UUID()
    let x: CGFloat = CGFloat.random(in: 0...800)
    let y: CGFloat = CGFloat.random(in: 0...1100)
    let size: CGFloat = CGFloat.random(in: 1...3)
    let opacity: Double = Double.random(in: 0.1...0.5)
    let duration: Double = Double.random(in: 1.5...4.0)
    let delay: Double = Double.random(in: 0...3.0)
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
                
                // Provider badge
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(GameTheme.primaryGradient, lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .shadow(color: GameTheme.neonPurple.opacity(0.5), radius: 10)
                    
                    Circle()
                        .fill(GameTheme.surfaceElevated)
                        .frame(width: 84, height: 84)
                    
                    Image(systemName: provider.icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(GameTheme.primaryGradient)
                }
                .scaleEffect(cardAppear ? 1 : 0.6)
                .opacity(cardAppear ? 1 : 0)
                
                // Title
                VStack(spacing: 8) {
                    Text(provider.displayName)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(GameTheme.textPrimary)
                    
                    Text("Configure sua API Key para\ndesbloquear os modelos do \(provider.displayName).")
                        .font(.system(size: 14))
                        .foregroundStyle(GameTheme.textSecondary)
                        .multilineTextAlignment(.center)
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
                    .foregroundStyle(GameTheme.neonCyan)
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
                        .fill(GameTheme.neonGreen.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(GameTheme.neonGreen.opacity(0.5), lineWidth: 1))
                        .shadow(color: GameTheme.neonGreen.opacity(0.6), radius: 8)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(GameTheme.neonGreen)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Configurado!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(GameTheme.neonGreen)
                    Text("API Key salva com sucesso")
                        .font(.system(size: 12))
                        .foregroundStyle(GameTheme.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(GameTheme.neonGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameTheme.neonGreen.opacity(0.3), lineWidth: 1))
            
            Button(role: .destructive) {
                KeychainManager.shared.deleteKey(for: provider)
                isConfigured = false
                apiKey = ""
                errorMessage = nil
            } label: {
                Text("Reconfigurar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GameTheme.neonPink.opacity(0.8))
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
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameTheme.textMuted)
                    .tracking(2)
                
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
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
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
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(isValidating ? "Validando..." : "Salvar \(provider.displayName)")
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
            
            // Skip
            Button("Configurar depois") {
                // Just move on
            }
            .font(.system(size: 12))
            .foregroundStyle(GameTheme.textMuted)
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
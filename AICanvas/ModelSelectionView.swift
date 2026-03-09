import SwiftUI

/// Model selection view — Game Edition.
struct ModelSelectionView: View {
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isPresented: Bool
    @State private var showProviderSetup = false
    @State private var selectedProvider: AIProvider?
    @State private var searchText = ""

    var body: some View {
        ZStack {
            GameTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                gameHeader
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Current model banner
                        currentModelBanner
                        
                        if aiConfig.availableModels.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedModels.keys.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { provider in
                                providerSection(for: provider)
                            }
                        }
                        
                        // Add Provider
                        addProviderSection
                    }
                    .padding(16)
                }
            }
        }
        .sheet(isPresented: $showProviderSetup) {
            if let provider = selectedProvider {
                ProviderSetupView(
                    provider: provider,
                    isPresented: $showProviderSetup,
                    aiConfig: aiConfig
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var gameHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arsenal de IA")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(GameTheme.textPrimary)
                    Text("Escolha seu modelo de combate")
                        .font(.system(size: 12))
                        .foregroundStyle(GameTheme.textSecondary)
                }
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(GameTheme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(GameTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(GameTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Neon divider
            LinearGradient(
                colors: [GameTheme.neonPurple.opacity(0.0), GameTheme.neonPurple.opacity(0.6), GameTheme.neonCyan.opacity(0.6), GameTheme.neonCyan.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
        .background(GameTheme.surface)
    }
    
    // MARK: - Current Model Banner
    
    private var currentModelBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(GameTheme.primaryGradient)
                    .frame(width: 44, height: 44)
                    .shadow(color: GameTheme.neonPurple.opacity(0.6), radius: 8)
                
                Image(systemName: aiConfig.selectedModel.provider.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("MODELO ATIVO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameTheme.neonCyan)
                    .tracking(2)
                
                Text(aiConfig.selectedModel.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(GameTheme.textPrimary)
                
                Text(aiConfig.selectedModel.provider.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(GameTheme.textSecondary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(GameTheme.neonGreen.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .shadow(color: GameTheme.neonGreen.opacity(0.7), radius: 6)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(GameTheme.neonGreen)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GameTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [GameTheme.neonPurple.opacity(0.5), GameTheme.neonCyan.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: GameTheme.neonPurple.opacity(0.2), radius: 12)
    }
    
    // MARK: - Provider Section
    
    private var groupedModels: [AIProvider: [AIModel]] {
        Dictionary(grouping: aiConfig.availableModels) { $0.provider }
    }
    
    private func providerSection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: provider.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GameTheme.neonCyan)
                Text(provider.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameTheme.neonCyan)
                    .tracking(1.5)
                
                Spacer()
                
                Text("\(groupedModels[provider]?.count ?? 0) modelos")
                    .font(.system(size: 10))
                    .foregroundStyle(GameTheme.textMuted)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 6) {
                ForEach(groupedModels[provider] ?? []) { model in
                    modelRow(for: model)
                }
            }
        }
    }
    
    private func modelRow(for model: AIModel) -> some View {
        let isSelected = model.id == aiConfig.selectedModel.id
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                aiConfig.setSelectedModel(model)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPresented = false
            }
        } label: {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? GameTheme.neonPurple : GameTheme.border, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        Circle()
                            .fill(GameTheme.primaryGradient)
                            .frame(width: 10, height: 10)
                            .shadow(color: GameTheme.neonPurple.opacity(0.8), radius: 4)
                    }
                }
                
                Text(model.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? GameTheme.textPrimary : GameTheme.textSecondary)
                
                Spacer()
                
                if isSelected {
                    Text("SELECIONADO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(GameTheme.neonGreen)
                        .tracking(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(GameTheme.neonGreen.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(GameTheme.neonGreen.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isSelected
                ? GameTheme.neonPurple.opacity(0.1)
                : GameTheme.surfaceElevated
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                        ? GameTheme.neonPurple.opacity(0.4)
                        : GameTheme.border,
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? GameTheme.neonPurple.opacity(0.2) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(GameTheme.neonPurple.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(GameTheme.neonPurple.opacity(0.3), lineWidth: 1))
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(GameTheme.primaryGradient)
            }
            
            Text("Nenhum modelo disponível")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(GameTheme.textPrimary)
            
            Text("Configure uma API Key para\ndesbloquear seus modelos.")
                .font(.system(size: 13))
                .foregroundStyle(GameTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Add Provider
    
    private var addProviderSection: some View {
        let unconfiguredProviders = AIProvider.allCases.filter { !KeychainManager.shared.hasAPIKey(for: $0) }
        
        return Group {
            if !unconfiguredProviders.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(GameTheme.neonOrange)
                        Text("DESBLOQUEAR PROVEDORES")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(GameTheme.neonOrange)
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                        ForEach(unconfiguredProviders) { provider in
                            providerCard(for: provider)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func providerCard(for provider: AIProvider) -> some View {
        Button {
            selectedProvider = provider
            showProviderSetup = true
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(GameTheme.neonOrange.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(GameTheme.neonOrange.opacity(0.4), lineWidth: 1)
                        )
                    
                    Image(systemName: provider.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(GameTheme.neonOrange)
                }
                
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GameTheme.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("Desbloquear")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(GameTheme.neonOrange.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(GameTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GameTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Provider Setup

struct ProviderSetupView: View {
    let provider: AIProvider
    @Binding var isPresented: Bool
    @ObservedObject var aiConfig: AIConfiguration
    
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showKey = false
    
    var body: some View {
        ZStack {
            GameTheme.background
                .ignoresSafeArea()
            
            // Background glow
            Circle()
                .fill(GameTheme.neonPurple.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 100, y: -150)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") {
                        isPresented = false
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(GameTheme.textSecondary)
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("Configurar \(provider.displayName)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(GameTheme.textPrimary)
                    
                    Spacer()
                    
                    // Balance
                    Text("Cancelar").opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                LinearGradient(
                    colors: [GameTheme.neonPurple.opacity(0.0), GameTheme.neonPurple.opacity(0.4), GameTheme.neonCyan.opacity(0.4), GameTheme.neonCyan.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 30)
                        
                        // Icon
                        ZStack {
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
                        
                        VStack(spacing: 8) {
                            Text("Desbloquear \(provider.displayName)")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(GameTheme.textPrimary)
                            
                            Text("Digite sua API Key para acessar\nos modelos do \(provider.displayName).")
                                .font(.system(size: 14))
                                .foregroundStyle(GameTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Input
                        VStack(alignment: .leading, spacing: 10) {
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
                                Text(isValidating ? "Validando..." : "Salvar")
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
                        
                        Link(destination: URL(string: provider.keyDocURL)!) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 11))
                                Text("Obter API Key")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(GameTheme.neonCyan)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 32)
                }
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
            let isValid = await AIService.shared.validateKeyWithDebug(trimmed, for: provider)
            
            await MainActor.run {
                isValidating = false
                if isValid {
                    KeychainManager.shared.saveKey(trimmed, for: provider)
                    aiConfig.updateAvailableModels()
                    
                    if aiConfig.availableModels.count == provider.defaultModels.count {
                        aiConfig.setSelectedModel(provider.defaultModels.first!)
                    }
                    
                    isPresented = false
                } else {
                    errorMessage = "API Key inválida. Verifique e tente novamente."
                }
            }
        }
    }
}

#Preview {
    ModelSelectionView(
        aiConfig: AIConfiguration(),
        isPresented: .constant(true)
    )
}
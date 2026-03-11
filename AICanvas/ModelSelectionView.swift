import SwiftUI

/// Reusable provider logo view with proper sizing
struct ProviderLogoView: View {
    let provider: AIProvider
    var size: CGFloat = 36
    var cornerRadius: CGFloat = 10
    
    var body: some View {
        Image(provider.logoImageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Model selection view — Premium Edition with real logos.
struct ModelSelectionView: View {
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isPresented: Bool
    @State private var showProviderSetup = false
    @State private var selectedProvider: AIProvider?
    @State private var showDeleteConfirm = false
    @State private var providerToDelete: AIProvider?

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                gameHeader
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Current model banner
                        if !aiConfig.availableModels.isEmpty {
                            currentModelBanner
                        }
                        
                        // Configured providers
                        if !configuredProviders.isEmpty {
                            configuredProvidersSection
                        }
                        
                        if aiConfig.availableModels.isEmpty {
                            emptyState
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
        .alert("Remover Provedor", isPresented: $showDeleteConfirm, presenting: providerToDelete) { provider in
            Button("Cancelar", role: .cancel) {}
            Button("Remover", role: .destructive) {
                KeychainManager.shared.deleteKey(for: provider)
                aiConfig.updateAvailableModels()
            }
        } message: { provider in
            Text("A API Key do \(provider.displayName) será removida. Você poderá reconfigurá-la depois.")
        }
    }
    
    // MARK: - Header
    
    private var gameHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image("AppImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: AppTheme.shadowColor, radius: 2, y: 1)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modelos de IA")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Escolha seu provedor e modelo")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
        .background(AppTheme.surface)
    }
    
    // MARK: - Current Model Banner
    
    private var currentModelBanner: some View {
        HStack(spacing: 14) {
            ProviderLogoView(provider: aiConfig.selectedModel.provider, size: 44, cornerRadius: 12)
                .shadow(color: aiConfig.selectedModel.provider.brandColor.opacity(0.3), radius: 6, y: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("MODELO ATIVO")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(aiConfig.selectedModel.provider.brandColor)
                
                Text(aiConfig.selectedModel.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(aiConfig.selectedModel.provider.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(aiConfig.selectedModel.provider.brandColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(aiConfig.selectedModel.provider.brandColor)
            }
        }
        .padding(16)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(aiConfig.selectedModel.provider.brandColor.opacity(0.4), lineWidth: 1.5)
        )
    }
    
    // MARK: - Configured Providers
    
    private var configuredProviders: [AIProvider] {
        AIProvider.allCases.filter { KeychainManager.shared.hasAPIKey(for: $0) }
    }
    
    private var groupedModels: [AIProvider: [AIModel]] {
        Dictionary(grouping: aiConfig.availableModels) { $0.provider }
    }
    
    private var configuredProvidersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.action)
                Text("PROVEDORES CONFIGURADOS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 4)
            
            ForEach(configuredProviders) { provider in
                configuredProviderCard(for: provider)
            }
        }
    }
    
    private func configuredProviderCard(for provider: AIProvider) -> some View {
        VStack(spacing: 0) {
            // Provider header with logo
            HStack(spacing: 12) {
                ProviderLogoView(provider: provider, size: 36, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(groupedModels[provider]?.count ?? 0) modelos disponíveis")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Ativo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
                
                // Menu with options
                Menu {
                    Button {
                        selectedProvider = provider
                        showProviderSetup = true
                    } label: {
                        Label("Alterar API Key", systemImage: "key.fill")
                    }
                    
                    Button(role: .destructive) {
                        providerToDelete = provider
                        showDeleteConfirm = true
                    } label: {
                        Label("Remover", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Rectangle()
                .fill(AppTheme.border.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 14)
            
            // Models list
            VStack(spacing: 4) {
                ForEach(groupedModels[provider] ?? []) { model in
                    modelRow(for: model, provider: provider)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
    
    private func modelRow(for model: AIModel, provider: AIProvider) -> some View {
        let isSelected = model.id == aiConfig.selectedModel.id
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                aiConfig.setSelectedModel(model)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPresented = false
            }
        } label: {
            HStack(spacing: 10) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? provider.brandColor : AppTheme.border, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        Circle()
                            .fill(provider.brandColor)
                            .frame(width: 10, height: 10)
                    }
                }
                
                Text(model.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                
                Spacer()
                
                if isSelected {
                    Text("EM USO")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(provider.brandColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(provider.brandColorLight)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                isSelected
                ? provider.brandColorLight
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceElevated)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Text("Nenhum modelo disponível")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text("Configure uma API Key para\ndesbloquear seus modelos.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
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
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("DESBLOQUEAR PROVEDORES")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 4)
                    
                    ForEach(unconfiguredProviders) { provider in
                        providerCard(for: provider)
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
            HStack(spacing: 14) {
                ProviderLogoView(provider: provider, size: 44, cornerRadius: 12)
                    .opacity(0.7)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(provider.tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Configurar")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(provider.brandColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(provider.brandColorLight)
                .clipShape(Capsule())
            }
            .padding(14)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.border, lineWidth: 1)
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
    @State private var keyAppear = false
    @State private var isSuccess = false
    
    // Check if we're editing an existing key
    private var isEditing: Bool {
        KeychainManager.shared.hasAPIKey(for: provider)
    }
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") {
                        isPresented = false
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text(isEditing ? "Alterar \(provider.displayName)" : "Configurar \(provider.displayName)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    // Balance
                    Text("Cancelar").opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(height: 1)
                
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 30)
                        
                        // Logo with brand-colored glow
                        ZStack {
                            Circle()
                                .fill(provider.brandColor.opacity(0.08))
                                .frame(width: 120, height: 120)
                                .blur(radius: 20)
                            
                            ProviderLogoView(provider: provider, size: 80, cornerRadius: 20)
                                .shadow(color: provider.brandColor.opacity(0.35), radius: 16, y: 8)
                        }
                        .scaleEffect(keyAppear ? 1 : 0.7)
                        .opacity(keyAppear ? 1 : 0)
                        
                        VStack(spacing: 8) {
                            Text(isEditing ? "Alterar API Key" : "Desbloquear \(provider.displayName)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text(isEditing
                                 ? "Insira sua nova API Key do \(provider.displayName)."
                                 : "Digite sua API Key para acessar\nos modelos do \(provider.displayName)."
                            )
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .opacity(keyAppear ? 1 : 0)
                        .offset(y: keyAppear ? 0 : 10)
                        
                        if isSuccess {
                            // Success state
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.1))
                                        .frame(width: 64, height: 64)
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color.green)
                                }
                                
                                Text("API Key salva com sucesso!")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.green)
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Input
                            VStack(alignment: .leading, spacing: 10) {
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
                                    .font(.system(size: 14, design: .monospaced))
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
                                .padding(14)
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
                            .opacity(keyAppear ? 1 : 0)
                            
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
                                    Text(isValidating ? "Validando..." : "Salvar API Key")
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
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: apiKey.isEmpty ? .clear : provider.brandColor.opacity(0.3), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(apiKey.isEmpty || isValidating)
                            .animation(.easeInOut(duration: 0.2), value: apiKey.isEmpty)
                            .opacity(keyAppear ? 1 : 0)
                        }
                        
                        // Help link
                        Link(destination: URL(string: provider.keyDocURL)!) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                Text("Obter API Key no \(provider.displayName)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(provider.brandColor)
                        }
                        .opacity(keyAppear ? 1 : 0)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
                keyAppear = true
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
                    
                    withAnimation(.spring(response: 0.4)) {
                        isSuccess = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        isPresented = false
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
    ModelSelectionView(
        aiConfig: AIConfiguration(),
        isPresented: .constant(true)
    )
}
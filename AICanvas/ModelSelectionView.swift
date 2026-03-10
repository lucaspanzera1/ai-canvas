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
            AppTheme.background
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
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accent)
                    .frame(width: 44, height: 44)
                
                Image(systemName: aiConfig.selectedModel.provider.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("MODELO ATIVO")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.action)
                
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
                    .fill(AppTheme.action.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.action)
            }
        }
        .padding(16)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.action, lineWidth: 1)
        )
    }
    
    // MARK: - Provider Section
    
    private var groupedModels: [AIProvider: [AIModel]] {
        Dictionary(grouping: aiConfig.availableModels) { $0.provider }
    }
    
    private func providerSection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: provider.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(provider.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                Text("\(groupedModels[provider]?.count ?? 0) modelos")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textMuted)
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
                        .stroke(isSelected ? AppTheme.accent : AppTheme.border, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 10, height: 10)
                    }
                }
                
                Text(model.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                
                Spacer()
                
                if isSelected {
                    Text("SELECIONADO")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.action)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.action.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.action.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isSelected
                ? AppTheme.accent.opacity(0.1)
                : AppTheme.surfaceElevated
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected
                        ? AppTheme.borderActive
                        : AppTheme.border,
                        lineWidth: 1
                    )
            )
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
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
                        .fill(AppTheme.surfaceElevated)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                    
                    Image(systemName: provider.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("Desbloquear")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
                    
                    Text("Configurar \(provider.displayName)")
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
                    VStack(spacing: 32) {
                        Spacer(minLength: 30)
                        
                        // Icon
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: provider.icon)
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(AppTheme.surface)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Desbloquear \(provider.displayName)")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text("Digite sua API Key para acessar\nos modelos do \(provider.displayName).")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Input
                        VStack(alignment: .leading, spacing: 10) {
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
                                Text(isValidating ? "Validando..." : "Salvar")
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
                        
                        Link(destination: URL(string: provider.keyDocURL)!) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 11))
                                Text("Obter API Key")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(AppTheme.link)
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
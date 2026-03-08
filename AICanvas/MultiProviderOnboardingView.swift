import SwiftUI

/// Multi-provider onboarding screen for configuring AI services.
struct MultiProviderOnboardingView: View {
    @Binding var isPresented: Bool
    @ObservedObject var aiConfig: AIConfiguration
    @State private var selectedTab = 0
    @State private var hasConfiguredAny = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Provider Setup
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
                .tabViewStyle(.page(indexDisplayMode: .always))
                
                // Navigation
                navigationView
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            
            VStack(spacing: 8) {
                Text("AI Canvas")
                    .font(.largeTitle.bold())
                
                Text("Configure pelo menos um provedor de IA\npara começar a usar o assistente.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
    
    // MARK: - Navigation
    
    private var navigationView: some View {
        VStack(spacing: 16) {
            // Provider indicators
            HStack(spacing: 8) {
                ForEach(Array(AIProvider.allCases.enumerated()), id: \.element.id) { index, provider in
                    Circle()
                        .fill(KeychainManager.shared.hasAPIKey(for: provider) ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            HStack(spacing: 16) {
                if selectedTab > 0 {
                    Button("Anterior") {
                        withAnimation {
                            selectedTab -= 1
                        }
                    }
                }
                
                Spacer()
                
                if selectedTab < AIProvider.allCases.count - 1 {
                    Button("Próximo") {
                        withAnimation {
                            selectedTab += 1
                        }
                    }
                } else if hasConfiguredAny || KeychainManager.shared.hasAnyAPIKey {
                    Button("Continuar") {
                        aiConfig.updateAvailableModels()
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
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
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Provider Icon
            Image(systemName: provider.icon)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            
            // Title
            VStack(spacing: 8) {
                Text(provider.displayName)
                    .font(.title.bold())
                
                Text("Configure sua API Key do \(provider.displayName) para acessar seus modelos.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Status or Input
            if isConfigured || KeychainManager.shared.hasAPIKey(for: provider) {
                configuredView
            } else {
                inputView
            }
            
            // Documentation Link
            Link("Como obter API Key →", destination: URL(string: provider.keyDocURL)!)
                .font(.footnote)
                .foregroundStyle(.tint)
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .onAppear {
            isConfigured = KeychainManager.shared.hasAPIKey(for: provider)
        }
    }
    
    // MARK: - Views
    
    private var configuredView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("API Key configurada!")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            Button(role: .destructive) {
                KeychainManager.shared.deleteKey(for: provider)
                isConfigured = false
                apiKey = ""
                errorMessage = nil
            } label: {
                Text("Reconfigurar")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 16) {
            // Input Field
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
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
            
            // Save Button
            Button {
                saveKey()
            } label: {
                HStack {
                    if isValidating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Configurar \(provider.displayName)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(apiKey.isEmpty ? Color.gray : Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(apiKey.isEmpty || isValidating)
            
            // Skip
            Button("Pular por agora") {
                // Just move to next provider
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
                    
                    // Update available models
                    aiConfig.updateAvailableModels()
                    
                    // If this is the first configured provider, select its first model
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
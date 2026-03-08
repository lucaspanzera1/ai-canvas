import SwiftUI

/// Model selection view for switching between different AI providers and models.
struct ModelSelectionView: View {
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isPresented: Bool
    @State private var showProviderSetup = false
    @State private var selectedProvider: AIProvider?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current Model
                currentModelSection
                
                Divider()
                
                // Available Models
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if aiConfig.availableModels.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedModels.keys.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { provider in
                                providerSection(for: provider)
                            }
                        }
                        
                        // Add Provider Button
                        addProviderSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Modelos de IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        isPresented = false
                    }
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
    
    // MARK: - Current Model
    
    private var currentModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modelo Atual")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Image(systemName: aiConfig.selectedModel.provider.icon)
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(aiConfig.selectedModel.name)
                        .font(.headline)
                    Text(aiConfig.selectedModel.provider.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(16)
    }
    
    // MARK: - Provider Sections
    
    private var groupedModels: [AIProvider: [AIModel]] {
        Dictionary(grouping: aiConfig.availableModels) { $0.provider }
    }
    
    private func providerSection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: provider.icon)
                    .foregroundStyle(.tint)
                Text(provider.displayName)
                    .font(.subheadline.bold())
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(groupedModels[provider] ?? []) { model in
                    modelRow(for: model)
                }
            }
        }
    }
    
    private func modelRow(for model: AIModel) -> some View {
        Button {
            aiConfig.setSelectedModel(model)
            isPresented = false
        } label: {
            HStack {
                Text(model.name)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if model.id == aiConfig.selectedModel.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                model.id == aiConfig.selectedModel.id 
                ? Color.accentColor.opacity(0.1) 
                : Color(.tertiarySystemBackground)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            
            Text("Nenhum modelo configurado")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Configure uma API Key para começar a usar os modelos de IA.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Add Provider
    
    private var addProviderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adicionar Provedor")
                .font(.subheadline.bold())
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(AIProvider.allCases) { provider in
                    if !KeychainManager.shared.hasAPIKey(for: provider) {
                        providerCard(for: provider)
                    }
                }
            }
        }
        .padding(.top, 20)
    }
    
    private func providerCard(for provider: AIProvider) -> some View {
        Button {
            selectedProvider = provider
            showProviderSetup = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: provider.icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                
                Text(provider.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            }
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
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Provider Icon
                Image(systemName: provider.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                
                // Title
                VStack(spacing: 8) {
                    Text("Configurar \(provider.displayName)")
                        .font(.largeTitle.bold())
                    
                    Text("Digite sua API Key para usar os modelos do \(provider.displayName).")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Input
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
                        Text("Salvar")
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
                Link("Obter API Key →", destination: URL(string: provider.keyDocURL)!)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                Spacer()
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        isPresented = false
                    }
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
                    
                    // If this was the first provider, select its first model
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
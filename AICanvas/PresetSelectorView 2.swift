import SwiftUI

/// Preset selection view — lets the user choose an AI preset and optionally edit a custom system prompt.
struct PresetSelectorView: View {
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isPresented: Bool
    
    @State private var selectedPresetId: String
    @State private var showCustomPromptEditor = false
    @State private var tempCustomPrompt: String
    
    private let presets = AIPresetManager.shared.getAllPresets()
    
    init(aiConfig: AIConfiguration, isPresented: Binding<Bool>) {
        self._aiConfig = ObservedObject(wrappedValue: aiConfig)
        self._isPresented = isPresented
        self._selectedPresetId = State(initialValue: aiConfig.selectedPreset.id)
        self._tempCustomPrompt = State(initialValue: aiConfig.customSystemPrompt)
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Current preset banner
                        currentPresetBanner
                        
                        // Preset list
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PRESETS DISPONÍVEIS")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.textMuted)
                                .padding(.horizontal, 4)
                            
                            ForEach(presets) { preset in
                                presetRow(preset)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Custom system prompt editor toggle
                        customPromptSection
                    }
                    .padding(.vertical, 16)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Presets de IA")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Escolha um estilo de assistente")
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
    
    // MARK: - Current Preset Banner
    
    private var currentPresetBanner: some View {
        let current = aiConfig.selectedPreset
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color(fromHex: current.color).opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(current.emoji)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("PRESET ATIVO")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(color(fromHex: current.color))
                Text(current.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(current.description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(color(fromHex: current.color).opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color(fromHex: current.color))
            }
        }
        .padding(16)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
    }
    
    // MARK: - Preset Row
    
    private func presetRow(_ preset: AIPreset) -> some View {
        let isSelected = preset.id == selectedPresetId
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPresetId = preset.id
                aiConfig.setSelectedPreset(preset)
                
                // If user had a custom prompt, keep it; otherwise, no-op.
                // Optionally suggest recommended provider/model (non-blocking).
                if let recommendedModelId = preset.recommendedModel {
                    // If the recommended provider is configured, try to switch model to a matching one
                    let targetProvider = preset.recommendedProvider
                    if KeychainManager.shared.hasAPIKey(for: targetProvider) {
                        if let match = aiConfig.availableModels.first(where: { $0.provider == targetProvider && $0.id == recommendedModelId }) {
                            aiConfig.setSelectedModel(match)
                        } else if let fallback = aiConfig.availableModels.first(where: { $0.provider == targetProvider }) {
                            aiConfig.setSelectedModel(fallback)
                        }
                    }
                }
            }
            // Close after slight delay to show selection feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isPresented = false
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color(fromHex: preset.color).opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(preset.emoji)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                    Text(preset.description)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Text("EM USO")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(color(fromHex: preset.color))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color(fromHex: preset.color).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(isSelected ? color(fromHex: preset.color).opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color(fromHex: preset.color).opacity(0.4) : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    // MARK: - Custom Prompt
    
    private var customPromptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12, weight: .medium))
                Text("Prompt do Sistema Personalizado")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Toggle(isOn: $showCustomPromptEditor) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, 4)
            
            if showCustomPromptEditor {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Se definido, substitui o prompt do preset atual.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    TextEditor(text: $tempCustomPrompt)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(minHeight: 140)
                        .padding(10)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                    
                    HStack(spacing: 10) {
                        Button(role: .destructive) {
                            tempCustomPrompt = ""
                            aiConfig.setCustomSystemPrompt("")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("Limpar")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.danger)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button {
                            aiConfig.setCustomSystemPrompt(tempCustomPrompt.trimmingCharacters(in: .whitespacesAndNewlines))
                            isPresented = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Aplicar")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showCustomPromptEditor)
    }
    
    // MARK: - Helpers
    
    private func color(fromHex hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        
        let r, g, b: Double
        switch hexSanitized.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0.5; g = 0.5; b = 0.5
        }
        return Color(red: r, green: g, blue: b)
    }
}

#Preview {
    PresetSelectorView(
        aiConfig: AIConfiguration(),
        isPresented: .constant(true)
    )
}

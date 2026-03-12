import SwiftUI

/// Preset selector sheet view
struct PresetSelectorView: View {
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isPresented: Bool
    @State private var showCustomPromptEditor = false
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                presetHeader
                
                // Presets List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(AIPresetManager.shared.getAllPresets()) { preset in
                            PresetCard(
                                preset: preset,
                                isSelected: preset.id == aiConfig.selectedPreset.id,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3)) {
                                        aiConfig.setSelectedPreset(preset)
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
                
                Divider()
                
                // Custom Prompt Editor Button
                VStack(spacing: 12) {
                    Button {
                        showCustomPromptEditor = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 14, weight: .medium))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sistema de Prompt Personalizado")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Crie seu próprio system prompt")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isPresented = false
                        }
                    } label: {
                        Text("Pronto")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.surface)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.action)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showCustomPromptEditor) {
            CustomPromptEditorView(
                aiConfig: aiConfig,
                isPresented: $showCustomPromptEditor
            )
        }
    }
    
    private var presetHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image("AppImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Presets de IA")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Escolha um estilo para o seu assistente")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        isPresented = false
                    }
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
    }
}

/// Individual preset card
struct PresetCard: View {
    let preset: AIPreset
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(preset.emoji)
                        .font(.system(size: 28))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(preset.description)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(Color(hex: preset.color))
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.surface)
                        }
                    } else {
                        Circle()
                            .stroke(AppTheme.border, lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                }
                
                // Features pills
                HStack(spacing: 6) {
                    ForEach(preset.features, id: \.self) { feature in
                        Text(feature)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(hex: preset.color))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: preset.color).opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
            .padding(14)
            .background(isSelected ? Color(hex: preset.color).opacity(0.08) : AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: preset.color).opacity(0.4) : AppTheme.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

/// Custom system prompt editor
struct CustomPromptEditorView: View {
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isPresented: Bool
    @State private var editingPrompt: String = ""
    @State private var hasChanges: Bool = false
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Prompt Personalizado")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Customize o comportamento do assistente")
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
                
                // Editor
                VStack(spacing: 12) {
                    Text("Cole sua descrição personalizada para o assistente:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextEditor(text: $editingPrompt)
                        .scrollContentBackground(.hidden)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                        .onChange(of: editingPrompt) { _ in
                            hasChanges = editingPrompt != aiConfig.customSystemPrompt
                        }
                    
                    HStack(spacing: 12) {
                        if editingPrompt != aiConfig.customSystemPrompt {
                            Button {
                                editingPrompt = aiConfig.customSystemPrompt
                                hasChanges = false
                            } label: {
                                Text("Desfazer")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(AppTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button {
                            aiConfig.setCustomSystemPrompt(editingPrompt)
                            hasChanges = false
                            isPresented = false
                        } label: {
                            Text("Salvar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.surface)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(AppTheme.action)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .opacity(hasChanges ? 1 : 0.5)
                        .disabled(!hasChanges)
                    }
                }
                .padding(16)
                
                Spacer()
            }
        }
        .onAppear {
            editingPrompt = aiConfig.customSystemPrompt.isEmpty ? "" : aiConfig.customSystemPrompt
        }
    }
}

// MARK: - Color Extension Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    PresetSelectorView(
        aiConfig: AIConfiguration(),
        isPresented: .constant(true)
    )
}

import SwiftUI

/// Side panel with AI chat agent.
struct AIChatPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var aiConfig: AIConfiguration
    @ObservedObject private var localization = LocalizationManager.shared
    @Binding var isVisible: Bool
    @FocusState private var isInputFocused: Bool
    @State private var showModelSelection = false
    @State private var showPresetSelection = false
    @State private var attachCanvas = false // toggle: send with canvas snapshot

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            chatMessages

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            chatInput
        }
        .frame(width: 360)
        .background(AppTheme.surface)
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1),
            alignment: .leading
        )
        .sheet(isPresented: $showModelSelection) {
            ModelSelectionView(
                aiConfig: aiConfig,
                isPresented: $showModelSelection
            )
        }
        .sheet(isPresented: $showPresetSelection) {
            PresetSelectorView(
                aiConfig: aiConfig,
                isPresented: $showPresetSelection
            )
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel("AI Assistant", color: AppTheme.textPrimary)

                    // Current model — tap to switch
                    Button {
                        showModelSelection = true
                    } label: {
                        HStack(spacing: 6) {
                            ProviderLogoView(provider: aiConfig.selectedModel.provider, size: 14, cornerRadius: 0)
                            Text(aiConfig.selectedModel.name)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                HStack(spacing: -1) {
                    Menu {
                        Button {
                            showPresetSelection = true
                        } label: {
                            Label("Escolher preset", systemImage: "sparkles")
                        }

                        Button {
                            showModelSelection = true
                        } label: {
                            Label("Trocar modelo", systemImage: "brain.head.profile")
                        }

                        Divider()

                        Button(role: .destructive) {
                            viewModel.clearChat()
                        } label: {
                            Label("Limpar conversa", systemImage: "trash")
                        }

                        Button {
                            KeychainManager.shared.deleteAllKeys()
                            NotificationCenter.default.post(name: .apiKeyDidChange, object: nil)
                        } label: {
                            Label("Reconfigurar APIs", systemImage: "key")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surface)
                            .hairline()
                    }

                    SquareIconButton(icon: "xmark") {
                        withAnimation(AppTheme.motion) { isVisible = false }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    // MARK: - Messages

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(AppTheme.motion) {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    } else if viewModel.isLoading {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pronto para criar!")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Peça ideias, analise seu canvas\nou resolva cálculos desenhados.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(3)
            }

            // One-tap canvas analysis
            Button {
                viewModel.analyzeCanvas()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                    Text("Analisar meu canvas agora")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(MonoButtonStyle(kind: .primary, fullWidth: true))

            // Quick prompts
            let quickPrompts = QuickPromptManager.shared.getPromptsForPreset(aiConfig.selectedPreset)

            if !quickPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Sugestões")
                    VStack(spacing: -1) {
                        ForEach(quickPrompts.prefix(3)) { prompt in
                            QuickPromptChip(
                                text: prompt.text,
                                viewModel: viewModel,
                                withCanvas: prompt.withCanvas
                            )
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 32)
        .padding(.horizontal, 20)
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("ERR")
                .font(AppTheme.label())
                .tracking(1.2)
                .foregroundStyle(AppTheme.onAccent)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(AppTheme.accent)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(12)
        .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .top)
    }

    // MARK: - Input

    private var chatInput: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            // Canvas attachment toggle bar
            HStack(spacing: 6) {
                let hasSelection = viewModel.canvasManager?.selectionRect != nil
                Button {
                    viewModel.analyzeCanvas()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: hasSelection ? "viewfinder" : "eye")
                            .font(.system(size: 10))
                        Text(hasSelection ? "Analisar Seleção" : "Analisar Canvas")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .hairline()
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)

                Button {
                    attachCanvas.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: attachCanvas ? (hasSelection ? "viewfinder" : "photo.fill") : "photo")
                            .font(.system(size: 10))
                        Text(attachCanvas ? (hasSelection ? "Seleção anexada" : "Canvas anexado") : "Anexar imagem")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(attachCanvas ? AppTheme.onAccent : AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(attachCanvas ? AppTheme.accent : Color.clear)
                    .hairline(attachCanvas ? AppTheme.accent : AppTheme.border)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            HStack(alignment: .bottom, spacing: 0) {
                TextField("Mensagem...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .onSubmit {
                        if attachCanvas {
                            viewModel.sendMessageWithCanvas()
                        } else {
                            viewModel.sendMessage()
                        }
                    }

                let isEmpty = viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                let canSend = !isEmpty && !viewModel.isLoading
                Button {
                    if attachCanvas {
                        viewModel.sendMessageWithCanvas()
                        attachCanvas = false
                    } else {
                        viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: attachCanvas ? "camera" : "arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(canSend ? AppTheme.onAccent : AppTheme.textMuted)
                        .frame(width: 40, height: 40)
                        .background(canSend ? AppTheme.accent : Color.clear)
                        .overlay(Rectangle().fill(AppTheme.border).frame(width: 1), alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(AppTheme.motion, value: canSend)
            }
            .hairline(isInputFocused ? AppTheme.borderActive : AppTheme.border)
            .animation(AppTheme.motion, value: isInputFocused)
            .padding(12)
        }
    }
}

// MARK: - Quick Prompt Chip

struct QuickPromptChip: View {
    let text: String
    @ObservedObject var viewModel: ChatViewModel
    var withCanvas: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button {
            if withCanvas {
                viewModel.sendMessageWithCanvas(customPrompt: text)
            } else {
                viewModel.inputText = text
                viewModel.sendMessage()
            }
        } label: {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? AppTheme.onAccent : AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: withCanvas ? "camera" : "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(isHovered ? AppTheme.onAccent : AppTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovered ? AppTheme.accent : AppTheme.surface)
            .hairline()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(AppTheme.motion) { isHovered = hover }
        }
    }
}

// MARK: - Message Bubble

/// Transcript-style message: mono role label above the text. User turns carry a
/// solid left rule; assistant turns are plain text on the panel.
struct MessageBubble: View {
    let message: ChatMessage
    @State private var appeared = false

    private var isUser: Bool {
        message.role == .user
    }

    /// Markdown is parsed per paragraph: full-syntax parsing drops the blank
    /// lines between blocks, which would run paragraphs together in a `Text`.
    private var paragraphs: [AttributedString] {
        message.content
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { block in
                var options = AttributedString.MarkdownParsingOptions()
                options.interpretedSyntax = .inlineOnlyPreservingWhitespace
                options.failurePolicy = .returnPartiallyParsedIfPossible
                return (try? AttributedString(markdown: block, options: options)) ?? AttributedString(block)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(isUser ? "Você" : "IA", color: isUser ? AppTheme.textSecondary : AppTheme.textPrimary)

            // Canvas thumbnail (if attached)
            if isUser, let img = message.attachedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 200, maxHeight: 120)
                    .clipped()
                    .hairline()
                    .overlay(
                        Text("CANVAS")
                            .font(AppTheme.label(9))
                            .tracking(1)
                            .foregroundStyle(AppTheme.onAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent),
                        alignment: .bottomLeading
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
            .foregroundStyle(isUser ? AppTheme.textSecondary : AppTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 14)
        .overlay(
            Rectangle().fill(isUser ? AppTheme.accent : .clear).frame(width: 2),
            alignment: .leading
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(AppTheme.motion) { appeared = true }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("IA", color: AppTheme.textPrimary)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(AppTheme.accent)
                        .frame(width: 6, height: 6)
                        .opacity(animate ? 1 : 0.15)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animate
                        )
                }
            }
            .padding(.vertical, 4)
            .onAppear { animate = true }
        }
        .padding(.leading, 14)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let apiKeyDidChange = Notification.Name("apiKeyDidChange")
}

#Preview {
    AIChatPanelView(
        viewModel: ChatViewModel(aiConfig: AIConfiguration()),
        aiConfig: AIConfiguration(),
        isVisible: .constant(true)
    )
    .background(AppTheme.background)
}

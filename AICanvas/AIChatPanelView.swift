import SwiftUI

/// Side panel with AI chat agent — Game Edition.
struct AIChatPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isVisible: Bool
    @FocusState private var isInputFocused: Bool
    @State private var showModelSelection = false
    @State private var pulseGlow = false
    @State private var attachCanvas = false // toggle: send with canvas snapshot

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            
            chatMessages
            
            currentModelIndicator
            
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
    }

    // MARK: - Header

    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.surface)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.action)
                            .frame(width: 6, height: 6)
                        Text("Online")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Menu {
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                    }

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isVisible = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            // Divider
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
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding(16)
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.spring(response: 0.3)) {
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
        VStack(spacing: 20) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceElevated)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(spacing: 6) {
                Text("Pronto para criar!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Peça ideias, analise seu canvas\nou resolva cálculos desenhados.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // One-tap canvas analysis
            Button {
                viewModel.analyzeCanvas()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13))
                    Text("Analisar meu canvas agora")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(AppTheme.action)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Quick prompts
            VStack(spacing: 8) {
                QuickPromptChip(text: "💡 Me dê ideias de desenho", viewModel: viewModel, withCanvas: false)
                QuickPromptChip(text: "🧮 Resolva os cálculos do canvas", viewModel: viewModel, withCanvas: true)
                QuickPromptChip(text: "✨ Sugira melhorias para este canvas", viewModel: viewModel, withCanvas: true)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 20)
    }

    // MARK: - Current Model

    private var currentModelIndicator: some View {
        Button {
            showModelSelection = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.background)
                        .frame(width: 26, height: 26)
                    Image(systemName: aiConfig.selectedModel.provider.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(aiConfig.selectedModel.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(aiConfig.selectedModel.provider.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Trocar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.borderHover, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.danger)
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.danger)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.danger.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(AppTheme.danger)
                .frame(width: 3),
            alignment: .leading
        )
    }

    // MARK: - Input

    private var chatInput: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            // Canvas attachment toggle bar
            HStack(spacing: 8) {
                Button {
                    viewModel.analyzeCanvas()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Analisar Canvas")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.action)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.action.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.action.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)

                Button {
                    attachCanvas.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: attachCanvas ? "photo.fill" : "photo")
                            .font(.system(size: 11, weight: .semibold))
                        Text(attachCanvas ? "Canvas anexado" : "Anexar canvas")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(attachCanvas ? .white : AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(attachCanvas ? AppTheme.accent : AppTheme.surfaceElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(attachCanvas ? Color.clear : AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Mensagem...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .onSubmit {
                        if attachCanvas {
                            viewModel.sendMessageWithCanvas()
                        } else {
                            viewModel.sendMessage()
                        }
                    }

                Button {
                    if attachCanvas {
                        viewModel.sendMessageWithCanvas()
                        attachCanvas = false
                    } else {
                        viewModel.sendMessage()
                    }
                } label: {
                    ZStack {
                        let isEmpty = viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                        if isEmpty || viewModel.isLoading {
                            Circle()
                                .fill(AppTheme.surfaceElevated)
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                            Image(systemName: attachCanvas ? "camera.fill" : "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)
                        } else {
                            Circle()
                                .fill(attachCanvas ? AppTheme.action : AppTheme.accent)
                                .frame(width: 32, height: 32)
                            Image(systemName: attachCanvas ? "camera.fill" : "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.surface)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                .animation(.spring(response: 0.3), value: viewModel.inputText.isEmpty)
                .animation(.spring(response: 0.3), value: attachCanvas)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isInputFocused ? AppTheme.borderActive : AppTheme.borderHover, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isInputFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
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
            HStack(spacing: 6) {
                if withCanvas {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.action.opacity(0.7))
                }
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHovered ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isHovered
                ? AppTheme.border
                : AppTheme.surfaceElevated
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(withCanvas ? AppTheme.action.opacity(0.3) : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hover }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @State private var appeared = false

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 48)
            } else {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 24, height: 24)
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.surface)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Canvas thumbnail (if attached)
                if isUser, let img = message.attachedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 200, maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                        .overlay(
                            HStack(spacing: 3) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 9))
                                Text("canvas")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.45))
                            .clipShape(Capsule())
                            .padding(6),
                            alignment: .bottomLeading
                        )
                }

                Text(message.content)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .foregroundStyle(isUser ? AppTheme.surface : AppTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isUser {
                                AnyView(AppTheme.accent)
                            } else {
                                AnyView(AppTheme.surfaceElevated)
                            }
                        }
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isUser
                                ? Color.clear
                                : AppTheme.border,
                                lineWidth: 1
                            )
                    )
            }
            .scaleEffect(appeared ? 1 : 0.85, anchor: isUser ? .bottomTrailing : .bottomLeading)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    appeared = true
                }
            }

            if !isUser {
                Spacer(minLength: 48)
            } else {
                // User avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceElevated)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(AppTheme.borderActive, lineWidth: 1))
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 24, height: 24)
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.surface)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppTheme.textMuted)
                        .frame(width: 5, height: animate ? 8 : 5)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
            .onAppear { animate = true }
            
            Spacer(minLength: 48)
        }
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

import SwiftUI

/// Side panel with AI chat agent — Game Edition.
struct AIChatPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isVisible: Bool
    @FocusState private var isInputFocused: Bool
    @State private var showModelSelection = false
    @State private var pulseGlow = false

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
        .background(GameTheme.surface)
        .overlay(
            Rectangle()
                .fill(GameTheme.border)
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
                        .fill(GameTheme.primaryGradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: GameTheme.neonPurple.opacity(pulseGlow ? 0.8 : 0.3), radius: pulseGlow ? 12 : 6)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulseGlow = true
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GameTheme.textPrimary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(GameTheme.neonGreen)
                            .frame(width: 6, height: 6)
                            .shadow(color: GameTheme.neonGreen, radius: 3)
                        Text("Online")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(GameTheme.neonGreen)
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
                            .foregroundStyle(GameTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(GameTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(GameTheme.border, lineWidth: 1))
                    }

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isVisible = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(GameTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(GameTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(GameTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            // Neon divider
            LinearGradient(
                colors: [GameTheme.neonPurple.opacity(0.0), GameTheme.neonPurple.opacity(0.6), GameTheme.neonCyan.opacity(0.6), GameTheme.neonCyan.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
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
                    .fill(GameTheme.neonPurple.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(GameTheme.neonPurple.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(GameTheme.primaryGradient)
            }

            VStack(spacing: 6) {
                Text("Pronto para criar!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(GameTheme.textPrimary)

                Text("Peça ideias, análise seus desenhos\nou desafie a IA com qualquer pergunta.")
                    .font(.system(size: 13))
                    .foregroundStyle(GameTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Quick prompts
            VStack(spacing: 8) {
                QuickPromptChip(text: "💡 Me dê ideias de desenho", viewModel: viewModel)
                QuickPromptChip(text: "🎨 Analise meu canvas", viewModel: viewModel)
                QuickPromptChip(text: "✨ Sugira melhorias", viewModel: viewModel)
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
                        .fill(GameTheme.neonPurple.opacity(0.2))
                        .frame(width: 26, height: 26)
                    Image(systemName: aiConfig.selectedModel.provider.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GameTheme.neonPurple)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(aiConfig.selectedModel.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GameTheme.textPrimary)
                    Text(aiConfig.selectedModel.provider.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(GameTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Trocar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GameTheme.neonCyan)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(GameTheme.neonCyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(GameTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(GameTheme.border, lineWidth: 1)
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
                .foregroundStyle(GameTheme.neonOrange)
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(GameTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(GameTheme.neonOrange.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(GameTheme.neonOrange)
                .frame(width: 3),
            alignment: .leading
        )
    }

    // MARK: - Input

    private var chatInput: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [GameTheme.neonPurple.opacity(0.0), GameTheme.neonPurple.opacity(0.3), GameTheme.neonCyan.opacity(0.3), GameTheme.neonCyan.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Mensagem...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .font(.system(size: 14))
                    .foregroundStyle(GameTheme.textPrimary)
                    .onSubmit {
                        viewModel.sendMessage()
                    }

                Button {
                    viewModel.sendMessage()
                } label: {
                    ZStack {
                        if viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading {
                            Circle()
                                .fill(GameTheme.surfaceElevated)
                                .frame(width: 36, height: 36)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(GameTheme.textMuted)
                        } else {
                            Circle()
                                .fill(GameTheme.primaryGradient)
                                .frame(width: 36, height: 36)
                                .shadow(color: GameTheme.neonPurple.opacity(0.6), radius: 8)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                .animation(.spring(response: 0.3), value: viewModel.inputText.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(GameTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isInputFocused ? GameTheme.neonPurple.opacity(0.6) : GameTheme.border, lineWidth: 1)
            )
            .shadow(color: isInputFocused ? GameTheme.neonPurple.opacity(0.2) : .clear, radius: 10)
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
    @State private var isHovered = false

    var body: some View {
        Button {
            viewModel.inputText = text
            viewModel.sendMessage()
        } label: {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? GameTheme.neonCyan : GameTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isHovered
                    ? GameTheme.neonCyan.opacity(0.1)
                    : GameTheme.surfaceElevated
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isHovered ? GameTheme.neonCyan.opacity(0.5) : GameTheme.border, lineWidth: 1)
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
                        .fill(GameTheme.primaryGradient)
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .foregroundStyle(isUser ? .white : GameTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isUser {
                                AnyView(GameTheme.primaryGradient)
                            } else {
                                AnyView(GameTheme.surfaceElevated)
                            }
                        }
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isUser
                                ? Color.clear
                                : GameTheme.border,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isUser ? GameTheme.neonPurple.opacity(0.4) : .clear,
                        radius: 8,
                        x: 0,
                        y: 4
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
                        .fill(GameTheme.neonCyan.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(GameTheme.neonCyan.opacity(0.4), lineWidth: 1))
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(GameTheme.neonCyan)
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
                    .fill(GameTheme.primaryGradient)
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            index == 0 ? GameTheme.neonPurple :
                            index == 1 ? GameTheme.neonCyan :
                            GameTheme.neonGreen
                        )
                        .frame(width: 6, height: animate ? 14 : 6)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animate
                        )
                        .shadow(
                            color: (index == 0 ? GameTheme.neonPurple :
                                   index == 1 ? GameTheme.neonCyan :
                                   GameTheme.neonGreen).opacity(0.8),
                            radius: 4
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(GameTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.border, lineWidth: 1))
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
    .background(GameTheme.background)
}

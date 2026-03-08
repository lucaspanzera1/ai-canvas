import SwiftUI

/// Side panel with AI chat agent powered by multiple providers.
struct AIChatPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isVisible: Bool
    @FocusState private var isInputFocused: Bool
    @State private var showModelSelection = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider()

            // Messages
            chatMessages
            
            // Current Model Indicator
            currentModelIndicator

            // Error banner
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            Divider()

            // Input
            chatInput
        }
        .frame(width: 340)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showModelSelection) {
            ModelSelectionView(
                aiConfig: aiConfig,
                isPresented: $showModelSelection
            )
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)

            Text("AI Assistant")
                .font(.headline)

            Spacer()

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
                    // Force re-onboarding by posting notification
                    NotificationCenter.default.post(
                        name: .apiKeyDidChange,
                        object: nil
                    )
                } label: {
                    Label("Reconfigurar APIs", systemImage: "key")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Messages

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
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
                withAnimation {
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
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)

            Text("Converse com a IA")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Peça ideias, feedback ou ajuda\ncom seus desenhos.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Current Model

    private var currentModelIndicator: some View {
        Button {
            showModelSelection = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: aiConfig.selectedModel.provider.icon)
                    .foregroundStyle(.tint)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(aiConfig.selectedModel.name)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Text(aiConfig.selectedModel.provider.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Input

    private var chatInput: some View {
        HStack(spacing: 10) {
            TextField("Mensagem...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.gray : Color.accentColor
                    )
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .padding(10)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(isUser ? .white : .primary)
                    .cornerRadius(16)
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .offset(y: animate ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: animate
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .onAppear { animate = true }
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
}

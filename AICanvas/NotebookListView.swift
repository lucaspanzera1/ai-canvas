import SwiftUI

// MARK: - Notebook List View

struct NotebookListView: View {
    @ObservedObject var store: NotebookStore
    @Binding var selectedNotebook: Notebook?
    @State private var showCreateSheet = false
    @State private var notebookToDelete: Notebook?
    @State private var showDeleteConfirm = false
    @State private var appeared = false

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)
    ]

    var body: some View {
        ZStack {
            // Background
            GameTheme.background.ignoresSafeArea()

            // Background glows
            ZStack {
                Circle()
                    .fill(GameTheme.neonPurple.opacity(0.12))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(x: -150, y: -300)

                Circle()
                    .fill(GameTheme.neonCyan.opacity(0.08))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: 200, y: 400)
            }

            VStack(spacing: 0) {
                listHeader
                    .padding(.bottom, 8)

                if store.notebooks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(store.notebooks) { notebook in
                                NotebookCard(notebook: notebook)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                            selectedNotebook = notebook
                                        }
                                    }
                                    .onLongPressGesture {
                                        notebookToDelete = notebook
                                        showDeleteConfirm = true
                                    }
                                    .scaleEffect(appeared ? 1 : 0.85)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.45, dampingFraction: 0.8)
                                            .delay(Double(store.notebooks.firstIndex(of: notebook) ?? 0) * 0.06),
                                        value: appeared
                                    )
                            }

                            // New Notebook Card
                            NewNotebookCard {
                                showCreateSheet = true
                            }
                            .scaleEffect(appeared ? 1 : 0.85)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.8)
                                    .delay(Double(store.notebooks.count) * 0.06),
                                value: appeared
                            )
                        }
                        .padding(20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
        .onDisappear { appeared = false }
        .sheet(isPresented: $showCreateSheet) {
            CreateNotebookSheet(store: store, isPresented: $showCreateSheet)
        }
        .confirmationDialog(
            "Apagar \"\(notebookToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                if let nb = notebookToDelete {
                    withAnimation(.spring(response: 0.35)) {
                        store.deleteNotebook(nb)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O desenho será perdido permanentemente.")
        }
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(GameTheme.neonPurple)
                    Text("MEUS CADERNOS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(GameTheme.neonPurple)
                        .tracking(2)
                }

                Text("AI Canvas")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameTheme.primaryGradient)
            }

            Spacer()

            // Stats badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(store.notebooks.count)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameTheme.textPrimary)
                Text(store.notebooks.count == 1 ? "caderno" : "cadernos")
                    .font(.system(size: 11))
                    .foregroundStyle(GameTheme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(GameTheme.neonPurple.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .overlay(Circle().stroke(GameTheme.neonPurple.opacity(0.3), lineWidth: 1))

                Text("📓")
                    .font(.system(size: 52))
            }

            VStack(spacing: 8) {
                Text("Nenhum caderno ainda")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(GameTheme.textPrimary)
                Text("Crie seu primeiro caderno\ne comece a desenhar!")
                    .font(.system(size: 14))
                    .foregroundStyle(GameTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Criar Caderno")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(GameTheme.primaryGradient)
                .clipShape(Capsule())
                .shadow(color: GameTheme.neonPurple.opacity(0.6), radius: 14)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Notebook Card

struct NotebookCard: View {
    let notebook: Notebook
    @State private var hovered = false

    private var accentColor: Color {
        notebookSwiftColor(at: notebook.colorIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top — emoji + color block
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.25), accentColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 110)

                // Decorative lines (ruled notebook feel)
                VStack(spacing: 14) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle()
                            .fill(accentColor.opacity(0.12))
                            .frame(height: 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                // Emoji
                Text(notebook.emoji)
                    .font(.system(size: 40))
                    .padding(14)
                    .shadow(color: accentColor.opacity(0.5), radius: 8)
            }

            // Bottom info
            VStack(alignment: .leading, spacing: 6) {
                Text(notebook.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(GameTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(GameTheme.textMuted)
                    Text(notebook.lastModified.relativeString)
                        .font(.system(size: 11))
                        .foregroundStyle(GameTheme.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GameTheme.surfaceElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    hovered ? accentColor.opacity(0.6) : GameTheme.border,
                    lineWidth: hovered ? 1.5 : 1
                )
        )
        .shadow(
            color: hovered ? accentColor.opacity(0.3) : .black.opacity(0.3),
            radius: hovered ? 16 : 8,
            x: 0,
            y: hovered ? 8 : 4
        )
        .scaleEffect(hovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
        .onHover { h in hovered = h }
    }
}

// MARK: - New Notebook Card

struct NewNotebookCard: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(GameTheme.neonPurple.opacity(hovered ? 0.2 : 0.1))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(GameTheme.neonPurple.opacity(hovered ? 0.7 : 0.3), lineWidth: 1.5)
                        )
                        .shadow(color: GameTheme.neonPurple.opacity(hovered ? 0.6 : 0.0), radius: 12)

                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(GameTheme.neonPurple)
                }

                Text("Novo Caderno")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(hovered ? GameTheme.neonPurple : GameTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(hovered ? GameTheme.neonPurple.opacity(0.06) : GameTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                hovered
                                ? GameTheme.neonPurple.opacity(0.5)
                                : Color(white: 1, opacity: 0.06),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(hovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.25), value: hovered)
        .onHover { h in hovered = h }
    }
}

// MARK: - Create Notebook Sheet

struct CreateNotebookSheet: View {
    @ObservedObject var store: NotebookStore
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var selectedEmoji = "📓"
    @State private var selectedColorIndex = 0
    @FocusState private var nameFocused: Bool

    private let emojis = ["📓", "✏️", "🎨", "💡", "🔥", "⚡️", "🌙", "🎯", "🗺️", "🔮", "🧠", "🎮", "🚀", "🌊", "🦋"]

    var body: some View {
        ZStack {
            GameTheme.background.ignoresSafeArea()

            Circle()
                .fill(GameTheme.neonPurple.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 100, y: -200)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") { isPresented = false }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(GameTheme.textSecondary)
                        .buttonStyle(.plain)

                    Spacer()

                    Text("Novo Caderno")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(GameTheme.textPrimary)

                    Spacer()

                    Button("Criar") {
                        createAndOpen()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(name.isEmpty ? GameTheme.textMuted : GameTheme.neonCyan)
                    .disabled(name.isEmpty)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                LinearGradient(
                    colors: [GameTheme.neonPurple.opacity(0), GameTheme.neonPurple.opacity(0.5), GameTheme.neonCyan.opacity(0.5), GameTheme.neonCyan.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 1)

                ScrollView {
                    VStack(spacing: 28) {
                        // Preview Card
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [notebookSwiftColor(at: selectedColorIndex).opacity(0.3), notebookSwiftColor(at: selectedColorIndex).opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(notebookSwiftColor(at: selectedColorIndex).opacity(0.5), lineWidth: 1.5)
                                )
                                .shadow(color: notebookSwiftColor(at: selectedColorIndex).opacity(0.3), radius: 16)

                            HStack(spacing: 14) {
                                Text(selectedEmoji)
                                    .font(.system(size: 42))
                                    .shadow(color: notebookSwiftColor(at: selectedColorIndex).opacity(0.6), radius: 10)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name.isEmpty ? "Nome do caderno" : name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(name.isEmpty ? GameTheme.textMuted : GameTheme.textPrimary)
                                    Text("Agora mesmo")
                                        .font(.system(size: 11))
                                        .foregroundStyle(GameTheme.textMuted)
                                }
                            }
                            .padding(16)
                        }
                        .padding(.top, 24)

                        // Name input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOME")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(GameTheme.textMuted)
                                .tracking(2)

                            TextField("Ex: Anotações de Matemática", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                                .foregroundStyle(GameTheme.textPrimary)
                                .focused($nameFocused)
                                .padding(14)
                                .background(GameTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(nameFocused ? GameTheme.neonPurple.opacity(0.6) : GameTheme.border, lineWidth: 1)
                                )
                        }

                        // Emoji picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ÍCONE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(GameTheme.textMuted)
                                .tracking(2)

                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 10), count: 5), spacing: 10) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 26))
                                            .frame(width: 48, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedEmoji == emoji
                                                          ? GameTheme.neonPurple.opacity(0.2)
                                                          : GameTheme.surfaceElevated)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(selectedEmoji == emoji
                                                                    ? GameTheme.neonPurple.opacity(0.7)
                                                                    : GameTheme.border, lineWidth: 1)
                                                    )
                                            )
                                            .shadow(color: selectedEmoji == emoji ? GameTheme.neonPurple.opacity(0.4) : .clear, radius: 6)
                                    }
                                    .buttonStyle(.plain)
                                    .scaleEffect(selectedEmoji == emoji ? 1.08 : 1.0)
                                    .animation(.spring(response: 0.2), value: selectedEmoji)
                                }
                            }
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("COR")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(GameTheme.textMuted)
                                .tracking(2)

                            HStack(spacing: 10) {
                                ForEach(0..<notebookNeonColors.count, id: \.self) { idx in
                                    Button {
                                        selectedColorIndex = idx
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(notebookSwiftColor(at: idx))
                                                .frame(width: 32, height: 32)
                                                .shadow(color: notebookSwiftColor(at: idx).opacity(selectedColorIndex == idx ? 0.9 : 0.0), radius: 8)

                                            if selectedColorIndex == idx {
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2.5)
                                                    .frame(width: 32, height: 32)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .scaleEffect(selectedColorIndex == idx ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.2), value: selectedColorIndex)
                                }
                            }
                        }

                        // Create button
                        Button {
                            createAndOpen()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Criar Caderno")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                name.isEmpty
                                ? AnyView(GameTheme.surfaceElevated)
                                : AnyView(GameTheme.primaryGradient)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(name.isEmpty ? GameTheme.border : Color.clear, lineWidth: 1)
                            )
                            .shadow(color: name.isEmpty ? .clear : GameTheme.neonPurple.opacity(0.5), radius: 14)
                        }
                        .buttonStyle(.plain)
                        .disabled(name.isEmpty)
                        .animation(.easeInOut(duration: 0.2), value: name.isEmpty)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .onAppear { nameFocused = true }
    }

    private func createAndOpen() {
        guard !name.isEmpty else { return }
        store.createNotebook(name: name, emoji: selectedEmoji, colorIndex: selectedColorIndex)
        isPresented = false
    }
}

// MARK: - Helpers

func notebookSwiftColor(at index: Int) -> Color {
    let colors: [Color] = [
        Color(red: 0.58, green: 0.22, blue: 1.0),   // Roxo
        Color(red: 0.0,  green: 0.85, blue: 1.0),   // Cyan
        Color(red: 0.18, green: 1.0,  blue: 0.58),  // Verde
        Color(red: 1.0,  green: 0.2,  blue: 0.6),   // Rosa
        Color(red: 1.0,  green: 0.6,  blue: 0.0),   // Laranja
        Color(red: 0.3,  green: 0.6,  blue: 1.0),   // Azul
        Color(red: 1.0,  green: 0.9,  blue: 0.0),   // Amarelo
        Color(red: 1.0,  green: 0.25, blue: 0.25),  // Vermelho
    ]
    return colors[index % colors.count]
}

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    NotebookListView(
        store: NotebookStore(),
        selectedNotebook: .constant(nil)
    )
}

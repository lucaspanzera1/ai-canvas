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
            AppTheme.background.ignoresSafeArea()

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
                    Image(systemName: "book.closed")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("MEUS CADERNOS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .tracking(1)
                }

                Text("AI Canvas")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            // Stats badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(store.notebooks.count)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(store.notebooks.count == 1 ? "caderno" : "cadernos")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
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
                    .fill(AppTheme.surfaceElevated)
                    .frame(width: 90, height: 90)
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))

                Text("📓")
                    .font(.system(size: 40))
            }

            VStack(spacing: 8) {
                Text("Nenhum caderno ainda")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Crie seu primeiro caderno\ne comece a desenhar!")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                    Text("Criar Caderno")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    .fill(accentColor.opacity(0.15))
                    .frame(height: 60)

                // Emoji
                Text(notebook.emoji)
                    .font(.system(size: 28))
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            // Bottom info
            VStack(alignment: .leading, spacing: 4) {
                Text(notebook.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                    Text(notebook.lastModified.relativeString)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surfaceElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    hovered ? AppTheme.borderHover : AppTheme.border,
                    lineWidth: 1
                )
        )
        .shadow(
            color: hovered ? AppTheme.shadowColor : .clear,
            radius: hovered ? 12 : 4,
            x: 0,
            y: hovered ? 4 : 2
        )
        .scaleEffect(hovered ? 1.01 : 1.0)
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
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(hovered ? AppTheme.borderActive : AppTheme.border)
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Text("Novo Caderno")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(hovered ? AppTheme.surfaceElevated : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                hovered ? AppTheme.borderHover : AppTheme.border,
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(hovered ? 1.01 : 1.0)
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
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") { isPresented = false }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .buttonStyle(.plain)

                    Spacer()

                    Text("Novo Caderno")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button("Criar") {
                        createAndOpen()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(name.isEmpty ? AppTheme.textMuted : AppTheme.accent)
                    .disabled(name.isEmpty)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 28) {
                        // Preview Card
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.surfaceElevated)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )

                            HStack(spacing: 14) {
                                Text(selectedEmoji)
                                    .font(.system(size: 32))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name.isEmpty ? "Nome do caderno" : name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(name.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary)
                                    Text("Agora mesmo")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                            }
                            .padding(16)
                        }
                        .padding(.top, 24)

                        // Name input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOME")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)

                            TextField("Ex: Anotações de Matemática", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textPrimary)
                                .focused($nameFocused)
                                .padding(14)
                                .background(AppTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(nameFocused ? AppTheme.accent : AppTheme.border, lineWidth: 1)
                                )
                        }

                        // Emoji picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ÍCONE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)

                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 10), count: 5), spacing: 10) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 24))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedEmoji == emoji
                                                          ? AppTheme.border
                                                          : AppTheme.surfaceElevated)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(selectedEmoji == emoji
                                                                    ? AppTheme.borderHover
                                                                    : AppTheme.border, lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .scaleEffect(selectedEmoji == emoji ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.2), value: selectedEmoji)
                                }
                            }
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TITULO DA COR")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)

                            HStack(spacing: 12) {
                                ForEach(0..<8, id: \.self) { idx in
                                    Button {
                                        selectedColorIndex = idx
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(notebookSwiftColor(at: idx))
                                                .frame(width: 28, height: 28)

                                            if selectedColorIndex == idx {
                                                Circle()
                                                    .stroke(AppTheme.accent, lineWidth: 2)
                                                    .frame(width: 34, height: 34)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.spring(response: 0.2), value: selectedColorIndex)
                                }
                            }
                        }

                        // Create button
                        Button {
                            createAndOpen()
                        } label: {
                            Text("Criar Caderno")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(name.isEmpty ? AppTheme.borderHover : AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
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
        Color(red: 0.44, green: 0.58, blue: 0.88),   // Periwinkle
        Color(red: 0.55, green: 0.85, blue: 0.76),   // Mint
        Color(red: 0.98, green: 0.70, blue: 0.58),   // Peach
        Color(red: 0.88, green: 0.56, blue: 0.56),   // Soft Red
        Color(red: 0.90, green: 0.85, blue: 0.55),   // Pale Yellow
        Color(red: 0.75, green: 0.65, blue: 0.85),   // Lavender
        Color(red: 0.60, green: 0.60, blue: 0.60),   // Gray
        Color(red: 0.20, green: 0.25, blue: 0.35),   // Slate
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

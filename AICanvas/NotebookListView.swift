import SwiftUI

// MARK: - Enums & State

enum ItemActionType {
    case edit
    case delete
}

enum ItemSelection: Identifiable {
    case notebook(Notebook, ItemActionType)
    case folder(Folder, ItemActionType)
    
    var id: String {
        switch self {
        case .notebook(let nb, let type): return "nb_\(nb.id)_\(type)"
        case .folder(let f, let type): return "f_\(f.id)_\(type)"
        }
    }
}

// MARK: - Notebook List View

struct NotebookListView: View {
    @ObservedObject var store: NotebookStore
    @Binding var selectedNotebook: Notebook?
    
    @State private var currentFolder: Folder? = nil
    
    @State private var showCreateNotebook = false
    @State private var showCreateFolder = false
    @State private var activeAction: ItemSelection?
    
    @State private var appeared = false
    @State private var showOnboarding = false
    @StateObject private var aiConfig = AIConfiguration()

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)
    ]
    
    private var visibleFolders: [Folder] {
        if currentFolder == nil {
            return store.folders
        }
        return []
    }
    
    private var visibleNotebooks: [Notebook] {
        store.notebooks.filter { $0.folderId == currentFolder?.id }
    }

    var body: some View {
        ZStack {
            // Background
            AppTheme.background.ignoresSafeArea()
            
            // Decorative background blobs
            Circle()
                .fill(AppTheme.textSecondary.opacity(0.04))
                .blur(radius: 60)
                .frame(width: 400, height: 400)
                .offset(x: -200, y: -200)
            
            Circle()
                .fill(AppTheme.textSecondary.opacity(0.03))
                .blur(radius: 80)
                .frame(width: 500, height: 500)
                .offset(x: 300, y: 100)

            VStack(spacing: 0) {
                listHeader
                    .padding(.bottom, 8)

                if visibleFolders.isEmpty && visibleNotebooks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            // FOLDERS
                            ForEach(visibleFolders) { folder in
                                FolderCard(folder: folder)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                            currentFolder = folder
                                        }
                                    }
                                    .contextMenu {
                                        Button {
                                            activeAction = .folder(folder, .edit)
                                        } label: {
                                            Label("Editar Pasta", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            activeAction = .folder(folder, .delete)
                                        } label: {
                                            Label("Apagar Pasta", systemImage: "trash")
                                        }
                                    }
                                    .scaleEffect(appeared ? 1 : 0.85)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(.spring(response: 0.45).delay(Double(store.folders.firstIndex(of: folder) ?? 0) * 0.05), value: appeared)
                            }
                            
                            // NOTEBOOKS
                            ForEach(visibleNotebooks) { notebook in
                                NotebookCard(notebook: notebook)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                            selectedNotebook = notebook
                                        }
                                    }
                                    .contextMenu {
                                        Button {
                                            activeAction = .notebook(notebook, .edit)
                                        } label: {
                                            Label("Editar Caderno", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            activeAction = .notebook(notebook, .delete)
                                        } label: {
                                            Label("Apagar Caderno", systemImage: "trash")
                                        }
                                    }
                                    .scaleEffect(appeared ? 1 : 0.85)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(.spring(response: 0.45).delay(Double(visibleFolders.count + (store.notebooks.firstIndex(of: notebook) ?? 0)) * 0.05), value: appeared)
                            }

                            // CREATE NEW CARDS
                            if currentFolder == nil {
                                NewItemCard(title: "Nova Pasta", icon: "folder.badge.plus") {
                                    showCreateFolder = true
                                }
                                .scaleEffect(appeared ? 1 : 0.85)
                                .opacity(appeared ? 1 : 0)
                                .animation(.spring(response: 0.45).delay(Double(visibleFolders.count + visibleNotebooks.count) * 0.05), value: appeared)
                            }
                            
                            NewItemCard(title: "Novo Caderno", icon: "plus") {
                                showCreateNotebook = true
                            }
                            .scaleEffect(appeared ? 1 : 0.85)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.45).delay(Double(visibleFolders.count + visibleNotebooks.count + 1) * 0.05), value: appeared)
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
        .sheet(isPresented: $showCreateNotebook) {
            ItemEditorSheet(store: store, mode: .createNotebook(folderId: currentFolder?.id), isPresented: $showCreateNotebook)
        }
        .sheet(isPresented: $showCreateFolder) {
            ItemEditorSheet(store: store, mode: .createFolder, isPresented: $showCreateFolder)
        }
        .sheet(item: Binding(
            get: {
                if case .notebook(let nb, .edit) = activeAction { return ItemSelection.notebook(nb, .edit) }
                if case .folder(let f, .edit) = activeAction { return ItemSelection.folder(f, .edit) }
                return nil
            },
            set: { if $0 == nil { activeAction = nil } }
        )) { _ in
            if case .notebook(let nb, .edit) = activeAction {
                ItemEditorSheet(store: store, mode: .editNotebook(nb), isPresented: Binding(
                    get: { activeAction != nil },
                    set: { if !$0 { activeAction = nil } }
                ))
            } else if case .folder(let f, .edit) = activeAction {
                ItemEditorSheet(store: store, mode: .editFolder(f), isPresented: Binding(
                    get: { activeAction != nil },
                    set: { if !$0 { activeAction = nil } }
                ))
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            MultiProviderOnboardingView(
                isPresented: $showOnboarding,
                aiConfig: aiConfig
            )
        }
        .confirmationDialog(
            "Tem certeza?",
            isPresented: Binding(
                get: {
                    if case .notebook(_, .delete) = activeAction { return true }
                    if case .folder(_, .delete) = activeAction { return true }
                    return false
                },
                set: { if !$0 { activeAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                if case .notebook(let nb, .delete) = activeAction {
                    withAnimation { store.deleteNotebook(nb) }
                } else if case .folder(let f, .delete) = activeAction {
                    withAnimation { store.deleteFolder(f) }
                }
                activeAction = nil
            }
            Button("Cancelar", role: .cancel) { activeAction = nil }
        } message: {
            if case .folder = activeAction {
                Text("A pasta e todos os cadernos nela serão apagados permanentemente.")
            } else {
                Text("Este caderno será apagado permanentemente.")
            }
        }
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let folder = currentFolder {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            currentFolder = nil
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Voltar")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.textSecondary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)

                    Text("\(folder.emoji) \(folder.name)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("ESPAÇO CRIATIVO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.textSecondary.opacity(0.08))
                    .clipShape(Capsule())

                    Text("Meus Cadernos")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }

            Spacer()

            // Header Actions
            VStack(alignment: .trailing, spacing: 12) {
                HStack(spacing: 12) {
                    // Open Source Action
                    Link(destination: URL(string: "https://github.com/lucaspanzera1/ai-canvas")!) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Config IAs
                    Button {
                        showOnboarding = true
                    } label: {
                        Image(systemName: "cpu")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Stats badge
                HStack(spacing: 8) {
                    Image(systemName: currentFolder == nil ? "books.vertical.fill" : "folder.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textSecondary)
                    let count = currentFolder == nil ? store.notebooks.count + store.folders.count : visibleNotebooks.count
                    Text("\(count) \(count == 1 ? "item" : "itens")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.surfaceElevated)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                .shadow(color: AppTheme.shadowColor, radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [.init(color: AppTheme.accent.opacity(0.06), location: 0), .init(color: .clear, location: 1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(AppTheme.surfaceElevated)
                    .frame(width: 90, height: 90)
                    .shadow(color: AppTheme.shadowColor, radius: 10, y: 5)
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))

                Text("✨")
                    .font(.system(size: 44))
                    .offset(x: 2, y: -2)
            }

            VStack(spacing: 8) {
                Text(currentFolder == nil ? "Espaço vazio" : "Pasta vazia")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Crie seu primeiro item e solte a imaginação\ncom a ajuda de IA poderosa.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 12) {
                if currentFolder == nil {
                    Button {
                        showCreateFolder = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                            Text("Nova Pasta")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(AppTheme.surfaceElevated)
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    showCreateNotebook = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Criar Caderno")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
}

// MARK: - Folder Card

struct FolderCard: View {
    let folder: Folder
    @State private var hovered = false

    private var accentColor: Color {
        notebookSwiftColor(at: folder.colorIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    gradient: Gradient(colors: [accentColor.opacity(0.3), accentColor.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 60)

                HStack {
                    Text(folder.emoji)
                        .font(.system(size: 28))
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    Spacer()
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.2))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(folder.lastModified.relativeString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surfaceElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hovered ? accentColor.opacity(0.5) : AppTheme.border, lineWidth: hovered ? 2 : 1)
        )
        .shadow(color: hovered ? accentColor.opacity(0.2) : AppTheme.shadowColor, radius: hovered ? 12 : 6, y: hovered ? 6 : 2)
        .scaleEffect(hovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hovered)
        .onHover { h in hovered = h }
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
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    gradient: Gradient(colors: [accentColor.opacity(0.4), accentColor.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 70)

                Text(notebook.emoji)
                    .font(.system(size: 34))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(notebook.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)
                    Text(notebook.lastModified.relativeString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surfaceElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hovered ? accentColor.opacity(0.5) : AppTheme.border, lineWidth: hovered ? 2 : 1)
        )
        .shadow(color: hovered ? accentColor.opacity(0.2) : AppTheme.shadowColor, radius: hovered ? 12 : 6, y: hovered ? 6 : 2)
        .scaleEffect(hovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hovered)
        .onHover { h in hovered = h }
    }
}

// MARK: - New Item Card

struct NewItemCard: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(hovered ? AppTheme.borderActive : AppTheme.border)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(hovered ? AppTheme.surfaceElevated : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                hovered ? AppTheme.accent.opacity(0.6) : AppTheme.border,
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
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

// MARK: - Editor Sheet (Create/Edit)

enum EditorMode {
    case createNotebook(folderId: UUID?)
    case createFolder
    case editNotebook(Notebook)
    case editFolder(Folder)
    
    var title: String {
        switch self {
        case .createNotebook: return "Novo Caderno"
        case .createFolder: return "Nova Pasta"
        case .editNotebook: return "Editar Caderno"
        case .editFolder: return "Editar Pasta"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .createNotebook, .createFolder: return "Criar"
        case .editNotebook, .editFolder: return "Salvar"
        }
    }
    
    var defaultEmoji: String {
        switch self {
        case .createNotebook, .editNotebook: return "📓"
        case .createFolder, .editFolder: return "📁"
        }
    }
}

struct ItemEditorSheet: View {
    @ObservedObject var store: NotebookStore
    let mode: EditorMode
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var selectedEmoji = ""
    @State private var selectedColorIndex = 0
    @FocusState private var nameFocused: Bool

    private let emojis = ["📓", "📁", "✏️", "🎨", "💡", "🔥", "⚡️", "🌙", "🎯", "🗺️", "🔮", "🧠", "🎮", "🚀", "🌊", "🦋"]

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

                    Text(mode.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button(mode.buttonTitle) {
                        save()
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
                                    Text(name.isEmpty ? "Nome" : name)
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

                            TextField("Ex: Ideias", text: $name)
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
                                                    .fill(selectedEmoji == emoji ? AppTheme.border : AppTheme.surfaceElevated)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(selectedEmoji == emoji ? AppTheme.borderHover : AppTheme.border, lineWidth: 1)
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
                            Text("COR DO TEMA")
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

                        // Submit button
                        Button {
                            save()
                        } label: {
                            Text(mode.buttonTitle)
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
        .onAppear {
            switch mode {
            case .createNotebook, .createFolder:
                selectedEmoji = mode.defaultEmoji
            case .editNotebook(let nb):
                name = nb.name
                selectedEmoji = nb.emoji
                selectedColorIndex = nb.colorIndex
            case .editFolder(let f):
                name = f.name
                selectedEmoji = f.emoji
                selectedColorIndex = f.colorIndex
            }
            nameFocused = true
        }
    }

    private func save() {
        guard !name.isEmpty else { return }
        
        switch mode {
        case .createNotebook(let folderId):
            store.createNotebook(name: name, emoji: selectedEmoji, colorIndex: selectedColorIndex, folderId: folderId)
        case .createFolder:
            store.createFolder(name: name, emoji: selectedEmoji, colorIndex: selectedColorIndex)
        case .editNotebook(let nb):
            store.renameNotebook(nb, to: name, emoji: selectedEmoji, colorIndex: selectedColorIndex)
        case .editFolder(let f):
            store.renameFolder(f, to: name, emoji: selectedEmoji, colorIndex: selectedColorIndex)
        }
        
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

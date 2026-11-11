import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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

enum DraggableItem: Codable, Transferable {
    case notebook(UUID)
    case folder(UUID)
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
    
    var jsonData: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
    
    init?(jsonData: Data) {
        do {
            let decoded = try JSONDecoder().decode(DraggableItem.self, from: jsonData)
            self = decoded
        } catch {
            return nil
        }
    }
}

// MARK: - Notebook List View

struct NotebookListView: View {
    @ObservedObject var store: NotebookStore
    @ObservedObject var syncManager: SyncManager
    @ObservedObject private var localization = LocalizationManager.shared
    @Binding var selectedNotebook: Notebook?
    @Binding var folderPath: [Folder]
    @Binding var showSidebar: Bool

    private var selectedFolder: Folder? { folderPath.last }
    
    @State private var showCreateNotebook = false
    @State private var showCreateFolder = false
    @State private var showPDFImporter = false
    @State private var showGraphView = false
    @State private var activeAction: ItemSelection?
    
    @State private var appeared = false
    @State private var showOnboarding = false
    @StateObject private var aiConfig = AIConfiguration()
    @State private var isHeaderDropTargeted = false

    private var parentFolderId: UUID? {
        folderPath.count > 1 ? folderPath[folderPath.count - 2].id : nil
    }

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)
    ]
    
    private var visibleFolders: [Folder] {
        store.folders.filter { $0.parentFolderId == selectedFolder?.id }
    }
    
    private var visibleNotebooks: [Notebook] {
        store.notebooks.filter { $0.folderId == selectedFolder?.id }
    }
    
    // Extract booleans for dialogs/sheets to simplify type inference
    private var isDeletingSomething: Bool {
        if case .notebook(_, .delete) = activeAction { return true }
        if case .folder(_, .delete) = activeAction { return true }
        return false
    }
    
    private var isEditingNotebook: Bool {
        if case .notebook(_, .edit) = activeAction { return true }
        return false
    }
    
    private var isEditingFolder: Bool {
        if case .folder(_, .edit) = activeAction { return true }
        return false
    }

    var body: some View {
        mainContent
            .onAppear { withAnimation { appeared = true } }
            .onDisappear { appeared = false }
            .sheet(isPresented: $showCreateNotebook) {
                ItemEditorSheet(store: store, mode: .createNotebook(folderId: selectedFolder?.id), isPresented: $showCreateNotebook)
            }
            .sheet(isPresented: $showCreateFolder) {
                ItemEditorSheet(store: store, mode: .createFolder(parentFolderId: selectedFolder?.id), isPresented: $showCreateFolder)
            }
            .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                handlePDFImport(result)
            }
            .sheet(isPresented: Binding(get: { isEditingNotebook }, set: { if !$0 { activeAction = nil } })) {
                if case .notebook(let nb, .edit) = activeAction {
                    ItemEditorSheet(store: store, mode: .editNotebook(nb), isPresented: Binding(
                        get: { activeAction != nil },
                        set: { if !$0 { activeAction = nil } }
                    ))
                }
            }
            .sheet(isPresented: Binding(get: { isEditingFolder }, set: { if !$0 { activeAction = nil } })) {
                if case .folder(let f, .edit) = activeAction {
                    ItemEditorSheet(store: store, mode: .editFolder(f), isPresented: Binding(
                        get: { activeAction != nil },
                        set: { if !$0 { activeAction = nil } }
                    ))
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                MultiProviderOnboardingView(isPresented: $showOnboarding, aiConfig: aiConfig)
            }
            .confirmationDialog(
                "Tem certeza?",
                isPresented: Binding(get: { isDeletingSomething }, set: { if !$0 { activeAction = nil } }),
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

    private var mainContent: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if showGraphView {
                GraphView(
                    store: store,
                    selectedNotebook: $selectedNotebook,
                    folderPath: $folderPath,
                    showGraphView: $showGraphView
                )
            } else if visibleFolders.isEmpty && visibleNotebooks.isEmpty {
                VStack(spacing: 0) {
                    listHeader
                    emptyState
                }
            } else {
                VStack(spacing: 0) {
                    listHeader
                        .background(AppTheme.background)

                    ScrollView {
                        gridContent
                            .padding(.horizontal, 32)
                            .padding(.top, 28)
                            .padding(.bottom, 60)
                    }
                    .onDrop(of: [.data], delegate: RootDropDelegate(store: store))
                }
            }
        }
    }

    private var gridContent: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(visibleFolders) { folder in
                let folderIndex = visibleFolders.firstIndex(of: folder) ?? 0
                let folderDelay = Double(folderIndex) * 0.03

                FolderCard(folder: folder)
                    .onDrag {
                        let provider = NSItemProvider()
                        let data = DraggableItem.folder(folder.id).jsonData
                        provider.registerDataRepresentation(forTypeIdentifier: UTType.data.identifier, visibility: .all) { completion in
                            completion(data, nil)
                            return nil
                        }
                        return provider
                    }
                    .onDrop(of: [.data], delegate: FolderDropDelegate(folder: folder, store: store))
                    .contextMenu {
                        Button { activeAction = .folder(folder, .edit) } label: {
                            Label("Editar Pasta", systemImage: "pencil")
                        }
                        if let sel = selectedFolder {
                            Divider()
                            if folderPath.count > 1 {
                                let parent = folderPath[folderPath.count - 2]
                                Button { store.moveFolder(folder, to: parent.id) } label: {
                                    Label("Mover para \(parent.name)", systemImage: "folder")
                                }
                            }
                            Button { store.moveFolder(folder, to: nil) } label: {
                                Label("Mover para Início", systemImage: "house")
                            }
                            let _ = sel // suppress unused warning
                        }
                        Divider()
                        Button(role: .destructive) { activeAction = .folder(folder, .delete) } label: {
                            Label("Apagar Pasta", systemImage: "trash")
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(AppTheme.motion.delay(folderDelay), value: appeared)
                    .highPriorityGesture(TapGesture().onEnded {
                        withAnimation(AppTheme.motion) {
                            folderPath.append(folder)
                        }
                    })
            }

            ForEach(visibleNotebooks) { notebook in
                let nbIndex = visibleNotebooks.firstIndex(of: notebook) ?? 0
                let combinedIndex = visibleFolders.count + nbIndex
                let nbDelay = Double(combinedIndex) * 0.03

                NotebookCard(notebook: notebook, syncManager: syncManager)
                    .onTapGesture {
                        withAnimation(AppTheme.motion) {
                            selectedNotebook = notebook
                        }
                    }
                    .onDrag {
                        let provider = NSItemProvider()
                        let data = DraggableItem.notebook(notebook.id).jsonData
                        provider.registerDataRepresentation(forTypeIdentifier: UTType.data.identifier, visibility: .all) { completion in
                            completion(data, nil)
                            return nil
                        }
                        return provider
                    }
                    .contextMenu {
                        Button { activeAction = .notebook(notebook, .edit) } label: {
                            Label("Editar Caderno", systemImage: "pencil")
                        }
                        if let sel = selectedFolder {
                            Divider()
                            if folderPath.count > 1 {
                                let parent = folderPath[folderPath.count - 2]
                                Button { store.moveNotebook(notebook, to: parent.id) } label: {
                                    Label("Mover para \(parent.name)", systemImage: "folder")
                                }
                            }
                            Button { store.moveNotebook(notebook, to: nil) } label: {
                                Label("Mover para Início", systemImage: "house")
                            }
                            let _ = sel // suppress unused warning
                        }
                        Divider()
                        Button(role: .destructive) { activeAction = .notebook(notebook, .delete) } label: {
                            Label("Apagar Caderno", systemImage: "trash")
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(AppTheme.motion.delay(nbDelay), value: appeared)
            }

            newItemCards
        }
    }

    @ViewBuilder
    private var newItemCards: some View {
        let baseDelay = Double(visibleFolders.count + visibleNotebooks.count) * 0.03

        NewItemCard(title: "Nova Pasta", icon: "folder.badge.plus") { showCreateFolder = true }
            .opacity(appeared ? 1 : 0)
            .animation(AppTheme.motion.delay(baseDelay), value: appeared)

        NewItemCard(title: "Novo Caderno", icon: "plus") { showCreateNotebook = true }
            .opacity(appeared ? 1 : 0)
            .animation(AppTheme.motion.delay(baseDelay + 0.03), value: appeared)

        NewItemCard(title: "Importar PDF", icon: "doc.badge.plus") { showPDFImporter = true }
            .opacity(appeared ? 1 : 0)
            .animation(AppTheme.motion.delay(baseDelay + 0.06), value: appeared)
    }

    // MARK: - Header

    private var itemCount: Int {
        selectedFolder == nil
            ? store.notebooks.count + store.folders.filter { $0.parentFolderId == nil }.count
            : visibleNotebooks.count + visibleFolders.count
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar: navigation on the left, utilities on the right
            HStack(spacing: 8) {
                if !showSidebar {
                    SquareIconButton(icon: "sidebar.left") {
                        withAnimation(AppTheme.motion) { showSidebar = true }
                    }
                }

                if selectedFolder != nil {
                    Button(action: {
                        withAnimation(AppTheme.motion) {
                            _ = folderPath.removeLast()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isHeaderDropTargeted ? "tray.and.arrow.down" : "arrow.left")
                                .font(.system(size: 12))
                            Text(folderPath.count > 1 ? folderPath[folderPath.count - 2].name : "Início".localized)
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(isHeaderDropTargeted ? AppTheme.onAccent : AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(isHeaderDropTargeted ? AppTheme.accent : Color.clear)
                        .hairline(isHeaderDropTargeted ? AppTheme.accent : AppTheme.border)
                        .animation(AppTheme.motion, value: isHeaderDropTargeted)
                    }
                    .buttonStyle(.plain)
                    .onDrop(of: [.data], delegate: ParentDropDelegate(
                        targetFolderId: parentFolderId,
                        store: store,
                        isTargeted: $isHeaderDropTargeted
                    ))
                }

                Spacer()

                HStack(spacing: -1) {
                    Link(destination: URL(string: "https://github.com/lucaspanzera1/ai-canvas")!) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surface)
                            .hairline()
                    }
                    .buttonStyle(.plain)

                    SquareIconButton(icon: "point.3.connected.trianglepath.dotted", isActive: showGraphView) {
                        withAnimation(AppTheme.motion) { showGraphView.toggle() }
                    }

                    SquareIconButton(icon: "cpu") {
                        showOnboarding = true
                    }
                }
            }
            .padding(.top, 24)

            // Title block
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(selectedFolder == nil ? "ESPAÇO CRIATIVO" : "Pasta")

                    HStack(spacing: 12) {
                        if let folder = selectedFolder {
                            NoteIcon(icon: folder.emoji, size: 28)
                        }
                        Text(selectedFolder?.name ?? "Meus Cadernos".localized)
                            .font(.system(size: 40, weight: .semibold))
                            .tracking(-1.2)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(String(format: "%02d", itemCount) + " " + (itemCount == 1 ? "item" : "itens").localized.uppercased())
                    .font(AppTheme.label(11))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.top, 36)
            .padding(.bottom, 20)

            Rectangle()
                .fill(AppTheme.textPrimary)
                .frame(height: 1)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("00 itens")
                Text(selectedFolder == nil ? "Espaço vazio" : "Pasta vazia")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Crie seu primeiro item e solte a imaginação\ncom a ajuda de IA poderosa.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(4)
            }

            HStack(spacing: 8) {
                Button {
                    showCreateNotebook = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Criar Caderno")
                    }
                }
                .buttonStyle(MonoButtonStyle(kind: .primary))

                Button {
                    showCreateFolder = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                        Text("Nova Pasta")
                    }
                }
                .buttonStyle(MonoButtonStyle())

                Button {
                    showPDFImporter = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                        Text("Importar PDF")
                    }
                }
                .buttonStyle(MonoButtonStyle())
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  let notebook = store.createNotebookFromPDF(sourceURL: url, folderId: selectedFolder?.id) else { return }
            withAnimation(AppTheme.motion) {
                selectedNotebook = notebook
            }
        case .failure(let error):
            print("PDF import canceled/failed: \(error)")
        }
    }
}

// MARK: - Card Chrome

/// Shared square card: monochrome banner on top, hairline rule, text block below.
/// Hover sharpens the border to full contrast instead of lifting or scaling.
private struct ItemCardChrome<Footer: View>: View {
    let icon: String
    let title: String
    let bannerImageData: Data?
    let kind: String
    @ViewBuilder let footer: () -> Footer
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                // Overlay keeps a fill-scaled image from widening the card
                AppTheme.surfaceElevated
                    .frame(height: 76)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if let imageData = bannerImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .grayscale(1)
                                .contrast(1.1)
                        }
                    }
                    .clipped()

                NoteIcon(icon: icon, size: 20)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surface)
                    .hairline()
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                Text(kind)
                    .font(AppTheme.label(9))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.surface)
                    .hairline()
                    .padding(12)
            }

            Rectangle().fill(AppTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                footer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
        }
        .background(AppTheme.surface)
        .hairline(hovered ? AppTheme.accent : AppTheme.border)
        .contentShape(Rectangle())
        .animation(AppTheme.motion, value: hovered)
        .onHover { hovered = $0 }
    }
}

// MARK: - Folder Card

struct FolderCard: View {
    let folder: Folder

    var body: some View {
        ItemCardChrome(icon: folder.emoji, title: folder.name, bannerImageData: folder.bannerImageData, kind: "DIR") {
            Text(folder.lastModified.relativeString.uppercased())
                .font(AppTheme.label())
                .tracking(0.8)
                .foregroundStyle(AppTheme.textMuted)
        }
    }
}

// MARK: - Notebook Card

struct NotebookCard: View {
    let notebook: Notebook
    @ObservedObject var syncManager: SyncManager

    private var isSyncing: Bool { syncManager.syncingNotebooks.contains(notebook.id) }
    private var hasChanges: Bool { syncManager.notebookHasChanges(notebook) }

    var body: some View {
        ItemCardChrome(
            icon: notebook.emoji,
            title: notebook.name,
            bannerImageData: notebook.bannerImageData,
            kind: notebook.type == .pdf ? "PDF" : "NB"
        ) {
            HStack(spacing: 6) {
                Text(notebook.lastModified.relativeString.uppercased())
                    .font(AppTheme.label())
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textMuted)

                Spacer()

                if SyncSettings.load().isConfigured && (hasChanges || isSyncing) {
                    Button {
                        guard !isSyncing else { return }
                        Task { await syncManager.syncNotebook(notebook) }
                    } label: {
                        Group {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.5)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                        .frame(width: 22, height: 22)
                        .hairline()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .animation(AppTheme.motion, value: hasChanges)
        }
    }
}

// MARK: - New Item Card

struct NewItemCard: View {
    let title: String
    let icon: String
    let action: () -> Void
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(hovered ? AppTheme.onAccent : AppTheme.textPrimary)

                Spacer()

                HStack {
                    Text(title.localized)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                }
                .foregroundStyle(hovered ? AppTheme.onAccent : AppTheme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(hovered ? AppTheme.accent : Color.clear)
            .overlay(
                Rectangle()
                    .strokeBorder(
                        hovered ? AppTheme.accent : AppTheme.borderHover,
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(AppTheme.motion, value: hovered)
        .onHover { h in hovered = h }
    }
}

// MARK: - Editor Sheet (Create/Edit)

enum EditorMode {
    case createNotebook(folderId: UUID?)
    case createFolder(parentFolderId: UUID?)
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
    @State private var bannerImageData: Data? = nil
    @State private var selectedBannerItem: PhotosPickerItem? = nil
    @State private var showEmojiPicker = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") { isPresented = false }
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .buttonStyle(.plain)

                    Spacer()

                    Text(mode.title.localized.uppercased())
                        .font(AppTheme.label(11))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button(mode.buttonTitle) {
                        save()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(name.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary)
                    .disabled(name.isEmpty)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Preview
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .bottomLeading) {
                                AppTheme.surfaceElevated
                                    .frame(height: 88)
                                    .frame(maxWidth: .infinity)
                                    .overlay {
                                        if let data = bannerImageData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .grayscale(1)
                                        }
                                    }
                                    .clipped()

                                NoteIcon(icon: selectedEmoji, size: 22)
                                    .frame(width: 40, height: 40)
                                    .background(AppTheme.surface)
                                    .hairline()
                                    .padding(12)
                            }

                            Rectangle().fill(AppTheme.border).frame(height: 1)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(name.isEmpty ? "Nome" : name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(name.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary)
                                Text("Agora mesmo".localized.uppercased())
                                    .font(AppTheme.label())
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                            .padding(14)
                        }
                        .hairline()
                        .padding(.top, 28)

                        // Name input
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel("Nome")

                            TextField("Ex: Ideias", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.textPrimary)
                                .focused($nameFocused)
                                .padding(.vertical, 12)
                                .overlay(
                                    Rectangle()
                                        .fill(nameFocused ? AppTheme.accent : AppTheme.border)
                                        .frame(height: nameFocused ? 2 : 1),
                                    alignment: .bottom
                                )
                        }

                        // Icon picker
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel("ÍCONE")

                            Button { showEmojiPicker = true } label: {
                                HStack(spacing: 14) {
                                    NoteIcon(icon: selectedEmoji, size: 24)
                                        .frame(width: 48, height: 48)
                                        .hairline()

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Toque para escolher")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("Biblioteca de emojis por categoria")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(12)
                                .hairline()
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .sheet(isPresented: $showEmojiPicker) {
                                EmojiPickerView(selectedEmoji: $selectedEmoji, isPresented: $showEmojiPicker)
                            }
                        }

                        // Banner Image Picker
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                SectionLabel("BANNER PERSONALIZADO (IMAGEM)")
                                Spacer()
                                if bannerImageData != nil {
                                    Button {
                                        bannerImageData = nil
                                        selectedBannerItem = nil
                                    } label: {
                                        Text("Remover".localized.uppercased())
                                            .font(AppTheme.label())
                                            .tracking(1.2)
                                            .underline()
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            PhotosPicker(selection: $selectedBannerItem, matching: .images) {
                                if let data = bannerImageData, let uiImage = UIImage(data: data) {
                                    AppTheme.surfaceElevated
                                        .frame(height: 80)
                                        .frame(maxWidth: .infinity)
                                        .overlay {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .grayscale(1)
                                        }
                                        .clipped()
                                        .hairline()
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                        Text("Selecionar Imagem")
                                    }
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .overlay(Rectangle().strokeBorder(AppTheme.borderHover, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                                }
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedBannerItem) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        await MainActor.run {
                                            withAnimation(AppTheme.motion) { bannerImageData = data }
                                        }
                                    }
                                }
                            }
                        }

                        // Submit button
                        Button {
                            save()
                        } label: {
                            Text(mode.buttonTitle)
                        }
                        .buttonStyle(MonoButtonStyle(kind: .primary, fullWidth: true))
                        .disabled(name.isEmpty)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 28)
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
                bannerImageData = nb.bannerImageData
            case .editFolder(let f):
                name = f.name
                selectedEmoji = f.emoji
                selectedColorIndex = f.colorIndex
                bannerImageData = f.bannerImageData
            }
            nameFocused = true
        }
    }

    private func save() {
        guard !name.isEmpty else { return }
        
        switch mode {
        case .createNotebook(let folderId):
            store.createNotebook(name: name, emoji: selectedEmoji, colorIndex: selectedColorIndex, folderId: folderId, bannerImageData: bannerImageData)
        case .createFolder(let parentFolderId):
            store.createFolder(name: name, emoji: selectedEmoji, colorIndex: selectedColorIndex, parentFolderId: parentFolderId, bannerImageData: bannerImageData)
        case .editNotebook(let nb):
            store.renameNotebook(nb, to: name, emoji: selectedEmoji, colorIndex: selectedColorIndex, bannerImageData: bannerImageData)
        case .editFolder(let f):
            store.renameFolder(f, to: name, emoji: selectedEmoji, colorIndex: selectedColorIndex, bannerImageData: bannerImageData)
        }
        
        isPresented = false
    }
}

// MARK: - Helpers

func notebookSwiftColor(at index: Int) -> Color {
    // Monochrome ramp — kept so stored colorIndex values still map to a stable tone.
    let colors: [Color] = [
        Color(light: 0x0A0A0A, dark: 0xFAFAFA),
        Color(light: 0x262626, dark: 0xE5E5E5),
        Color(light: 0x404040, dark: 0xD4D4D4),
        Color(light: 0x525252, dark: 0xA3A3A3),
        Color(light: 0x737373, dark: 0x8A8A8A),
        Color(light: 0x8A8A8A, dark: 0x737373),
        Color(light: 0xA3A3A3, dark: 0x525252),
        Color(light: 0xD4D4D4, dark: 0x404040),
    ]
    return colors[index % colors.count]
}

// MARK: - Note Icon

struct NoteIcon: View {
    let icon: String
    var size: CGFloat = 28

    var isSFSymbol: Bool { icon.hasPrefix("sf:") }
    var symbolName: String { String(icon.dropFirst(3)) }

    var body: some View {
        if isSFSymbol {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.7, weight: .regular))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: size, height: size)
        } else {
            Text(icon)
                .font(.system(size: size * 0.85))
                .grayscale(1)
        }
    }
}

// MARK: - Drop Delegates

struct FolderDropDelegate: DropDelegate {
    let folder: Folder
    let store: NotebookStore
    
    func performDrop(info: DropInfo) -> Bool {
        for itemProvider in info.itemProviders(for: [.data]) {
            itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.data.identifier) { data, error in
                guard let data = data, let draggableItem = DraggableItem(jsonData: data) else { return }
                DispatchQueue.main.async {
                    switch draggableItem {
                    case .notebook(let id):
                        if let notebook = store.notebooks.first(where: { $0.id == id }) {
                            store.moveNotebook(notebook, to: folder.id)
                        }
                    case .folder(let id):
                        if let movingFolder = store.folders.first(where: { $0.id == id }), movingFolder.id != folder.id {
                            store.moveFolder(movingFolder, to: folder.id)
                        }
                    }
                }
            }
        }
        return true
    }
}

struct RootDropDelegate: DropDelegate {
    let store: NotebookStore

    func performDrop(info: DropInfo) -> Bool {
        for itemProvider in info.itemProviders(for: [.data]) {
            itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.data.identifier) { data, error in
                guard let data = data, let draggableItem = DraggableItem(jsonData: data) else { return }
                DispatchQueue.main.async {
                    switch draggableItem {
                    case .notebook(let id):
                        if let notebook = store.notebooks.first(where: { $0.id == id }) {
                            store.moveNotebook(notebook, to: nil)
                        }
                    case .folder(let id):
                        if let folder = store.folders.first(where: { $0.id == id }) {
                            store.moveFolder(folder, to: nil)
                        }
                    }
                }
            }
        }
        return true
    }
}

struct ParentDropDelegate: DropDelegate {
    let targetFolderId: UUID?
    let store: NotebookStore
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        withAnimation(AppTheme.motion) { isTargeted = true }
    }

    func dropExited(info: DropInfo) {
        withAnimation(AppTheme.motion) { isTargeted = false }
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        for itemProvider in info.itemProviders(for: [.data]) {
            itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.data.identifier) { data, error in
                guard let data = data, let draggableItem = DraggableItem(jsonData: data) else { return }
                DispatchQueue.main.async {
                    switch draggableItem {
                    case .notebook(let id):
                        if let notebook = store.notebooks.first(where: { $0.id == id }) {
                            store.moveNotebook(notebook, to: targetFolderId)
                        }
                    case .folder(let id):
                        if let folder = store.folders.first(where: { $0.id == id }), folder.id != targetFolderId {
                            store.moveFolder(folder, to: targetFolderId)
                        }
                    }
                }
            }
        }
        return true
    }
}

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = LocalizationManager.shared.locale
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Emoji Picker Data

private let emojiPickerCategories: [(name: String, icon: String, emojis: [String])] = [
    ("Estudo", "📚", ["📓","📔","📒","📕","📗","📘","📙","📚","📖","📝","✏️","🖊️","🖋️","📐","📏","🔬","🔭","🧪","🧫","🧬","🎓","🏫","📎","🖇️","📌","📍","🗒️","🗓️"]),
    ("Trabalho", "💼", ["💼","🏢","📱","💻","⌨️","🖥️","🖨️","📞","📟","📠","📊","📈","📉","📋","🗂️","🗃️","🗄️","📁","📂","📅","📆","⚙️","🔧","🛠️","🔒","🔑"]),
    ("Criativo", "🎨", ["🎨","🖌️","🎭","🎬","🎤","🎵","🎶","🎸","🎹","🎺","🎻","🥁","🎯","🎮","🕹️","🎲","✨","💫","⭐","🌟","🏆","🥇","🎪","🎠","🎡","🎢","🎑","🎆"]),
    ("Natureza", "🌿", ["🌱","🌲","🌳","🌴","🌵","🌷","🌸","🌺","🌻","🌹","🍀","☘️","🍃","🌿","🌾","🌊","🔥","⚡","❄️","🌈","🌙","☀️","⛅","🌤️","🌍","🌎","🌏","🦋"]),
    ("Pessoas", "😊", ["😊","🤔","😎","🥳","🤩","💪","🙌","👏","🤝","👋","❤️","💙","💚","💛","💜","🧠","👁️","🐱","🐶","🦊","🐼","🦁","🐯","🦄","🐸","🐧","🦉","🦅"]),
    ("Comida", "🍕", ["🍕","🍔","🍟","🌮","🌯","🍜","🍝","🍣","🍱","🍩","🍪","🎂","🍰","☕","🍵","🧃","🥤","🧁","🍫","🍓","🍎","🍋","🍇","🥑","🍉","🍑","🥐","🧇"]),
    ("Viagem", "✈️", ["✈️","🚀","🛸","🚗","🚂","🚢","🏠","🏡","🏛️","⛺","🗺️","🧭","🏔️","🏝️","🎡","🗼","🗽","🏰","🌄","🌃","🌆","🛕","⛩️","🕌","🕍","🏟️","🚁","🛩️"]),
    ("Objetos", "🔮", ["🔮","💡","🔑","🗝️","🔒","💎","🏺","🎁","🎀","🎊","🎉","🎈","🔧","🔨","🛠️","📡","💰","💳","🧲","🪄","🎩","🧸","🪞","🛋️","🖼️","🪴","🕯️","💿"]),
]

// MARK: - SF Symbols Data

private let sfSymbolCategories: [(name: String, icon: String, symbols: [String])] = [
    ("Estudo", "book.fill", [
        "book.fill","book.closed.fill","books.vertical.fill","text.book.closed.fill",
        "doc.fill","doc.text.fill","pencil","pencil.and.outline","highlighter",
        "graduationcap.fill","backpack.fill","ruler.fill","paperclip","pin.fill",
        "bookmark.fill","note.text","list.bullet","list.clipboard.fill",
        "magnifyingglass","brain.head.profile","lightbulb.fill","flask.fill"
    ]),
    ("Trabalho", "briefcase.fill", [
        "briefcase.fill","folder.fill","folder.badge.plus","tray.fill","tray.2.fill",
        "archivebox.fill","doc.richtext.fill","calendar","calendar.badge.plus",
        "clock.fill","alarm.fill","chart.bar.fill","chart.line.uptrend.xyaxis",
        "chart.pie.fill","envelope.fill","phone.fill","bubble.left.fill",
        "flag.fill","checkmark.circle.fill","person.2.fill","building.2.fill","network"
    ]),
    ("Criativo", "paintbrush.fill", [
        "paintbrush.fill","paintpalette.fill","camera.fill","photo.fill","film.fill",
        "music.note","music.quarternote.3","microphone.fill","theatermasks.fill",
        "pencil.and.scribble","wand.and.stars","sparkles","star.fill","star.circle.fill",
        "heart.fill","bolt.fill","flame.fill","crown.fill","trophy.fill","medal.fill",
        "photo.artframe","cube.fill","square.3.layers.3d"
    ]),
    ("Tecnologia", "laptopcomputer", [
        "laptopcomputer","iphone","desktopcomputer","keyboard","display","printer.fill",
        "wifi","cpu.fill","memorychip.fill","externaldrive.fill","server.rack",
        "terminal.fill","chevron.left.forwardslash.chevron.right","curlybraces",
        "lock.fill","key.fill","shield.fill","gear","gearshape.fill",
        "antenna.radiowaves.left.and.right","sensor.tag.radiowaves.forward.fill","qrcode"
    ]),
    ("Pessoas", "person.fill", [
        "person.fill","person.2.fill","person.3.fill","figure.walk","figure.run",
        "heart.fill","hand.raised.fill","hands.clap.fill","brain.head.profile",
        "eye.fill","face.smiling.fill","figure.mind.and.body","figure.yoga",
        "figure.strengthtraining.traditional","medal.fill","trophy.fill","crown.fill",
        "gift.fill","balloon.fill","party.popper","handbag.fill","figure.child"
    ]),
    ("Natureza", "leaf.fill", [
        "leaf.fill","tree.fill","cloud.fill","sun.max.fill","moon.fill",
        "bolt.fill","flame.fill","drop.fill","snowflake","wind","rainbow",
        "mountain.2.fill","tent.fill","globe.europe.africa.fill","water.waves",
        "tornado","bird.fill","fish.fill","hare.fill","tortoise.fill",
        "ant.fill","pawprint.fill","sun.and.horizon.fill"
    ]),
    ("Objetos", "giftcard.fill", [
        "giftcard.fill","gift.fill","bag.fill","cart.fill","creditcard.fill",
        "key.fill","lock.fill","tag.fill","flashlight.on.fill","lightbulb.fill",
        "battery.100.bolt","cross.case.fill","stethoscope","pills.fill",
        "dumbbell.fill","soccerball","basketball.fill","gamecontroller.fill",
        "map.fill","mappin.and.ellipse","binoculars.fill","camera.filters"
    ]),
    ("Símbolos", "star.fill", [
        "star.fill","heart.fill","bolt.fill","flame.fill","drop.fill",
        "checkmark.circle.fill","xmark.circle.fill","exclamationmark.circle.fill",
        "questionmark.circle.fill","info.circle.fill","plus.circle.fill",
        "minus.circle.fill","arrow.up.circle.fill","arrow.down.circle.fill",
        "arrow.right.circle.fill","arrow.left.circle.fill","infinity.circle.fill",
        "sparkles","wand.and.stars","tornado","hurricane","aqi.medium"
    ]),
]

// MARK: - Emoji Picker View

private enum IconPickerMode: String, CaseIterable {
    case emoji = "Emojis"
    case sfSymbol = "SF Symbols"
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var selectedCategoryIndex = 0
    @State private var mode: IconPickerMode = .emoji

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 6)]

    private var currentCategories: [(name: String, icon: String, items: [String])] {
        switch mode {
        case .emoji:
            return emojiPickerCategories.map { ($0.name, $0.icon, $0.emojis) }
        case .sfSymbol:
            return sfSymbolCategories.map { ($0.name, $0.icon, $0.symbols) }
        }
    }

    private var displayedItems: [String] {
        let all = currentCategories
        if searchText.isEmpty {
            let idx = min(selectedCategoryIndex, all.count - 1)
            return all[idx].items
        }
        let lower = searchText.lowercased()
        return all.flatMap { $0.items }.filter { $0.lowercased().contains(lower) }
    }

    private var selectedIsCurrentMode: Bool {
        switch mode {
        case .emoji: return !selectedEmoji.hasPrefix("sf:")
        case .sfSymbol: return selectedEmoji.hasPrefix("sf:")
        }
    }

    var body: some View {
        ZStack {
            AppTheme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") { isPresented = false }
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .buttonStyle(.plain)

                    Spacer()

                    Text("Escolher Ícone".localized.uppercased())
                        .font(AppTheme.label(11))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Text("Cancelar")
                        .font(.system(size: 13))
                        .foregroundStyle(.clear)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)

                // Mode toggle — two joined square segments
                HStack(spacing: -1) {
                    ForEach(IconPickerMode.allCases, id: \.self) { m in
                        Button { mode = m } label: {
                            Text(m.rawValue.uppercased())
                                .font(AppTheme.label(11))
                                .tracking(1.2)
                                .foregroundStyle(mode == m ? AppTheme.onAccent : AppTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(mode == m ? AppTheme.accent : AppTheme.surface)
                                .hairline(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .onChange(of: mode) { _ in
                    selectedCategoryIndex = 0
                    searchText = ""
                }

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textMuted)
                        .font(.system(size: 14))
                    TextField(mode == .emoji ? "Buscar emoji…" : "Buscar símbolo…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Category tabs (hidden during search)
                if searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(currentCategories.indices, id: \.self) { idx in
                                Button {
                                    withAnimation(AppTheme.motion) {
                                        selectedCategoryIndex = idx
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if mode == .sfSymbol {
                                            Image(systemName: currentCategories[idx].icon)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(selectedCategoryIndex == idx ? AppTheme.textPrimary : AppTheme.textSecondary)
                                        } else {
                                            Text(currentCategories[idx].icon)
                                                .font(.system(size: 15))
                                        }
                                        Text(currentCategories[idx].name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(selectedCategoryIndex == idx ? AppTheme.textPrimary : AppTheme.textSecondary)
                                    }
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .fill(selectedCategoryIndex == idx ? AppTheme.accent : .clear)
                                            .frame(height: 2),
                                        alignment: .bottom
                                    )
                                }
                                .buttonStyle(.plain)
                                .animation(AppTheme.motion, value: selectedCategoryIndex)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                    }
                } else {
                    Spacer().frame(height: 12)
                }

                // Grid
                ScrollView {
                    if displayedItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.textMuted)
                            Text("Nenhum resultado")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(displayedItems, id: \.self) { item in
                                let stored = mode == .sfSymbol ? "sf:\(item)" : item
                                let isSelected = selectedEmoji == stored && selectedIsCurrentMode

                                Button {
                                    selectedEmoji = stored
                                    isPresented = false
                                } label: {
                                    Group {
                                        if mode == .sfSymbol {
                                            Image(systemName: item)
                                                .font(.system(size: 22, weight: .regular))
                                                .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.textPrimary)
                                        } else {
                                            Text(item)
                                                .font(.system(size: 30))
                                        }
                                    }
                                    .frame(width: 52, height: 52)
                                    .background(isSelected && mode == .sfSymbol ? AppTheme.accent : Color.clear)
                                    .hairline(isSelected ? AppTheme.accent : .clear)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

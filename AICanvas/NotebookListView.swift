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
    @Binding var selectedNotebook: Notebook?
    @Binding var folderPath: [Folder]
    @Binding var showSidebar: Bool

    private var selectedFolder: Folder? { folderPath.last }
    
    @State private var showCreateNotebook = false
    @State private var showCreateFolder = false
    @State private var showPDFImporter = false
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

            if visibleFolders.isEmpty && visibleNotebooks.isEmpty {
                VStack(spacing: 0) {
                    listHeader
                        .padding(.bottom, 8)
                    emptyState
                }
            } else {
                ScrollView {
                    gridContent
                        .padding(20)
                        .padding(.bottom, 40)
                }
                .onDrop(of: [.data], delegate: RootDropDelegate(store: store))
                .safeAreaInset(edge: .top, spacing: 0) {
                    listHeader
                        .padding(.bottom, 8)
                        .background(AppTheme.background)
                }
            }
        }
    }

    private var gridContent: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(visibleFolders) { folder in
                let folderIndex = store.folders.firstIndex(of: folder) ?? 0
                let folderDelay = Double(folderIndex) * 0.05

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
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.45).delay(folderDelay), value: appeared)
                    .highPriorityGesture(TapGesture().onEnded {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            folderPath.append(folder)
                        }
                    })
            }

            ForEach(visibleNotebooks) { notebook in
                let nbIndex = store.notebooks.firstIndex(of: notebook) ?? 0
                let combinedIndex = visibleFolders.count + nbIndex
                let nbDelay = Double(combinedIndex) * 0.05

                NotebookCard(notebook: notebook, syncManager: syncManager)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.45).delay(nbDelay), value: appeared)
            }

            newItemCards
        }
    }

    @ViewBuilder
    private var newItemCards: some View {
        let baseCount = visibleFolders.count + visibleNotebooks.count

        let newFolderDelay = Double(baseCount) * 0.05
        NewItemCard(title: "Nova Pasta", icon: "folder.badge.plus") { showCreateFolder = true }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45).delay(newFolderDelay), value: appeared)

        let newNotebookDelay = Double(baseCount + 1) * 0.05
        NewItemCard(title: "Novo Caderno", icon: "plus") { showCreateNotebook = true }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45).delay(newNotebookDelay), value: appeared)

        let importPDFDelay = Double(baseCount + 2) * 0.05
        NewItemCard(title: "Importar PDF", icon: "doc.badge.plus") { showPDFImporter = true }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45).delay(importPDFDelay), value: appeared)
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 12) {
                if !showSidebar {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showSidebar = true
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(8)
                            .background(AppTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let folder = selectedFolder {
                        Group {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    _ = folderPath.removeLast()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isHeaderDropTargeted ? "tray.and.arrow.down.fill" : "chevron.left")
                                    Text(folderPath.count > 1 ? folderPath[folderPath.count - 2].name : "Início")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(isHeaderDropTargeted ? AppTheme.accent : AppTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isHeaderDropTargeted ? AppTheme.accent.opacity(0.15) : AppTheme.textSecondary.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(isHeaderDropTargeted ? AppTheme.accent.opacity(0.6) : Color.clear, lineWidth: 1.5))
                                .animation(.spring(response: 0.25), value: isHeaderDropTargeted)
                            }
                            .buttonStyle(.plain)
                            .onDrop(of: [.data], delegate: ParentDropDelegate(
                                targetFolderId: parentFolderId,
                                store: store,
                                isTargeted: $isHeaderDropTargeted
                            ))
                            .padding(.bottom, 4)

                            HStack(spacing: 8) {
                                NoteIcon(icon: folder.emoji, size: 30)
                                Text(folder.name)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                    } else {
                        Group {
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
                    Image(systemName: selectedFolder == nil ? "books.vertical.fill" : "folder.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textSecondary)
                    let count = selectedFolder == nil ? store.notebooks.count + store.folders.filter { $0.parentFolderId == nil }.count : visibleNotebooks.count + visibleFolders.count
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
                Text(selectedFolder == nil ? "Espaço vazio" : "Pasta vazia")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Crie seu primeiro item e solte a imaginação\ncom a ajuda de IA poderosa.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 12) {
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

                Button {
                    showCreateNotebook = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Criar Caderno")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)

                Button {
                    showPDFImporter = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                        Text("Importar PDF")
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

            Spacer()
        }
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  let notebook = store.createNotebookFromPDF(sourceURL: url, folderId: selectedFolder?.id) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedNotebook = notebook
            }
        case .failure(let error):
            print("PDF import canceled/failed: \(error)")
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
                if let imageData = folder.bannerImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 60)
                        .clipped()
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [accentColor.opacity(0.3), accentColor.opacity(0.05)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 60)
                }

                HStack {
                    NoteIcon(icon: folder.emoji, size: 28)
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
    @ObservedObject var syncManager: SyncManager
    @State private var hovered = false

    private var accentColor: Color {
        notebookSwiftColor(at: notebook.colorIndex)
    }

    private var isSyncing: Bool { syncManager.syncingNotebooks.contains(notebook.id) }
    private var hasChanges: Bool { syncManager.notebookHasChanges(notebook) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let imageData = notebook.bannerImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 70)
                        .clipped()
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [accentColor.opacity(0.4), accentColor.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 70)
                }

                NoteIcon(icon: notebook.emoji, size: 34)
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

                    Spacer()

                    if SyncSettings.load().isConfigured && (hasChanges || isSyncing) {
                        Button {
                            guard !isSyncing else { return }
                            Task { await syncManager.syncNotebook(notebook) }
                        } label: {
                            Group {
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(accentColor)
                                }
                            }
                            .padding(6)
                            .background(accentColor.opacity(0.1))
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3), value: hasChanges)
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
                            if let data = bannerImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.surfaceElevated)
                                    .frame(height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.border, lineWidth: 1)
                                    )
                            }

                            HStack(spacing: 14) {
                                NoteIcon(icon: selectedEmoji, size: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name.isEmpty ? "Nome" : name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary.opacity(name.isEmpty ? 0.6 : 1.0))
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

                            Button { showEmojiPicker = true } label: {
                                HStack(spacing: 12) {
                                    NoteIcon(icon: selectedEmoji, size: 32)
                                        .frame(width: 56, height: 56)
                                        .background(AppTheme.background)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Toque para escolher")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("Biblioteca de emojis por categoria")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.textMuted)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                                .padding(12)
                                .background(AppTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .sheet(isPresented: $showEmojiPicker) {
                                EmojiPickerView(selectedEmoji: $selectedEmoji, isPresented: $showEmojiPicker)
                            }
                        }

                        // Banner Image Picker
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("BANNER PERSONALIZADO (IMAGEM)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.textMuted)
                                Spacer()
                                if bannerImageData != nil {
                                    Button("Remover", role: .destructive) {
                                        bannerImageData = nil
                                        selectedBannerItem = nil
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                }
                            }

                            PhotosPicker(selection: $selectedBannerItem, matching: .images) {
                                if let data = bannerImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                        Text("Selecionar Imagem")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4])))
                                }
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedBannerItem) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        await MainActor.run {
                                            withAnimation { bannerImageData = data }
                                        }
                                    }
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
                                .foregroundStyle(Color(uiColor: .systemBackground))
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

// MARK: - Note Icon

struct NoteIcon: View {
    let icon: String
    var size: CGFloat = 28

    var isSFSymbol: Bool { icon.hasPrefix("sf:") }
    var symbolName: String { String(icon.dropFirst(3)) }

    var body: some View {
        if isSFSymbol {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.75, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: size, height: size)
        } else {
            Text(icon)
                .font(.system(size: size))
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
        withAnimation(.spring(response: 0.25)) { isTargeted = true }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.spring(response: 0.25)) { isTargeted = false }
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
        formatter.locale = Locale(identifier: "pt_BR")
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
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") { isPresented = false }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .buttonStyle(.plain)

                    Spacer()

                    Text("Escolher Ícone")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Text("Cancelar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)

                // Mode toggle
                Picker("Modo", selection: $mode) {
                    ForEach(IconPickerMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
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
                .padding(12)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Category tabs (hidden during search)
                if searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(currentCategories.indices, id: \.self) { idx in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCategoryIndex == idx ? AppTheme.surfaceElevated : .clear)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(selectedCategoryIndex == idx ? AppTheme.border : .clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.2), value: selectedCategoryIndex)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
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
                                                .font(.system(size: 24, weight: .medium))
                                                .foregroundStyle(AppTheme.textPrimary)
                                        } else {
                                            Text(item)
                                                .font(.system(size: 30))
                                        }
                                    }
                                    .frame(width: 52, height: 52)
                                    .background(isSelected ? AppTheme.accent.opacity(0.12) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? AppTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

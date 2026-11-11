import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @ObservedObject var store: NotebookStore
    @ObservedObject var syncManager: SyncManager
    @Binding var selectedNotebook: Notebook?
    @Binding var folderPath: [Folder]
    @Binding var showSidebar: Bool

    private var selectedFolder: Folder? { folderPath.last }

    @State private var expandedFolders: Set<UUID> = []

    @State private var showCreateNotebook = false
    @State private var showCreateFolder = false
    @State private var showPDFImporter = false
    @State private var showSyncSettings = false
    @State private var showSettings = false
    @State private var creatingInFolderId: UUID? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Workspace Header
            HStack(spacing: 10) {
                Image("AppImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .colorInvert(colorScheme == .dark)

                Text("Meu Workspace")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                Button {
                    withAnimation(AppTheme.motion) {
                        showSidebar = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    
                    // Root space
                    SidebarItemButton(
                        icon: "square.grid.2x2",
                        title: "Início",
                        isSelected: selectedNotebook == nil && folderPath.isEmpty
                    ) {
                        withAnimation {
                            selectedNotebook = nil
                            folderPath.removeAll()
                        }
                    }
                    
                    let rootFolders = store.folders.filter { $0.parentFolderId == nil }
                    if !rootFolders.isEmpty {
                        SectionLabel("PASTAS")
                            .padding(.top, 20)
                            .padding(.bottom, 6)
                            .padding(.horizontal, 16)

                        // Folders
                        ForEach(rootFolders) { folder in
                            FolderSidebarRow(
                                folder: folder,
                                notebooks: store.notebooks.filter { $0.folderId == folder.id },
                                isExpanded: expandedFolders.contains(folder.id),
                                isSelected: selectedFolder?.id == folder.id && selectedNotebook == nil,
                                selectedNotebook: $selectedNotebook,
                                folderPath: $folderPath,
                                onToggle: {
                                    withAnimation(AppTheme.motion) {
                                        if expandedFolders.contains(folder.id) {
                                            expandedFolders.remove(folder.id)
                                        } else {
                                            expandedFolders.insert(folder.id)
                                        }
                                    }
                                },
                                onSelect: {
                                    withAnimation {
                                        folderPath = [folder]
                                        selectedNotebook = nil
                                    }
                                },
                                onAddNotebook: {
                                    creatingInFolderId = folder.id
                                    showCreateNotebook = true
                                }
                            )
                        }
                    }
                    
                    // Notebooks sem pasta
                    let rootNotebooks = store.notebooks.filter { $0.folderId == nil }
                    if !rootNotebooks.isEmpty {
                        SectionLabel("CADERNOS")
                            .padding(.top, 20)
                            .padding(.bottom, 6)
                            .padding(.horizontal, 16)
                        
                        ForEach(rootNotebooks) { notebook in
                            NotebookSidebarRow(
                                notebook: notebook,
                                isSelected: selectedNotebook?.id == notebook.id
                            ) {
                                withAnimation {
                                    selectedNotebook = notebook
                                    folderPath.removeAll()
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Bottom actions
            VStack(spacing: 0) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
                    .padding(.bottom, 4)
                
                Button {
                    showCreateFolder = true
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .frame(width: 20)
                        Text("Nova Pasta")
                        Spacer()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button {
                    creatingInFolderId = nil
                    showCreateNotebook = true
                } label: {
                    HStack {
                        Image(systemName: "plus.square.on.square")
                            .frame(width: 20)
                        Text("Novo Caderno")
                        Spacer()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    showPDFImporter = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .frame(width: 20)
                        Text("Importar PDF")
                        Spacer()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Rectangle().fill(AppTheme.border).frame(height: 1)
                    .padding(.top, 4)

                HStack(spacing: 0) {
                    Button {
                        if SyncSettings.load().isConfigured {
                            Task { await syncManager.sync() }
                        } else {
                            showSyncSettings = true
                        }
                    } label: {
                        HStack {
                            if syncManager.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 20)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .frame(width: 20)
                            }
                            Text(syncManager.isSyncing ? "Sincronizando…" : "Sincronizar")
                            Spacer()
                            if !SyncSettings.load().isConfigured {
                                Rectangle()
                                    .fill(AppTheme.accent)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.leading, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(syncManager.isSyncing)

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(AppTheme.surface.ignoresSafeArea())
        .sheet(isPresented: $showCreateFolder) {
            ItemEditorSheet(store: store, mode: .createFolder(parentFolderId: selectedFolder?.id), isPresented: $showCreateFolder)
        }
        .sheet(isPresented: $showCreateNotebook) {
            ItemEditorSheet(store: store, mode: .createNotebook(folderId: creatingInFolderId), isPresented: $showCreateNotebook)
        }
        .sheet(isPresented: $showSyncSettings) {
            SyncSettingsView(syncManager: syncManager)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(syncManager: syncManager)
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            handlePDFImport(result)
        }
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  let notebook = store.createNotebookFromPDF(sourceURL: url, folderId: selectedFolder?.id) else { return }
            withAnimation {
                selectedNotebook = notebook
            }
        case .failure(let error):
            print("PDF import canceled/failed: \(error)")
        }
    }
}

// MARK: - Row Components

struct SidebarItemButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @ObservedObject private var localization = LocalizationManager.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(title.localized)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected || isHovered ? AppTheme.surfaceElevated : Color.clear)
            .overlay(Rectangle().fill(isSelected ? AppTheme.accent : .clear).frame(width: 2), alignment: .leading)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover in isHovered = hover }
    }
}

struct FolderSidebarRow: View {
    let folder: Folder
    let notebooks: [Notebook]
    let isExpanded: Bool
    let isSelected: Bool
    @Binding var selectedNotebook: Notebook?
    @Binding var folderPath: [Folder]
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onAddNotebook: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    Button(action: onToggle) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    NoteIcon(icon: folder.emoji, size: 14)
                    Text(folder.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isHovered {
                        Button(action: onAddNotebook) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.textMuted)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hairline()
                    }
                }
                .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isSelected || isHovered ? AppTheme.surfaceElevated : Color.clear)
                .overlay(Rectangle().fill(isSelected ? AppTheme.accent : .clear).frame(width: 2), alignment: .leading)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hover in isHovered = hover }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if notebooks.isEmpty {
                        Text("Pasta vazia")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                            .padding(.leading, 42)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(notebooks) { notebook in
                            NotebookSidebarRow(
                                notebook: notebook,
                                isSelected: selectedNotebook?.id == notebook.id
                            ) {
                                withAnimation {
                                    selectedNotebook = notebook
                                    folderPath = [folder]
                                }
                            }
                            .padding(.leading, 18)
                        }
                    }
                }
            }
        }
    }
}

struct NotebookSidebarRow: View {
    let notebook: Notebook
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                NoteIcon(icon: notebook.emoji, size: 14)
                    .frame(width: 16)
                
                Text(notebook.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
            }
            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected || isHovered ? AppTheme.surfaceElevated : Color.clear)
            .overlay(Rectangle().fill(isSelected ? AppTheme.accent : .clear).frame(width: 2), alignment: .leading)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover in isHovered = hover }
    }
}

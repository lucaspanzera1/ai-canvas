import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: NotebookStore
    @Binding var selectedNotebook: Notebook?
    @Binding var selectedFolder: Folder?
    @Binding var showSidebar: Bool
    
    @State private var expandedFolders: Set<UUID> = []
    
    @State private var showCreateNotebook = false
    @State private var showCreateFolder = false
    @State private var creatingInFolderId: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Workspace Header
            HStack(spacing: 10) {
                Image("AppImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: AppTheme.shadowColor, radius: 2, y: 1)
                
                Text("Meu Workspace")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showSidebar = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(6)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    
                    // Root space
                    SidebarItemButton(
                        icon: "square.grid.2x2",
                        title: "Início",
                        isSelected: selectedNotebook == nil && selectedFolder == nil
                    ) {
                        withAnimation {
                            selectedNotebook = nil
                            selectedFolder = nil
                        }
                    }
                    
                    if !store.folders.isEmpty {
                        Text("PASTAS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                            .padding(.horizontal, 16)
                        
                        // Folders
                        ForEach(store.folders) { folder in
                            FolderSidebarRow(
                                folder: folder,
                                notebooks: store.notebooks.filter { $0.folderId == folder.id },
                                isExpanded: expandedFolders.contains(folder.id),
                                isSelected: selectedFolder?.id == folder.id && selectedNotebook == nil,
                                selectedNotebook: $selectedNotebook,
                                selectedFolder: $selectedFolder,
                                onToggle: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if expandedFolders.contains(folder.id) {
                                            expandedFolders.remove(folder.id)
                                        } else {
                                            expandedFolders.insert(folder.id)
                                        }
                                    }
                                },
                                onSelect: {
                                    withAnimation {
                                        selectedFolder = folder
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
                        Text("CADERNOS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                            .padding(.horizontal, 16)
                        
                        ForEach(rootNotebooks) { notebook in
                            NotebookSidebarRow(
                                notebook: notebook,
                                isSelected: selectedNotebook?.id == notebook.id
                            ) {
                                withAnimation {
                                    selectedNotebook = notebook
                                    selectedFolder = nil
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Bottom actions
            VStack(spacing: 0) {
                Divider()
                    .foregroundStyle(AppTheme.border.opacity(0.5))
                
                Button {
                    showCreateFolder = true
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .frame(width: 20)
                        Text("Nova Pasta")
                        Spacer()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.95).ignoresSafeArea()) // Lighter sidebar background like Notion
        .sheet(isPresented: $showCreateFolder) {
            ItemEditorSheet(store: store, mode: .createFolder, isPresented: $showCreateFolder)
        }
        .sheet(isPresented: $showCreateNotebook) {
            ItemEditorSheet(store: store, mode: .createNotebook(folderId: creatingInFolderId), isPresented: $showCreateNotebook)
        }
    }
}

// MARK: - Row Components

struct SidebarItemButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.border.opacity(0.5) : (isHovered ? AppTheme.border.opacity(0.3) : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
    @Binding var selectedFolder: Folder?
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
                    
                    Text(folder.emoji)
                        .font(.system(size: 14))
                    Text(folder.name)
                        .font(.system(size: 14, weight: .semibold))
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
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isSelected ? AppTheme.border.opacity(0.5) : (isHovered ? AppTheme.border.opacity(0.3) : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
                                    selectedFolder = folder
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
                Text(notebook.emoji)
                    .font(.system(size: 14))
                    .frame(width: 16)
                
                Text(notebook.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Spacer()
            }
            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.border.opacity(0.5) : (isHovered ? AppTheme.border.opacity(0.3) : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover in isHovered = hover }
    }
}

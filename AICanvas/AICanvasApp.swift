import SwiftUI

@main
struct AICanvasApp: App {
    @StateObject private var store = NotebookStore()
    @State private var selectedNotebook: Notebook?
    @State private var selectedFolder: Folder?
    @State private var showSidebar = true

    var body: some Scene {
        WindowGroup {
            HStack(spacing: 0) {
                // Sidebar Layout (Notion Style)
                if showSidebar {
                    SidebarView(
                        store: store,
                        selectedNotebook: $selectedNotebook,
                        selectedFolder: $selectedFolder,
                        showSidebar: $showSidebar
                    )
                    .frame(width: 260)
                    .transition(AnyTransition.move(edge: .leading))
                    
                    Divider() // Separator
                }
                
                // Main Content
                ZStack {
                    if let notebook = selectedNotebook {
                        ContentView(
                            notebook: notebook,
                            store: store,
                            selectedNotebook: $selectedNotebook,
                            showSidebar: $showSidebar
                        )
                        .id(notebook.id)
                    } else {
                        NotebookListView(
                            store: store,
                            selectedNotebook: $selectedNotebook,
                            selectedFolder: $selectedFolder,
                            showSidebar: $showSidebar
                        )
                        .id(selectedFolder?.id ?? UUID())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSidebar)
        }
    }
}

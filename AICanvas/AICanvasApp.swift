import SwiftUI

@main
struct AICanvasApp: App {
    @StateObject private var store = NotebookStore()
    @StateObject private var syncManager: SyncManager
    @StateObject private var pomodoroManager = PomodoroManager()
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var selectedNotebook: Notebook?
    @State private var folderPath: [Folder] = []
    @State private var showSidebar = true

    init() {
        let s = NotebookStore()
        _store = StateObject(wrappedValue: s)
        _syncManager = StateObject(wrappedValue: SyncManager(store: s))
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: 0) {
                    // Sidebar Layout (Notion Style)
                    if showSidebar {
                        SidebarView(
                            store: store,
                            syncManager: syncManager,
                            selectedNotebook: $selectedNotebook,
                            folderPath: $folderPath,
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
                                syncManager: syncManager,
                                selectedNotebook: $selectedNotebook,
                                showSidebar: $showSidebar
                            )
                            .id(notebook.id)
                        } else {
                            NotebookListView(
                                store: store,
                                syncManager: syncManager,
                                selectedNotebook: $selectedNotebook,
                                folderPath: $folderPath,
                                showSidebar: $showSidebar
                            )
                            .id(folderPath.last?.id)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSidebar)

                // Floating Pomodoro widget — stays on top across every screen
                PomodoroWidgetView(manager: pomodoroManager)
            }
            .environment(\.locale, localization.locale)
        }
    }
}

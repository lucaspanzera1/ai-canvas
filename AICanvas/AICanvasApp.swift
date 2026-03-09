import SwiftUI

@main
struct AICanvasApp: App {
    @StateObject private var store = NotebookStore()
    @State private var selectedNotebook: Notebook?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let notebook = selectedNotebook {
                    ContentView(
                        notebook: notebook,
                        store: store,
                        selectedNotebook: $selectedNotebook
                    )
                    .id(notebook.id) // força recriação ao trocar de caderno
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    NotebookListView(
                        store: store,
                        selectedNotebook: $selectedNotebook
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedNotebook)
        }
    }
}

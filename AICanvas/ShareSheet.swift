import SwiftUI
import UIKit

// MARK: - Identifiable wrapper so .sheet(item:) works

struct ExportableItem: Identifiable {
    let id = UUID()
    let item: Any
}

// MARK: - SwiftUI-safe UIActivityViewController wrapper

/// Presents UIActivityViewController correctly via UIViewControllerRepresentable,
/// avoiding the _UIReparentingView warning that occurs when using rootVC.present() directly.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

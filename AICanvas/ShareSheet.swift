import SwiftUI
import UIKit

// MARK: - Identifiable wrapper so .sheet(item:) works

struct ExportableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - SwiftUI-safe UIActivityViewController wrapper

/// Presents UIActivityViewController correctly via UIViewControllerRepresentable,
/// avoiding the _UIReparentingView warning that occurs when using rootVC.present() directly.
struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let viewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = viewController.popoverPresentationController {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let rootView = windowScene?.windows.first?.rootViewController?.view
            let screen = rootView?.window?.windowScene?.screen
            popover.sourceView = rootView
            popover.sourceRect = CGRect(
                x: (screen?.bounds.midX) ?? 0,
                y: (screen?.bounds.midY) ?? 0,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

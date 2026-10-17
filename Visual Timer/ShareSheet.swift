import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let viewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        configurePopover(for: viewController)
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        configurePopover(for: uiViewController)
    }

    private func configurePopover(for viewController: UIActivityViewController) {
        if let popover = viewController.popoverPresentationController {
            let sourceView = viewController.view
            popover.sourceView = sourceView
            popover.sourceRect = CGRect(
                x: sourceView?.bounds.midX ?? 0,
                y: sourceView?.bounds.midY ?? 0,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
    }
}

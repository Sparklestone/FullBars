import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    let activityItems: [Any]?

    init(text: String) {
        self.text = text
        self.activityItems = nil
    }

    init(activityItems: [Any]) {
        self.text = ""
        self.activityItems = activityItems
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items = activityItems ?? [text]
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

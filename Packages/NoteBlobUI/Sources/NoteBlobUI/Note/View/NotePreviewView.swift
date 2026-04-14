import SwiftUI

struct NotePreviewView: View {

    let content: String
    let mode: PreviewMode

    var body: some View {
        MarkdownRendererView(source: content, mode: mode)
    }
}

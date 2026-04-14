import SwiftUI

struct LastChangeDateView: View {

    @Environment(\.horizontalContentMargin) private var horizontalMargin

    let date: Date?

    var body: some View {
        HStack {
            Group {
                if let date {
                    Text(date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                } else {
                    Text(verbatim: " ")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, horizontalMargin)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

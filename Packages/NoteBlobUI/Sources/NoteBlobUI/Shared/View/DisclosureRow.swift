import SwiftUI

struct DisclosureRow: View {

    let title: String
    var subtitle: String? = nil
    var detail: AttributedString? = nil
    let systemImage: String

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
            } icon: {
                Image(systemName: systemImage)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}

import MCPServerKit
import SwiftUI

// MARK: - Links

private enum AccountLinks {
    static let contact = URL(string: "mailto:rectangle-cornees.2c@icloud.com")!
    static let contributing = URL(string: "https://github.com/gaetanzanella/noteblob-public")!
    static let reportIssue = URL(string: "https://github.com/gaetanzanella/noteblob-public/issues")!
}

public struct AccountView: View {

    @State var presenter: AccountPresenter
    @Environment(\.dismiss) private var dismiss

    public init(presenter: AccountPresenter) {
        self._presenter = State(initialValue: presenter)
    }

    public var body: some View {
        #if os(macOS)
        macOSBody()
        #else
        iOSBody()
        #endif
    }

    #if os(macOS)
    private func macOSBody() -> some View {
        let viewModel = presenter.viewModel()
        return VStack(spacing: 16) {
            Text("account.title", bundle: .module)
                .font(.headline)

            Spacer()

            if viewModel.isAuthenticated {
                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        presenter.on(.logout)
                    } label: {
                        Text("account.clear_token", bundle: .module)
                    }
                    Text("account.authenticated.description", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                ContentUnavailableView(
                    String.localized("account.empty.title"),
                    systemImage: "person.crop.circle",
                    description: Text("account.empty.description", bundle: .module)
                )
            }

            Divider()

            #if os(macOS)
            MCPServerSection(presenter: presenter)
            #endif

            Divider()

            Section {
                Link(destination: AccountLinks.contact) {
                    Label(String.localized("account.contact.email"), systemImage: "envelope")
                }
            } header: {
                Text("account.contact.title", bundle: .module)
            }

            Divider()

            Section {
                Link(destination: AccountLinks.contributing) {
                    Label(String.localized("account.contributing.github"), systemImage: "curlybraces")
                }
                Link(destination: AccountLinks.reportIssue) {
                    Label(String.localized("account.contributing.report_issue"), systemImage: "exclamationmark.bubble")
                }
            } header: {
                Text("account.contributing.title", bundle: .module)
            }

            Spacer()

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("common.done", bundle: .module)
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .scenePadding()
        .frame(minWidth: 300, minHeight: 200)
        .task { await presenter.onAsync(.onAppear) }
    }
    #endif

    #if os(iOS)
    private func iOSBody() -> some View {
        let viewModel = presenter.viewModel()
        return NavigationStack {
            Form {
                if viewModel.isAuthenticated {
                    Section {
                        Button(role: .destructive) {
                            presenter.on(.logout)
                        } label: {
                            Text("account.clear_token", bundle: .module)
                        }
                    } footer: {
                        Text("account.authenticated.description", bundle: .module)
                    }
                }
                Section {
                    Link(destination: AccountLinks.contact) {
                        Label(String.localized("account.contact.email"), systemImage: "envelope")
                    }
                } header: {
                    Text("account.contact.title", bundle: .module)
                }
                Section {
                    Link(destination: AccountLinks.contributing) {
                        Label(String.localized("account.contributing.github"), systemImage: "curlybraces")
                    }
                    Link(destination: AccountLinks.reportIssue) {
                        Label(String.localized("account.contributing.report_issue"), systemImage: "exclamationmark.bubble")
                    }
                } header: {
                    Text("account.contributing.title", bundle: .module)
                }
            }
            .navigationTitle(Text("account.title", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("common.done", bundle: .module)
                    }
                }
            }
            .task { await presenter.onAsync(.onAppear) }
        }
    }
    #endif
}

// MARK: - MCP Server Section

#if os(macOS)
private struct MCPServerSection: View {

    let presenter: AccountPresenter

    var body: some View {
        let viewModel = presenter.viewModel()
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.isMCPServerEnabled },
                set: { presenter.on(.toggleMCPServer($0)) }
            )) {
                Text("account.mcp.toggle", bundle: .module)
            }
            StatusBadge(status: viewModel.mcpServerStatus)
                .frame(maxWidth: .infinity, alignment: .leading)
            if case .running = viewModel.mcpServerStatus {
                VStack(alignment: .leading, spacing: 8) {
                    Text("account.mcp.config_label", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(configSnippet)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        } header: {
            Text("account.mcp.title", bundle: .module)
        } footer: {
            Text("account.mcp.footer", bundle: .module)
        }
    }

    private var configSnippet: String {
        """
        {
          "mcpServers": {
            "noteblob": {
              "url": "http://localhost:9100/mcp"
            }
          }
        }
        """
    }
}

private struct StatusBadge: View {

    let status: MCPServerStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch status {
        case .running: .green
        case .starting: .orange
        case .failed: .red
        case .stopped: .secondary
        }
    }

    private var label: String {
        switch status {
        case .running: String.localized("account.mcp.status.running")
        case .starting: String.localized("account.mcp.status.starting")
        case .failed(let message): message
        case .stopped: String.localized("account.mcp.status.stopped")
        }
    }
}
#endif

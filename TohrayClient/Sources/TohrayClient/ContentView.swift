import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PostViewModel()
    @State private var showSettings = false
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 0) {
            MarkdownEditor(
                text: $viewModel.content,
                focusOnAppear: true,
                onCommandReturn: submit,
                onCommandP: togglePreview
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Slug (optional, auto-generated if empty)", text: $viewModel.slug)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)

                if !viewModel.statusMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: viewModel.isError ? "exclamationmark.circle" : "checkmark.circle")
                            Text(viewModel.statusMessage)
                        }
                        .foregroundColor(viewModel.isError ? .red : .green)

                        if let postedURL = viewModel.postedURL {
                            HStack(spacing: 8) {
                                Link(postedURL.absoluteString, destination: postedURL)
                                    .textSelection(.enabled)

                                Button(action: { viewModel.copyURLToClipboard() }) {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.plain)
                                .help("Copy link")
                            }
                        }
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")

                    Spacer()

                    Button("Clear") {
                        viewModel.clear()
                    }
                    .buttonStyle(.bordered)

                    Button(action: togglePreview) {
                        HStack(spacing: 8) {
                            Text("Preview")
                            Text("⌘P")
                                .font(.callout)
                                .opacity(0.8)
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("Preview (⌘P)")

                    Button(action: submit) {
                        HStack(spacing: 8) {
                            Text("Post")
                            Text("⌘↩")
                                .font(.callout)
                                .opacity(0.8)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Post (⌘↩)")
                    .disabled(viewModel.content.isEmpty || viewModel.isPosting)
                }
                .controlSize(.large)
            }
            .padding(14)
        }
        .frame(minWidth: 480, minHeight: 360)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPreview) {
            MarkdownPreviewView(markdown: viewModel.content)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMarkdownPreview)) { _ in
            togglePreview()
        }
    }

    private func togglePreview() {
        showPreview.toggle()
    }

    private func submit() {
        guard !viewModel.content.isEmpty, !viewModel.isPosting else { return }
        Task {
            await viewModel.post()
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Tohray URL", text: $viewModel.url)
                    .textFieldStyle(.roundedBorder)

                TextField("Username", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .foregroundColor(viewModel.isError ? .red : .green)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Test Connection") {
                    Task {
                        await viewModel.testConnection()
                    }
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    viewModel.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 500, height: 350)
    }
}

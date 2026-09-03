import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PostViewModel()
    @State private var showSettings = false
    @State private var showPreview = false
    @State private var showEdit = false

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

                if let editingSlug = viewModel.editingSlug {
                    HStack {
                        Text("Editing: \(editingSlug)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Stop Editing") {
                            viewModel.stopEditing()
                        }
                        .buttonStyle(.link)
                    }
                }

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

                    Button(action: { showEdit = true }) {
                        Image(systemName: "square.and.pencil")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("e", modifiers: .command)
                    .help("Edit an existing entry (⌘E)")

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
                            Text(viewModel.isEditing ? "Update" : "Post")
                            Text("⌘↩")
                                .font(.callout)
                                .opacity(0.8)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help(viewModel.isEditing ? "Save changes (⌘↩)" : "Post (⌘↩)")
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
        .sheet(isPresented: $showEdit) {
            EditPostListView(viewModel: viewModel) {
                showEdit = false
            }
        }
        .sheet(isPresented: $showPreview) {
            MarkdownPreviewView(markdown: viewModel.content)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMarkdownPreview)) { _ in
            togglePreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
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

struct EditPostListView: View {
    @ObservedObject var viewModel: PostViewModel
    @Environment(\.dismiss) private var dismiss
    var onSelect: () -> Void
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Post")
                .font(.title2)
                .fontWeight(.bold)
                .padding()

            Divider()

            Group {
                if viewModel.isLoadingPosts {
                    ProgressView("Loading posts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.posts.isEmpty {
                    VStack(spacing: 8) {
                        Text("No posts found")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        if viewModel.isError {
                            Text(viewModel.statusMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.posts) { post in
                        Button {
                            selectedID = post.id
                            viewModel.startEdit(post)
                            onSelect()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(post.slug)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(post.created)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(post.content)
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedID == post.id ? Color.accentColor.opacity(0.12) : Color.clear)
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 520, height: 420)
        .task {
            await viewModel.loadPosts()
        }
    }
}

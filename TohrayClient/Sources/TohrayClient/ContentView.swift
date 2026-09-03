import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PostViewModel()
    @State private var showSettings = false
    @State private var showPreview = false
    @State private var showEdit = false
    @State private var showImageUpload = false
    @StateObject private var editorRef = EditorReference()

    /// Box that owns the markdown editor's coordinator so insertions can reach
    /// the live text view from anywhere in this view hierarchy.
    final class EditorReference: ObservableObject {
        @Published var coordinators: MarkdownEditor.CoordinatorReference = MarkdownEditor.CoordinatorReference()
    }

    var body: some View {
        VStack(spacing: 0) {
            MarkdownEditor(
                text: $viewModel.content,
                focusOnAppear: true,
                coordinatorRef: editorRef.coordinators,
                onCommandReturn: submit,
                onCommandP: togglePreview,
                onCommandI: presentImageUpload
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
        .sheet(isPresented: $showImageUpload) {
            ImageUploadSheet { markdown in
                insertAtCursor(markdown)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMarkdownPreview)) { _ in
            togglePreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .insertImage)) { _ in
            presentImageUpload()
        }
    }

    private func togglePreview() {
        showPreview.toggle()
    }

    private func presentImageUpload() {
        showImageUpload = true
    }

    private func insertAtCursor(_ markdown: String) {
        editorRef.coordinators.coordinator?.insertMarkdown(markdown)
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
    @State private var selectedTab: SettingsTab = .tohray
    @State private var showACLCustom = false

    enum SettingsTab: String, CaseIterable {
        case tohray = "Tohray"
        case imageStorage = "Image Storage"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)

            Picker("Tab", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)

            Group {
                switch selectedTab {
                case .tohray:
                    tohrayForm
                case .imageStorage:
                    s3Form
                }
            }
            .frame(maxHeight: 460)

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .foregroundColor(viewModel.isError ? .red : .green)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                if selectedTab == .imageStorage {
                    Button("Test S3 Upload") {
                        Task {
                            await viewModel.testS3Upload()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.s3Config.isConfigured)
                } else {
                    Button("Test Connection") {
                        Task {
                            await viewModel.testConnection()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Button("Save") {
                    viewModel.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520, height: 620)
        .onAppear {
            // If the stored ACL from a previous session isn't one of the preset
            // options (e.g. a custom value), show the free-text field.
            if !S3Config.aclOptions.contains(viewModel.s3ACL) {
                showACLCustom = true
            }
        }
    }

    private var tohrayForm: some View {
        Form {
            Section("Tohray Server") {
                TextField("Tohray URL", text: $viewModel.url)
                    .textFieldStyle(.roundedBorder)
                TextField("Username", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
    }

    private var s3Form: some View {
        Form {
            Section("Image Storage (S3 / Cloudflare R2)") {
                Picker("Provider", selection: $viewModel.s3Provider) {
                    ForEach(S3Config.providers, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
                .onChange(of: viewModel.s3Provider) { provider in
                    applyProviderDefaults(provider)
                }

                TextField("Access Key ID", text: $viewModel.s3AccessKeyID)
                    .textFieldStyle(.roundedBorder)
                SecureField("Secret Access Key", text: $viewModel.s3SecretAccessKey)
                    .textFieldStyle(.roundedBorder)
                SecureField("Session Token (optional)", text: $viewModel.s3SessionToken)
                    .textFieldStyle(.roundedBorder)
                TextField("Endpoint", text: $viewModel.s3Endpoint)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g. https://<account>.r2.cloudflarestorage.com or https://s3.amazonaws.com")

                if let issue = viewModel.s3Config.endpointIssue {
                    Label(issue, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                aclPicker

                TextField("Bucket", text: $viewModel.s3Bucket)
                    .textFieldStyle(.roundedBorder)
                TextField("Root Directory (prefix)", text: $viewModel.s3RootDir)
                    .textFieldStyle(.roundedBorder)
                    .help("Objects are stored under this prefix, e.g. /appname/")
                TextField("Public URL (optional)", text: $viewModel.s3PublicURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Your custom CDN/public URL. Falls back to the endpoint if empty.")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var aclPicker: some View {
        if showACLCustom {
            TextField("ACL (custom)", text: $viewModel.s3ACL)
                .textFieldStyle(.roundedBorder)
        } else {
            Picker("ACL", selection: $viewModel.s3ACL) {
                ForEach(S3Config.aclOptions, id: \.self) { acl in
                    Text(acl).tag(acl)
                }
                Text("Custom…").tag("custom")
            }
            .onChange(of: viewModel.s3ACL) { acl in
                if acl == "custom" {
                    showACLCustom = true
                    viewModel.s3ACL = ""
                }
            }
        }
    }

    private func applyProviderDefaults(_ provider: String) {
        // Keep things minimal: setting the provider mainly drives the signing
        // region (Cloudflare -> "auto") and endpoint style automatically inside
        // S3Config. Optionally drop in a hint for known endpoints.
        if provider == "Cloudflare" && viewModel.s3Endpoint.isEmpty {
            viewModel.s3Endpoint = ""
        }
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

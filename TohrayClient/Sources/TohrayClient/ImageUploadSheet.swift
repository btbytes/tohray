import AppKit
import SwiftUI

/// Sheet shown on ⌘I. Lets the user paste a clipboard image or pick an image
/// file, choose a name, and upload it to the configured S3 bucket. On success
/// returns the generated markdown image link via `onComplete`.
struct ImageUploadSheet: View {
    var onComplete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ImageUploadViewModel
    @State private var mode: Mode = .paste
    @State private var image: NSImage?
    @State private var filename: String = ""
    @State private var imageDescription: String = ""
    @State private var imageData: Data?
    @State private var isUploading = false
    @State private var error: String?
    @State private var diagnosticMessage: String?

    enum Mode: String, CaseIterable {
        case paste = "Paste"
        case file = "File"
    }

    init(onComplete: @escaping (String) -> Void) {
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: ImageUploadViewModel())
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Insert Image")
                .font(.title2)
                .fontWeight(.bold)

            Picker("Source", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .onChange(of: mode) { _ in
                loadForCurrentMode()
            }

            Group {
                if mode == .paste {
                    pasteSection
                } else {
                    fileSection
                }
            }

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("Image name (with extension)", text: $filename)
                    .textFieldStyle(.roundedBorder)
                TextField("Image description (optional)", text: $imageDescription)
                    .textFieldStyle(.roundedBorder)
                    .help("Used as the markdown alt text and image title.")
                if let previewURL = viewModel.destinationPreview(for: filename) {
                    Text("Will upload to: \(previewURL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: upload) {
                    if isUploading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Upload & Insert")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUploading || !canUpload)
            }
        }
        .padding(24)
        .frame(width: 480, height: 520)
        .onAppear {
            loadForCurrentMode()
        }
        .alert("S3 Upload Failed", isPresented: Binding(
            get: { diagnosticMessage != nil },
            set: { if !$0 { diagnosticMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                diagnosticMessage = nil
            }
            Button("Copy Report") {
                if let diagnosticMessage {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(diagnosticMessage, forType: .string)
                }
            }
        } message: {
            Text(diagnosticMessage ?? "")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private var canUpload: Bool {
        imageData != nil && !filename.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var pasteSection: some View {
        HStack {
            Text("Grab the image currently on your clipboard.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Load from Clipboard") {
                loadClipboardImage()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("v", modifiers: .command)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    @ViewBuilder
    private var fileSection: some View {
        HStack {
            if let chosen = viewModel.chosenFileURL {
                Text(chosen.lastPathComponent)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("Choose a file to upload.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Choose File…") {
                chooseFile()
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func loadForCurrentMode() {
        error = nil
        if mode == .paste {
            loadClipboardImage()
        } else {
            if let url = viewModel.chosenFileURL {
                loadImage(from: url)
            } else {
                image = nil
                imageData = nil
                filename = ""
            }
        }
    }

    private func loadClipboardImage() {
        guard let image = NSImage(pasteboard: NSPasteboard.general),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            error = "No image found on the clipboard."
            self.image = nil
            self.imageData = nil
            self.filename = ""
            return
        }
        loadRep(rep, fallbackName: "clipboard-\(Int(Date().timeIntervalSince1970)).png")
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.chosenFileURL = url
            loadImage(from: url)
        }
    }

    private func loadImage(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            error = "Could not read the selected file."
            return
        }
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
        imageData = data
        image = NSImage(data: data)
        filename = url.lastPathComponent.isEmpty ? "image.\(ext)" : url.lastPathComponent
    }

    private func loadRep(_ rep: NSBitmapImageRep, fallbackName: String) {
        guard let png = rep.representation(using: .png, properties: [:]) else {
            error = "Could not encode the clipboard image."
            return
        }
        imageData = png
        image = NSImage(data: png)
        if filename.isEmpty || filename.hasPrefix("clipboard-") {
            filename = fallbackName
        }
    }

    private func upload() {
        guard let imageData, !isUploading else { return }
        isUploading = true
        error = nil
        diagnosticMessage = nil
        let name = filename.trimmingCharacters(in: .whitespaces)
        let description = imageDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let markdown = try await viewModel.upload(data: imageData, filename: name, description: description)
                onComplete(markdown)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                self.diagnosticMessage = viewModel.diagnosticReport(for: name)
                isUploading = false
            }
        }
    }
}

@MainActor
class ImageUploadViewModel: ObservableObject {
    @Published var chosenFileURL: URL?

    private let uploader = S3Uploader()
    private let settings = SettingsViewModel()

    func loadConfig() -> S3Config {
        settings.s3Config
    }

    func destinationPreview(for filename: String) -> String? {
        let cleaned = filename.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        let config = loadConfig()
        guard config.isConfigured else { return nil }
        let key = config.objectKey(for: cleaned)
        return config.publicURL(for: key)?.absoluteString
    }

    func upload(data: Data, filename: String, description: String = "") async throws -> String {
        let config = loadConfig()
        let key = config.objectKey(for: filename)
        let contentType = contentType(for: filename)
        let url = try await uploader.upload(data: data, key: key, contentType: contentType, config: config)
        return markdownImage(url: url.absoluteString, alt: description.isEmpty ? displayName(filename) : description, description: description)
    }

    /// A diagnostic report describing the S3 configuration and the constructed
    /// upload URL, shown when an upload fails.
    func diagnosticReport(for filename: String) -> String {
        let config = loadConfig()
        let key = config.objectKey(for: filename)
        let uploadURL: String
        switch uploader.uploadURL(for: key, config: config) {
        case .success(let url): uploadURL = url.absoluteString
        case .failure(let reason): uploadURL = "(could not construct — \(reason))"
        }
        let publicURL = config.publicURL(for: key)?.absoluteString ?? "(could not construct)"

        var report: [String] = []
        report.append("Provider: \(config.provider)")
        report.append("Access Key ID: \(config.accessKeyID.isEmpty ? "(empty)" : config.accessKeyID)")
        report.append("Secret Access Key: \(config.secretAccessKey.isEmpty ? "(empty)" : "••••••\(min(config.secretAccessKey.count, 4))")")
        report.append("Session Token: \(config.sessionToken.isEmpty ? "(empty)" : "•\(min(config.sessionToken.count, 4))")")
        report.append("Endpoint: \(config.endpoint.isEmpty ? "(empty)" : config.endpoint)")
        report.append("ACL: \(config.acl.isEmpty ? "(empty)" : config.acl)")
        report.append("Bucket: \(config.bucket.isEmpty ? "(empty)" : config.bucket)")
        report.append("Root Dir: \(config.rootDir.isEmpty ? "(empty)" : config.rootDir)")
        report.append("Public URL: \(config.publicURL.isEmpty ? "(empty)" : config.publicURL)")
        report.append("Region: \(config.region)")
        report.append("Object Key: \(key)")
        report.append("Upload URL: \(uploadURL)")
        report.append("Public File URL: \(publicURL)")
        if let issue = config.endpointIssue {
            report.append("Endpoint issue: \(issue)")
        }
        if !config.isConfigured {
            report.append("Config issue: missing required fields (Access Key ID, Secret Access Key, Endpoint, and Bucket must all be set).")
        }
        return report.joined(separator: "\n")
    }

    /// Builds a markdown image link. When a description is supplied it is used
    /// as the alt text and as the title attribute; otherwise the filename-based
    /// display name is used for the alt text.
    private func markdownImage(url: String, alt: String, description: String) -> String {
        let title = description.replacingOccurrences(of: "\"", with: "\\\"")
        if !title.isEmpty {
            return "![\(alt)](\(url) \"\(title)\")"
        }
        return "![\(alt)](\(url))"
    }

    private func displayName(_ filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        return base.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func contentType(for filename: String) -> String {
        switch (filename as NSString).pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "tif", "tiff": return "image/tiff"
        case "svg": return "image/svg+xml"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}

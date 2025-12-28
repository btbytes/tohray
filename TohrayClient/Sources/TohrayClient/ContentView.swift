import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PostViewModel()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Tohray Client")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            // Post form
            VStack(alignment: .leading, spacing: 10) {
                Text("Slug (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Auto-generated if empty", text: $viewModel.slug)
                    .textFieldStyle(.roundedBorder)

                Text("Content")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $viewModel.content)
                    .frame(minHeight: 200)
                    .border(Color.gray.opacity(0.2), width: 1)
                    .font(.body)
            }

            // Status message
            if !viewModel.statusMessage.isEmpty {
                HStack {
                    Image(systemName: viewModel.isError ? "exclamationmark.circle" : "checkmark.circle")
                    Text(viewModel.statusMessage)
                }
                .foregroundColor(viewModel.isError ? .red : .green)
                .font(.caption)
            }

            // Buttons
            HStack {
                Spacer()

                Button("Clear") {
                    viewModel.clear()
                }
                .buttonStyle(.bordered)

                Button("Post") {
                    Task {
                        await viewModel.post()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.content.isEmpty || viewModel.isPosting)
            }
        }
        .padding(30)
        .frame(width: 600, height: 450)
        .sheet(isPresented: $showSettings) {
            SettingsView()
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

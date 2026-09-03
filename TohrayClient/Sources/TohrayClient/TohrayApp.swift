import SwiftUI

@main
struct TohrayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 450)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .printItem) {
                Button("Preview") {
                    NotificationCenter.default.post(name: .toggleMarkdownPreview, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Divider()

                Button("Insert Image…") {
                    NotificationCenter.default.post(name: .insertImage, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
            }
        }
    }
}

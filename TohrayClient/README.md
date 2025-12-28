# Tohray Swift Client

A native macOS GUI client for posting to your Tohray blog.

## Features

- 🔐 **Secure credential storage** using macOS Keychain
- 🎨 **Native SwiftUI interface**
- ✅ **Automatic session & CSRF handling**
- 🚀 **Quick posting** with auto-generated slugs
- 🔄 **Connection testing** before posting

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Installation

### Option 1: Open in Xcode

1. Open `Package.swift` in Xcode
2. Select **My Mac** as the run destination
3. Click **Run** (⌘R)

### Option 2: Build from Command Line

```bash
cd TohrayClient
swift build
swift run
```

### Option 3: Create Standalone App

1. Open Package.swift in Xcode
2. Product → Archive
3. Distribute App → Copy App

## Usage

### First Time Setup

1. Launch the app
2. Click the **gear icon** to open Settings
3. Enter your credentials:
   - **Tohray URL**: `http://localhost:8080` or your server URL
   - **Username**: Your tohray username
   - **Password**: Your tohray password
4. Click **Test Connection** to verify
5. Click **Save** (credentials are stored securely in Keychain)

### Posting

1. Enter your post content (markdown supported)
2. Optionally enter a custom slug (auto-generated if empty)
3. Click **Post**
4. The app will show the URL of your new post

## Architecture

```
TohrayClient/
├── TohrayApp.swift          # App entry point
├── ContentView.swift        # Main UI (post form + settings)
├── PostViewModel.swift      # View models for UI state
├── KeychainHelper.swift     # macOS Keychain integration
└── TohrayAPIClient.swift    # API client (login, CSRF, posting)
```

## Security

- All credentials are stored in **macOS Keychain** (not plain text files)
- Uses the system's secure storage with encryption
- Credentials are only accessible to this app
- Session cookies are kept in memory only

## How It Works

1. **Login**: Fetches login page → extracts CSRF token → submits credentials → stores session cookie
2. **Post**: Fetches write page → extracts CSRF token → submits post with session cookie
3. **Keychain**: Uses `Security.framework` to securely store URL, username, and password

## Troubleshooting

### "No credentials found"
- Open Settings (gear icon) and enter your credentials
- Make sure to click Save

### "Connection failed"
- Verify your Tohray instance is running
- Check the URL is correct (include `http://` or `https://`)
- Test your credentials by logging in via web browser first

### Build errors
- Make sure you're using Xcode 15.0+ and macOS 13.0+
- Clean build folder: Product → Clean Build Folder (⇧⌘K)

## Future Enhancements

- [ ] View recent posts
- [ ] Edit existing posts
- [ ] Dark mode support
- [ ] Keyboard shortcuts
- [ ] Menu bar app option
- [ ] Export/import settings

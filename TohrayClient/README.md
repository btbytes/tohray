# Tohray Swift Client

A native macOS GUI client for posting to your Tohray blog.

## Features

- 🔐 **Secure credential storage** using macOS Keychain (one consolidated entry)
- 🎨 **Native SwiftUI interface**
- ✅ **Automatic session & CSRF handling**
- 🚀 **Quick posting** with auto-generated slugs
- 🖼️ **Image upload** (⌘I) to any S3-compatible bucket, inserting a markdown image link at the cursor
- 🔄 **Connection + S3 upload testing** before saving

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

1. Open `Package.swift` in Xcode
2. Product → Archive
3. Distribute App → Copy App

## Usage

### First Time Setup

1. Launch the app
2. Click the **gear icon** to open Settings
3. In the **Tohray** tab, enter your credentials:
   - **Tohray URL**: `http://localhost:8080` or your server URL
   - **Username**: Your tohray username
   - **Password**: Your tohray password
4. Optionally click **Test Connection** to verify
5. Click **Save** (credentials are stored securely in Keychain)

### Image Storage (S3 / Cloudflare R2)

To enable pasting/uploading images directly from the editor, configure the
**Image Storage** tab in Settings:

- **Provider**: `Cloudflare`, `AWS`, `MinIO`, or `GenericS3`
- **Access Key ID** / **Secret Access Key**: Your bucket credentials
- **Session Token** (optional): For AWS temporary credentials
- **Endpoint**: e.g. `https://<account-id>.r2.cloudflarestorage.com` or `https://s3.amazonaws.com`
- **ACL**: `private`, `public-read`, or a custom value
- **Bucket**: The bucket name
- **Root Directory** (prefix): Objects are stored under this prefix, e.g. `/appname/`
- **Public URL** (optional): Your public/CDN URL; falls back to the endpoint if empty

Click **Test S3 Upload** to verify the configuration with a small test object.

### Inserting an Image (⌘I)

1. Place the cursor where you want the image in the editor
2. Press **⌘I** (or Edit → **Insert Image…**)
3. Choose **Paste** (grab from clipboard) or **File** (pick an image)
4. Adjust the **image name** (pre-filled with the original filename, or a random
   name for pasted images)
5. Optionally add an **image description**, used as the markdown alt text and image title
6. Click **Upload & Insert**

A markdown image link is inserted at the cursor, e.g.:

```markdown
![A diagram of the network](https://cdn.example.com/appname/diagram.png "A diagram of the network")
```

### Posting

1. Enter your post content (markdown supported)
2. Optionally enter a custom slug (auto-generated if empty)
3. Click **Post** (⌘↩)
4. The app will show the URL of your new post

## Architecture

```
TohrayClient/
├── TohrayApp.swift          # App entry point & menu commands (⌘E, ⌘P, ⌘I)
├── ContentView.swift        # Main UI (editor, tabbed settings, image sheet)
├── PostViewModel.swift      # View models for UI state
├── MarkdownEditor.swift     # NSTextView markdown editor (+ cursor insertion)
├── MarkdownHighlighter.swift# In-place markdown syntax highlighting
├── MarkdownPreview.swift    # WKWebView HTML preview
├── TohrayAPIClient.swift    # API client (login, CSRF, posting)
├── KeychainHelper.swift     # macOS Keychain integration (single settings blob)
├── S3Config.swift           # S3-compatible storage configuration model
├── S3Uploader.swift         # AWS Signature V4 uploader (R2/AWS/MinIO)
└── ImageUploadSheet.swift   # ⌘I clipboard/file paste & upload UI
```

## Security

- All credentials are stored in **macOS Keychain** (not plain text files)
- Uses the system's secure storage with encryption
- All settings are stored as a **single Keychain entry** under the service
  `dev.fly.tohray`, so macOS only asks for permission once instead of once per field
- S3 secret keys are stored in the Keychain, never in plain text
- Session cookies are kept in memory only

## How It Works

1. **Login**: Fetches login page → extracts CSRF token → submits credentials → stores session cookie
2. **Post**: Fetches write page → extracts CSRF token → submits post with session cookie
3. **Image upload**: Objects are signed with AWS Signature V4 and uploaded with
   an HTTP PUT directly to your S3-compatible endpoint (no server round-trip),
   then inserted as a markdown link
4. **Keychain**: Uses `Security.framework` to securely store all settings as one JSON blob

## Troubleshooting

### "No credentials found"
- Open Settings (gear icon) and enter your credentials
- Make sure to click Save

### "Connection failed"
- Verify your Tohray instance is running
- Check the URL is correct (include `http://` or `https://`)
- Test your credentials by logging in via web browser first

### "S3 upload failed"
- Verify the **Image Storage** tab is filled in and click **Test S3 Upload**
- Check the endpoint and region for your provider (Cloudflare R2 uses `auto`)
- Ensure your ACL matches what your bucket allows

### Build errors
- Make sure you're using Xcode 15.0+ and macOS 13.0+
- Clean build folder: Product → Clean Build Folder (⇧⌘K)

## Future Enhancements

- [ ] View recent posts
- [ ] Edit existing posts
- [ ] Dark mode support
- [ ] Menu bar app option
- [ ] Export/import settings

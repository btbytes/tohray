# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tohray is a microblogging application written in Nim, inspired by Linus Lee's Stream. It's a lightweight, single-binary application designed for capturing a stream of thoughts with markdown support.

## Technology Stack

- **Language**: Nim (requires >= 2.0.8)
- **Web Framework**: Prologue (web framework) with Karax (HTML DSL)
- **Database**: SQLite with FTS5 full-text search
- **CSS**: Terminal.css
- **Deployment**: Designed for fly.io, but runs locally or in Docker

## Development Commands

### Build and Run
```bash
# Development build with debug symbols
make
# or
nim -d:debug c tohray.nim

# Production/release build
nim -d:release compile tohray.nim

# Run the application
./tohray
```

The app runs on port 8080 by default (configurable in `consts.nim`): http://localhost:8080

### Dependencies
```bash
# Install dependencies
nimble install -y --depsOnly
```

### Database Setup
```bash
# Populate with test data (lorem ipsum entries)
sqlite3 tohray.db < test.sql
```

## Configuration System

**CRITICAL**: Tohray compiles configuration directly into the binary - there are no runtime config files or environment variables for secrets.

### Local Development
1. Copy `example-consts.nim` to `consts.nim`
2. Set all required values in `consts.nim`:
   - `dbPath`: Path to SQLite database (e.g., `"./tohray.db"`)
   - `inviteCode`: Registration invite code
   - `secretKey`: Session secret key
   - `siteUrl`: Full site URL with trailing slash
   - `siteName`: Site name displayed in header
   - `siteTitle`: Site tagline/subtitle
   - `port`: Server port (default 8080)

### Deployment
For fly.io deployment, the `Dockerfile` copies `fly-consts.nim` to `consts.nim` before compilation, allowing separate local and production configs.

## Architecture

### Application Structure

**Entry Point**: `tohray.nim`
- Initializes database via `initdb.nim`
- Sets up Prologue app with middleware (sessions, CSRF, static files)
- Binds socket and starts server

**Routing**: `urls.nim`
- Defines all URL patterns using Prologue's pattern matching
- Maps routes to view handlers in `views.nim`

**Views**: `views.nim` (intentionally monolithic - "fits into myhead perfectly fine")
- All view handlers and HTML generation
- Uses Karax DSL for type-safe HTML generation
- Handles user authentication, CRUD operations, export, calendar, RSS

**Database**: `initdb.nim`
- Schema initialization with inline SQL
- Creates tables: `users`, `post`, `post_fts` (FTS5 virtual table)
- Sets up triggers to maintain FTS index automatically

### Key Design Decisions

1. **Monolithic views.nim**: Intentionally kept in one file for simplicity. Don't split it up unless truly necessary.

2. **Compiled secrets**: Configuration is compiled into the binary. This is deliberate for this hobby project - no config files or environment variable loading for secrets.

3. **FTS5 Search**: Full-text search is implemented using SQLite's FTS5 with automatic triggers to keep the index synchronized.

4. **Karax HTML DSL**: HTML is generated using Karax's type-safe DSL with procs like `buildHtml()`, avoiding string templates.

5. **Session-based auth**: Uses Prologue's memory sessions with PBKDF2 password hashing.

### Database Schema

**users table**:
- `id`, `fullname`, `username` (unique), `password` (hashed)

**post table**:
- `id`, `author_id`, `created` (timestamp), `slug` (unique, defaults to epoch), `content` (markdown)

**post_fts virtual table**:
- FTS5 index on post content
- Automatically synced via triggers

### URL Routes

- `/` - Homepage (stream view with pagination, search, month filtering)
- `/login`, `/logout`, `/register` - Authentication
- `/write` - Create new post
- `/edit/{slug}` - Edit existing post
- `/delete/{slug}` - Delete post
- `/export` - Export all posts (JSON default, `?format=md` for markdown)
- `/calendar` - Calendar view showing post counts by month/year
- `/rss` - RSS feed
- `/{slug}` - View single post (supports `?format=md` for plain markdown)

## Common Patterns

### Database Access
Always use `defer: db.close()` after opening connections:
```nim
let db = open(consts.dbPath, "", "", "")
defer: db.close()
```

### HTML Generation
Views use Karax DSL with the `baseLayout` proc for consistent layout:
```nim
proc someView*(ctx: Context) {.async.} =
  let vnode = buildHtml(tdiv()):
    # ... content ...
  result = baseLayout(ctx, "Page Title", vnode)
```

Note: Use `tdiv()` instead of `div()` (reserved keyword in Nim).

### Session Management
Check authentication:
```nim
if ctx.session.getOrDefault("userId", "").len != 0:
  # user is logged in
```

### CSRF Protection
All forms must include CSRF token:
```nim
let csrfToken = ctx.generateToken()
input(type = "hidden", name = "CSRFToken", value = csrfToken)
```

## Known Issues / TODO

From README:
- Search is currently broken
- "Next Page" and "Previous Page" navigation needs fixing (pagination only goes forward)
- `/import` endpoint not yet implemented

## Deployment Notes

### fly.io
- Volume required for database: `fly volumes create db -r [region]`
- Volume mount point: `/mnt/db` (configured in `fly.toml`)
- Uses multi-stage Docker build with nimlang/nim base image
- Binary runs directly (no shell wrapper needed)

### Docker
The Dockerfile uses a multi-stage build:
1. Base `nimlang/nim` image
2. Install dependencies with `nimble install -y --depsOnly`
3. Copy `fly-consts.nim` to `consts.nim` (for cloud deployment)
4. Compile with release flag
5. Run binary directly via ENTRYPOINT

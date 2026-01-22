# Mail Summary

AI-powered email assistant for macOS that reads your Mail.app inbox, categorizes emails intelligently, and provides actionable summaries.

![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.0--beta-yellow)

## Features

### 🤖 AI-Powered Email Categorization
- Automatically categorizes emails into 8 smart categories:
  - 💰 Bills - Invoices, payment reminders
  - 📦 Orders - Shopping confirmations, shipping updates
  - 💼 Work - Professional correspondence
  - 👤 Personal - Friends, family
  - 📢 Marketing - Promotions, sales
  - 📰 Newsletters - Subscriptions, digests
  - 🌐 Social - Facebook, Twitter, LinkedIn notifications
  - 📬 Other - Everything else

### 📊 TopGUI-Style Dashboard
- Glass card interface with visual category counts
- Color-coded by priority (Red = Urgent, Green = Safe)
- Unread indicators per category
- At-a-glance email status

### 🎯 Smart Features (Planned)
- **Priority Scoring (1-10):** AI scores email importance
- **Action Extraction:** Identifies deadlines, meetings, tasks
- **Sender Reputation:** Learns who you read vs delete
- **Smart Replies:** AI-suggested quick responses
- **Bulk Actions:** Delete marketing, mark all read

### 📧 Email Management
- View emails by category
- Mark as read
- Delete emails
- Bulk category actions
- AI summary of inbox

### 🔔 Menu Bar App
- Unread count badge
- Quick dropdown menu
- Scan on demand
- Background monitoring (planned)

---

## Current Status

**Version:** 1.0-beta (Foundation Complete)
**Status:** ✅ Builds and runs with sample data
**Next:** Implement real Mail.app database parsing

### What Works Now:
✅ Dashboard with glass card categories
✅ Sample email display
✅ AI categorization (rule-based)
✅ Category counts and stats
✅ Bulk delete by category
✅ Mark all as read
✅ Menu bar app
✅ TopGUI-inspired design

### Coming Soon:
⚠️ Real Mail.app mailbox parsing
⚠️ SQLite Envelope Index reading
⚠️ True AI categorization (Ollama/MLX)
⚠️ Priority scoring (1-10)
⚠️ Action extraction
⚠️ Sender reputation learning
⚠️ Smart reply suggestions
⚠️ Email list/detail views

---

## Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building)
- Mail.app with configured accounts

### Building from Source

```bash
cd "/Volumes/Data/xcode/Mail Summary"
xcodebuild -scheme "Mail Summary" -configuration Release build

# Install
cp -R build/Release/Mail\ Summary.app ~/Applications/
open ~/Applications/Mail\ Summary.app
```

---

## Architecture

### Core Components:

**MailEngine** - Orchestrates email loading, categorization, stats
**MailParser** - Reads Mail.app's Envelope Index SQLite database
**AICategorizationEngine** - AI-powered email analysis
**AIBackendManager** - Unified AI backend (Ollama, MLX, TinyLLM, etc.)
**ContentView** - Main dashboard with glass cards
**MenuBarView** - Menu bar dropdown

### Data Flow:

```
Mail.app Mailbox (~/Library/Mail/)
    ↓
MailParser (SQLite + .emlx)
    ↓
MailEngine (orchestration)
    ↓
AICategorizationEngine (AI analysis)
    ↓
Categories, Priority, Actions
    ↓
Dashboard UI (glass cards)
```

---

## AI Backend Support

Mail Summary supports 5 AI backends (like TopGUI/GTNW):

- **Ollama** - Fast GPU-accelerated (localhost:11434)
- **MLX Toolkit** - Apple Silicon optimized
- **TinyLLM** by Jason Cox - Lightweight Docker
- **TinyChat** by Jason Cox - Fast chatbot
- **OpenWebUI** - Self-hosted platform

All processing is **100% local** - no email content sent to cloud.

---

## Development Roadmap

### Phase 1: Foundation (Complete ✅)
- [x] Core architecture
- [x] Sample data
- [x] Dashboard UI
- [x] Menu bar app
- [x] Build system

### Phase 2: Mail Integration (Next)
- [ ] SQLite database parsing
- [ ] .emlx file reading
- [ ] Multiple account support
- [ ] Real-time monitoring (FSEvents)

### Phase 3: AI Enhancement
- [ ] True AI categorization (not rules)
- [ ] Priority scoring with AI
- [ ] Action extraction (deadlines/meetings)
- [ ] Smart reply generation

### Phase 4: Advanced Features
- [ ] Sender reputation DB
- [ ] Email list/detail views
- [ ] Bulk action confirmations
- [ ] Search and filtering
- [ ] Settings UI

### Phase 5: Polish
- [ ] App icon
- [ ] Notifications
- [ ] Performance optimization
- [ ] Error handling
- [ ] User preferences

---

## Technical Details

### Mail.app Database Location:
```
~/Library/Mail/V10/MailData/Envelope Index  (SQLite)
~/Library/Mail/V10/[Account]/Messages/*.emlx  (Email files)
```

### Database Schema:
```sql
messages (ROWID, subject, sender, date_received, mailbox)
addresses (address, comment, ROWID)
mailboxes (url, name)
```

### Privacy & Security:
- **Sandboxed app** with file access entitlements
- **Local AI only** - no cloud services
- **Read-only by default** - explicit actions to modify
- **No data collection** - everything stays on device

---

## Contributing

This is a personal project by Jordan Koch. Contributions welcome via pull requests.

---

## License

MIT License - See LICENSE file

---

## Acknowledgments

- Design inspired by TopGUI
- AI architecture from GTNW
- Built with SwiftUI and modern macOS APIs

---

## Author

**Jordan Koch**
- GitHub: [@kochj23](https://github.com/kochj23)

---

## Support

If you encounter issues:
1. Check Mail.app has configured accounts
2. Verify macOS 13.0+
3. Check file permissions for ~/Library/Mail/
4. Open issue on GitHub

---

**Status:** Working foundation, ready for Mail.app integration. Builds and runs with sample data.

**Created:** January 22, 2026

# Mail Summary - AI-Powered Email Assistant

**Created:** January 22, 2026
**Platform:** macOS 13.0+
**Language:** Swift + SwiftUI

---

## Project Overview

Mail Summary is an AI-powered email management assistant that reads your macOS Mail.app inbox, categorizes emails intelligently, and provides actionable summaries.

---

## Architecture

### Core Components:

**1. MailboxMonitor** (Real-time file system monitoring)
- Watches ~/Library/Mail/ for changes
- Detects new emails immediately
- Triggers AI processing

**2. MailParser** (Mail.app database reader)
- Parses Envelope Index SQLite database
- Extracts: subject, sender, date, body preview
- Reads .emlx files for full content

**3. AICategorizationEngine** (AI-powered analysis)
- Uses AIBackendManager (Ollama/MLX/TinyLLM/etc.)
- Categorizes: Marketing, Personal, Work, Bills, Orders, Social, Newsletters, Spam
- Priority scoring (1-10)
- Action extraction (deadlines, meetings)
- Sender reputation learning

**4. Dashboard (TopGUI-style UI)
- Glass card per category with counts
- AI-generated summary of important emails
- Heat map colors (green = safe, red = urgent)
- Category-based quick actions

**5. Email Viewer/Controller**
- View emails in app
- Mark as read
- Delete (with confirmation)
- Smart reply suggestions

---

## Technical Specifications

### Mail.app Database Access:

**Location:** `~/Library/Mail/V10/` (macOS Sonoma+)

**Files to Parse:**
- `MailData/Envelope Index` - SQLite database with metadata
- `*/Messages/*.emlx` - Individual email files (XML format)
- `Accounts.plist` - Account configuration

**Database Schema:**
```sql
-- Main tables:
messages (ROWID, subject, sender, date_received, date_sent, mailbox)
addresses (address, comment, ROWID)
mailboxes (url, name)
```

### AI Integration:

**Backend:** AIBackendManager (same as TopGUI/GTNW)
- Ollama (localhost:11434)
- MLX Toolkit (Python)
- TinyLLM (localhost:8000)
- TinyChat
- OpenWebUI (localhost:8080)

**AI Prompts:**

**Categorization:**
```
Subject: [subject]
From: [sender]
Preview: [first 500 chars]

Categorize this email into ONE of:
Marketing, Personal, Work, Bills, Orders, Social, Newsletters, Spam, Other

Return JSON: {"category": "Marketing", "confidence": 0.95}
```

**Priority Scoring:**
```
Analyze this email and score importance 1-10:
- 10: Urgent/Critical (bills due, meeting today)
- 7-9: Important (work tasks, personal matters)
- 4-6: Normal (regular correspondence)
- 1-3: Low priority (newsletters, marketing)

Return JSON: {"priority": 8, "reason": "Bill due Friday"}
```

**Action Extraction:**
```
Extract actionable items:
- Deadlines (pay by, respond by, due date)
- Meetings (date, time, location)
- Tasks (action verbs, requests)

Return JSON: {
  "actions": [
    {"type": "deadline", "text": "Pay bill by Jan 25", "date": "2026-01-25"},
    {"type": "meeting", "text": "Team meeting Tuesday 3pm", "date": "2026-01-23T15:00"}
  ]
}
```

---

## UI Design (TopGUI-Inspired)

### Main Dashboard:

```
┌─────────────────────────────────────────────────────┐
│ 📧 MAIL SUMMARY              [🧠 Ollama ✓][Scan Now]│
├─────────────────────────────────────────────────────┤
│  AI SUMMARY                                         │
│  ┌───────────────────────────────────────────────┐ │
│  │ 🤖 You have 3 bills due this week, 5 important│ │
│  │ work emails, and 12 marketing emails to       │ │
│  │ delete. Most urgent: Electric bill due Friday.│ │
│  └───────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│  CATEGORIES (Glass Cards)                           │
│  ┌─────────┬─────────┬─────────┬─────────┐        │
│  │ 💰 Bills│ 📦 Order│ 💼 Work │ 👤 Person│        │
│  │    3    │    2    │    5    │    4     │        │
│  │  🔴 Urg │  🟢 Safe│ 🟡 Attn │ 🟢 Safe  │        │
│  └─────────┴─────────┴─────────┴─────────┘        │
│  ┌─────────┬─────────┬─────────┬─────────┐        │
│  │ 📢 Mktg │ 📰 News │ 🌐 Social│ 📬 Other│        │
│  │   25    │    8    │    6     │    2     │        │
│  │  🟠 Low │ 🟢 Safe │ 🟢 Safe  │ 🟢 Safe  │        │
│  └─────────┴─────────┴─────────┴─────────┘        │
├─────────────────────────────────────────────────────┤
│  QUICK ACTIONS                                      │
│  [🗑️ Delete 25 Marketing] [✓ Mark All Read]       │
│  [📋 View Actions (8)]     [⚙️ Settings]           │
└─────────────────────────────────────────────────────┘
```

### Email List View (when clicking category):

```
┌─────────────────────────────────────────────────────┐
│ 📢 MARKETING EMAILS (25)                   [Delete All]│
├─────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────┐ │
│ │ 🏪 Amazon     "Your order has shipped"    ⭐ 7  │ │
│ │ Jan 22, 2pm   Order #123-456               [Keep]│ │
│ │ Action: Track package                    [Delete]│ │
│ └─────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 📧 Newsletter "Weekly tech news"           ⭐ 3  │ │
│ │ Jan 22, 1pm   Unsubscribe available?     [Keep]  │ │
│ │ Summary: Product launches, AI news       [Delete]│ │
│ └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## Key Features

### 1. AI Categorization
- Analyzes subject, sender, body preview
- Creates 8-10 categories automatically
- Confidence scores
- Learns from your keep/delete decisions

### 2. Priority Scoring (1-10)
- 10: Critical (bills due today)
- 7-9: Important (work, personal urgent)
- 4-6: Normal
- 1-3: Low (marketing, newsletters)
- Color-coded: Red > Amber > Green

### 3. Action Extraction
- Deadlines: "Pay by Jan 25"
- Meetings: "Zoom call Tuesday 3pm"
- Tasks: "Please review attached"
- Creates actionable todo list

### 4. Sender Reputation
- Learns who you read vs delete
- Tracks: always read, sometimes read, always delete
- Adjusts priority based on sender history
- Stored locally (privacy)

### 5. Smart Replies
- AI suggests responses: "Thanks, got it", "Will review", "Not interested"
- One-click send
- Learns your writing style over time

### 6. Bulk Actions with AI Confirmation
- AI: "Found 25 marketing emails. Keep 2 Amazon orders, delete 23?"
- Shows list for review
- Approve or adjust
- Safe bulk deletion

---

## Implementation Plan

### Phase 1: Mail Parsing (2-3 days)
- Mailbox monitor (FSEvents)
- SQLite database reader
- .emlx file parser
- Account detection

### Phase 2: AI Engine (2-3 days)
- Copy AIBackendManager from TopGUI
- Categorization prompts
- Priority scoring
- Action extraction
- Sender reputation DB

### Phase 3: Dashboard UI (3-4 days)
- TopGUI glass card design system
- Category cards with circular gauges
- AI summary display
- Quick actions panel

### Phase 4: Email Viewer (2-3 days)
- Email list views per category
- Mark as read functionality
- Delete with confirmation
- Smart reply UI

### Phase 5: Menu Bar App (1-2 days)
- Menu bar indicator (unread count)
- Quick dropdown menu
- Background monitoring
- Notification support

### Total: 10-15 days implementation

---

## Security & Privacy

- **Local only** - All AI processing local (Ollama/MLX)
- **No cloud** - Never sends email content to cloud
- **Read-only by default** - Requires explicit action to delete
- **Sandboxed** - macOS sandbox with file access entitlement
- **Encrypted DB** - Sender reputation stored encrypted

---

## Technical Stack

- **Language:** Swift 5.9+
- **Framework:** SwiftUI
- **Min OS:** macOS 13.0 (Ventura)
- **Database:** SQLite (Mail.app's format)
- **AI:** AIBackendManager (5 backend support)
- **File Monitoring:** FSEvents API
- **Design:** TopGUI glass card system

---

## Questions Confirmed:

✅ Mail access: Direct mailbox file access
✅ UI style: TopGUI glass cards
✅ Categories: AI-determined smart categories
✅ Bulk actions: Smart filters with confirmation
✅ Monitoring: Real-time
✅ Dashboard: Category cards + AI summary
✅ Integration: Standalone viewer/controller
✅ AI features: All 4 (priority, actions, reputation, replies)

---

**Ready to implement! This will be the most advanced AI-powered email assistant for macOS.**

Shall I proceed with creating the app?

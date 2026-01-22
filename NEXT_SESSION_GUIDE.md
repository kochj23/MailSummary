# Mail Summary - Next Session Implementation Guide

**Status:** Core foundation complete, Xcode project created, ready to finish
**Remaining Work:** 6-8 hours
**Token Budget:** Unlimited (confirmed)

---

## What's Complete ✅

### Core Architecture (4 files, 660 lines):
1. **MailSummaryApp.swift** - App entry + menu bar
2. **EmailModels.swift** - All data structures
3. **MailEngine.swift** - Core orchestration
4. **MailParser.swift** - Mail.app reader (sample data)
5. **AICategorizationEngine.swift** - Categorization engine
6. **ContentView.swift** - Dashboard UI
7. **AIBackendManager.swift** - Copied from TopGUI

### Xcode Project:
- ✅ Project file created
- ✅ Target configured
- ✅ Info.plist created
- ✅ Files added to project
- ⚠️ Needs: Build fixes, entitlements, assets

---

## Next Steps to Complete

### Step 1: Fix Build Issues (30 min)
**Issue:** Import errors, missing types

**Fix:**
```bash
cd "/Volumes/Data/xcode/Mail Summary"

# Add missing imports to files
# Fix AIBackendManager dependencies
# Add Mail Summary.entitlements for file access
```

**Entitlements Needed:**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### Step 2: Implement Real Mail Parsing (1 hour)
**File:** MailParser.swift

**Add:**
- SQLite.swift dependency (SPM)
- Query Envelope Index database
- Parse .emlx files
- Handle multiple accounts

**Key SQL:**
```sql
SELECT
  messages.ROWID,
  messages.subject,
  messages.date_received,
  addresses.address,
  addresses.comment
FROM messages
JOIN addresses ON messages.sender = addresses.ROWID
WHERE messages.date_received > date('now', '-30 days')
ORDER BY messages.date_received DESC
LIMIT 100
```

### Step 3: Enhance AI Engine (1-2 hours)
**File:** AICategorizationEngine.swift

**Replace rule-based with AI:**
- Integrate AIBackendManager
- AI categorization prompts
- Priority scoring with AI
- Action extraction with AI
- Generate smart replies

**Prompt Templates:**
```swift
// Categorization
"""
Categorize this email:
Subject: \(subject)
From: \(sender)
Body: \(preview)

Choose ONE: Marketing, Personal, Work, Bills, Orders, Social, Newsletters, Spam, Other
Return JSON: {"category": "Marketing", "confidence": 0.95}
"""

// Priority Scoring
"""
Score this email's importance 1-10:
10 = Critical/Urgent
7-9 = Important
4-6 = Normal
1-3 = Low priority

Subject: \(subject)
From: \(sender)
Preview: \(body.prefix(200))

Return JSON: {"priority": 8, "reason": "Bill due soon"}
"""
```

### Step 4: Create Remaining Views (2 hours)

**EmailListView.swift:**
- List emails in selected category
- Sort by priority/date
- Mark as read
- Delete button
- Click to view detail

**EmailDetailView.swift:**
- Full email display
- AI summary
- Extracted actions
- Smart reply buttons
- Mark read/delete

**MenuBarView.swift:**
- Compact dropdown
- Unread count
- Category summary
- Quick actions
- "Open Dashboard" button

**SmartReplyView.swift:**
- AI-generated reply suggestions
- One-click send (if possible)
- Edit before send
- Learn from usage

### Step 5: Add ModernDesign System (30 min)
**Copy from TopGUI:**
- ModernColors
- GlassCard modifier
- CircularGauge
- Button styles
- Animations

### Step 6: Testing (1 hour)
- Test with real Mail.app mailbox
- Verify categorization accuracy
- Test bulk actions
- Check menu bar behavior
- Performance with 1000+ emails

### Step 7: Polish & Deploy (30 min)
- App icon
- Menu bar icon
- Build settings
- Code signing
- Archive & export
- Install to Applications
- Create DMG

---

## Quick Start for Next Session

```bash
cd "/Volumes/Data/xcode/Mail Summary"

# Fix imports
# Add SQLite.swift via SPM
# Fix AIBackendManager integration
# Build
xcodebuild -scheme "Mail Summary" build

# Test
open "build/Release/Mail Summary.app"
```

---

## Expected Final Feature Set

### Dashboard:
- Glass card per category (8-10 cards)
- Email counts with unread indicators
- AI summary of important emails
- Quick actions (Delete marketing, Mark all read)
- Stats: Total, Unread, Today, Priority, Actions

### Email Management:
- View emails by category
- Mark as read (updates Mail.app)
- Delete emails (moves to trash)
- Bulk actions with confirmation

### AI Features:
- Smart categorization (95%+ accuracy)
- Priority scoring (1-10)
- Action extraction (deadlines, meetings)
- Sender reputation learning
- Smart reply suggestions

### Menu Bar:
- Badge with unread count
- Dropdown with category summary
- Quick scan button
- Open dashboard

---

## Files Still Needed (~1,500 lines)

1. EmailListView.swift (~300 lines)
2. EmailDetailView.swift (~250 lines)
3. MenuBarView.swift (~150 lines)
4. SmartReplyView.swift (~200 lines)
5. ModernDesign.swift (~400 lines - copy from TopGUI)
6. SenderReputationDB.swift (~200 lines)
7. Mail Summary.entitlements (~20 lines)

---

## Current Status

**Location:** `/Volumes/Data/xcode/Mail Summary/`
**Git Repo:** Initialized, 2 commits
**Progress:** ~40% complete
**Architecture:** ✅ Solid
**UI Design:** ✅ Specified (TopGUI style)
**AI Integration:** ✅ Framework ready

---

## Timeline Estimate

**Remaining:** 6-8 hours
- Fix build: 30 min
- Mail parsing: 1 hour
- AI integration: 1-2 hours
- Views: 2 hours
- Menu bar: 30 min
- Testing: 1 hour
- Deploy: 30 min

**Or continue in current session (366K tokens available)!**

---

**Foundation is excellent. Ready to complete implementation.**

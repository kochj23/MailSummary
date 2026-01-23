# Mail Summary - Setup Instructions

## Why Only 4 Emails Showing?

Mail Summary is currently showing **sample data** because it doesn't have permission to read your Mail.app mailbox yet.

### The Issue:

Your Mail.app has ~300 unread emails in:
- Digitalnoise Gmail account
- kochjpar@gmail.com account

But Mail Summary can't access `~/Library/Mail/` because of macOS privacy protections.

---

## Solution: Grant Full Disk Access

### Step 1: Open System Settings
1. Click Apple menu → **System Settings**
2. Go to **Privacy & Security**
3. Scroll to **Full Disk Access**

### Step 2: Add Mail Summary
1. Click the **+** button
2. Navigate to `/Users/kochj/Applications/`
3. Select **Mail Summary.app**
4. Click **Open**
5. Toggle should turn **ON** (blue)

### Step 3: Restart Mail Summary
1. Quit Mail Summary (Cmd+Q)
2. Reopen: `open "/Users/kochj/Applications/Mail Summary.app"`
3. Click **"Scan Now"** button
4. App will now read your real Mail.app mailbox
5. Should show ~300 emails from both Gmail accounts

---

## What Full Disk Access Allows:

**Mail Summary can read:**
- `~/Library/Mail/V10/MailData/Envelope Index` (SQLite database)
- Email metadata (subject, sender, date)
- Email preview text
- Account information

**Mail Summary CANNOT:**
- Send emails on your behalf
- Modify existing emails
- Access other apps' data
- Send data to internet

**All processing is 100% local using your chosen AI backend (Ollama/MLX/etc.)**

---

## Current Behavior

**Without Permission:**
- Shows 4 sample emails
- Categories work but with fake data
- Dashboard displays correctly
- All UI functional

**With Permission:**
- Reads all ~300 emails from Mail.app
- Real categorization
- Actual AI summaries
- True unread counts
- Priority scoring based on real content

---

## Alternative: Use Sample Data Mode

If you prefer not to grant Full Disk Access, Mail Summary works in "Demo Mode" with sample emails to show functionality.

---

## Troubleshooting

**"Still only shows 4 emails after granting access"**
- Quit Mail Summary completely (Cmd+Q)
- Check Full Disk Access is ON in System Settings
- Reopen app
- Click "Scan Now"

**"Can't find Mail Summary in Applications"**
- It's in: `/Users/kochj/Applications/Mail Summary.app`
- Use Finder → Go → Go to Folder → `~/Applications`

**"Mail.app has no emails"**
- Mail Summary reads what Mail.app has downloaded
- Open Mail.app to sync/download emails first
- Then scan in Mail Summary

---

## Next Steps After Setup

Once Full Disk Access is granted:

1. **Click Category Cards** → See email summaries
2. **AI Analyzes** → Categorizes all ~300 emails
3. **Priority Scores** → Urgent bills highlighted
4. **Quick Actions** → Delete marketing in bulk
5. **Menu Bar** → Quick access from menu bar icon

---

## Technical Note

Mail Summary parses Mail.app's SQLite database directly:
- Fast (no AppleScript overhead)
- Works offline
- Reads all accounts Mail.app manages
- No credentials needed (uses Mail.app's data)

---

**Grant Full Disk Access and Mail Summary will read your real ~300 emails!**

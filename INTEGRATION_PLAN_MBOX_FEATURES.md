# Integration Plan: MBox Explorer Features into Mail Summary

**Created:** January 30, 2026
**Author:** Jordan Koch
**Version:** 1.0

---

## Executive Summary

This document outlines the plan to integrate 12 advanced features from MBox Explorer into Mail Summary v2.2+. Mail Summary already has sophisticated AI capabilities (8 AI engines, multi-model ensemble, 90% autonomous handling), so the focus is on **unique visualization, productivity, and system integration features** that complement existing functionality.

---

## Feature Assessment Matrix

| MBox Explorer Feature | Already in Mail Summary? | Integration Priority | Notes |
|----------------------|-------------------------|---------------------|-------|
| Search History | Partial (SearchFilterManager) | HIGH | Add persistence layer |
| Email Statistics Dashboard | Yes (AnalyticsManager) | MEDIUM | Enhance with Charts |
| Spotlight Integration | No | HIGH | New feature |
| Quick Look Preview | No | HIGH | New feature |
| Batch Operations Toolbar | Partial (basic actions) | HIGH | Enhance UI |
| Sentiment Dashboard | Yes (RelationshipIntelligence) | LOW | Already sophisticated |
| Smart Reply Suggestions | Yes (SmartReplyEngine) | LOW | Already better |
| Meeting/Event Extractor | Yes (MeetingAutopilotEngine) | LOW | Already implemented |
| Notification Center | Partial (rule notifications) | MEDIUM | Enhance with reminders |
| Email Diff View | No | MEDIUM | New feature |
| Contact Exporter | No | MEDIUM | New feature |

---

## Phase 1: High Priority (Week 1-2)

### 1.1 Search History with Persistence

**Source:** `MBox Explorer/Models/SearchHistory.swift`

**Integration Steps:**
1. Copy `SearchHistory.swift` to `Mail Summary/Managers/`
2. Rename to `SearchHistoryManager.swift`
3. Integrate with existing `SearchFilterManager.swift`
4. Add UI elements to `SearchView.swift`:
   - Recent searches list
   - Saved searches with names
   - Quick access buttons
5. Persist to UserDefaults (already implemented in MBox version)

**Files to Create/Modify:**
- `Managers/SearchHistoryManager.swift` (new)
- `Views/SearchView.swift` (modify)
- `Models/SearchModels.swift` (add SearchEntry model)

**Estimated Effort:** 4-6 hours

---

### 1.2 Spotlight Integration

**Source:** `MBox Explorer/Services/SpotlightIntegration.swift`

**Integration Steps:**
1. Copy `SpotlightIntegration.swift` to `Mail Summary/Services/`
2. Adapt for Mail Summary's Email model
3. Index emails automatically after processing
4. Add settings toggle in `SettingsView.swift`
5. Handle deep links from Spotlight searches

**Files to Create/Modify:**
- `Services/SpotlightIntegration.swift` (new)
- `Views/SettingsView.swift` (add toggle)
- `MailEngine.swift` (call indexer after processing)
- Update `Info.plist` with CSSearchableIndex support

**Key Adaptations:**
```swift
// Change from MBox Explorer's Email model to Mail Summary's
attributeSet.title = email.subject
attributeSet.contentDescription = email.aiSummary ?? email.body.prefix(500)
attributeSet.authorEmailAddresses = [email.senderEmail]
attributeSet.contentCreationDate = email.date
```

**Estimated Effort:** 6-8 hours

---

### 1.3 Quick Look Preview

**Source:** `MBox Explorer/Services/QuickLookPreview.swift`

**Integration Steps:**
1. Copy `QuickLookPreview.swift` to `Mail Summary/Services/`
2. Add Quartz framework to project
3. Integrate with email list selection
4. Add space bar shortcut in `ContentView.swift`
5. Generate HTML preview from email content

**Files to Create/Modify:**
- `Services/QuickLookPreview.swift` (new)
- `Views/ContentView.swift` (add keyboard shortcut)
- Project settings (add Quartz framework)

**Estimated Effort:** 4-6 hours

---

### 1.4 Enhanced Batch Operations Toolbar

**Source:** `MBox Explorer/Views/Features/BatchOperationsView.swift`

**Integration Steps:**
1. Copy `BatchOperationsView.swift` to `Mail Summary/Views/Components/`
2. Adapt for Mail Summary's action system
3. Integrate with existing `EmailActionManager.swift`
4. Add to main ContentView when multiple emails selected
5. Include AI-powered batch actions:
   - Batch categorize
   - Batch priority adjustment
   - Batch rule application

**Key Adaptations:**
```swift
// Use Mail Summary's action system
EmailActionManager.shared.performBatchAction(.archive, on: selectedEmails)
EmailActionManager.shared.performBatchAction(.markRead, on: selectedEmails)
```

**Files to Create/Modify:**
- `Views/Components/BatchOperationsToolbar.swift` (new)
- `Views/ContentView.swift` (integrate toolbar)
- `Managers/EmailActionManager.swift` (add batch methods)

**Estimated Effort:** 6-8 hours

---

## Phase 2: Medium Priority (Week 3-4)

### 2.1 Enhanced Notification Center Integration

**Source:** `MBox Explorer/Services/NotificationService.swift`

**Integration Steps:**
1. Copy and adapt `NotificationService.swift`
2. Integrate with SnoozeReminderManager for follow-up reminders
3. Add notification for:
   - VIP sender emails
   - High priority emails
   - Snooze expirations
   - Action item deadlines
4. Add granular notification settings

**Files to Create/Modify:**
- `Services/NotificationService.swift` (new)
- `Managers/SnoozeReminderManager.swift` (integrate)
- `Views/SettingsView.swift` (notification preferences)

**Estimated Effort:** 6-8 hours

---

### 2.2 Email Diff View

**Source:** `MBox Explorer/Views/Features/EmailDiffView.swift`

**Integration Steps:**
1. Copy `EmailDiffView.swift` to `Mail Summary/Views/`
2. Add "Compare Emails" option in context menu
3. Useful for:
   - Comparing versions in thread
   - Tracking changes in forwarded emails
   - Seeing what changed between similar emails

**Files to Create/Modify:**
- `Views/EmailDiffView.swift` (new)
- `Views/EmailDetailView.swift` (add compare option)

**Estimated Effort:** 4-6 hours

---

### 2.3 Contact Exporter

**Source:** `MBox Explorer/Services/ContactExporter.swift`

**Integration Steps:**
1. Copy `ContactExporter.swift` to `Mail Summary/Services/`
2. Integrate with SenderIntelligenceManager
3. Export options:
   - vCard (.vcf)
   - CSV
   - Add to macOS Contacts
4. Include relationship intelligence data in export

**Files to Create/Modify:**
- `Services/ContactExporter.swift` (new)
- `Views/SenderIntelligenceView.swift` (add export button)

**Estimated Effort:** 4-6 hours

---

### 2.4 Enhanced Analytics with Charts

**Source:** `MBox Explorer/Views/Features/EmailStatisticsDashboard.swift`

**Integration Steps:**
1. Review existing `AnalyticsDashboardView.swift`
2. Add Swift Charts visualizations:
   - Email volume over time (line chart)
   - Category distribution (pie chart)
   - Response time trends (bar chart)
   - Sender heatmap
3. Add timeline visualization from TimelineView.swift
4. Add heatmap from HeatmapView.swift

**Files to Create/Modify:**
- `Views/AnalyticsDashboardView.swift` (enhance)
- `Views/Components/TimelineChart.swift` (new)
- `Views/Components/EmailHeatmap.swift` (new)

**Estimated Effort:** 8-10 hours

---

## Phase 3: Enhancement Features (Week 5+)

### 3.1 Word Cloud View
- Visual word cloud of email content
- Filter by sender/date range
- Click word to search

### 3.2 Command Palette
- Cmd+K quick access
- Fuzzy search for actions
- Keyboard-driven workflow

### 3.3 Tags & Collections
- Visual tag management
- Smart collections based on rules
- Color-coded organization

---

## Implementation Order Summary

| Week | Features | Hours |
|------|----------|-------|
| 1 | Search History, Spotlight Integration | 10-14h |
| 2 | Quick Look, Batch Operations | 10-14h |
| 3 | Notification Center, Email Diff | 10-14h |
| 4 | Contact Exporter, Enhanced Analytics | 12-16h |
| 5+ | Word Cloud, Command Palette, Tags | 12-16h |

**Total Estimated Effort:** 54-74 hours

---

## File Structure After Integration

```
Mail Summary/
├── Services/
│   ├── SpotlightIntegration.swift (NEW)
│   ├── QuickLookPreview.swift (NEW)
│   ├── NotificationService.swift (NEW)
│   └── ContactExporter.swift (NEW)
├── Managers/
│   ├── SearchHistoryManager.swift (NEW)
│   └── ... (existing managers)
├── Views/
│   ├── Components/
│   │   ├── BatchOperationsToolbar.swift (NEW)
│   │   ├── TimelineChart.swift (NEW)
│   │   ├── EmailHeatmap.swift (NEW)
│   │   └── WordCloud.swift (NEW)
│   ├── EmailDiffView.swift (NEW)
│   └── ... (existing views)
└── Models/
    └── SearchModels.swift (NEW)
```

---

## Testing Checklist

- [ ] Search History persists across app restarts
- [ ] Spotlight indexing completes without memory issues
- [ ] Quick Look works with space bar shortcut
- [ ] Batch operations work on 100+ selected emails
- [ ] Notifications appear for VIP emails
- [ ] Email diff shows correct differences
- [ ] Contact export creates valid vCard/CSV
- [ ] Charts render correctly with large datasets

---

## Notes

### Already Better in Mail Summary
The following MBox Explorer features are **already more sophisticated** in Mail Summary and should NOT be replaced:

1. **Smart Reply Suggestions** - Mail Summary's `SmartReplyEngine.swift` learns your writing style and generates replies in your voice. Much more advanced than MBox's basic suggestions.

2. **Sentiment Analysis** - `RelationshipIntelligenceEngine.swift` includes comprehensive sentiment analysis tied to relationship health scoring.

3. **Meeting/Event Extraction** - `MeetingAutopilotEngine.swift` not only extracts meetings but automatically accepts/declines based on calendar and value assessment.

### Integration Best Practices
1. Use Mail Summary's existing model classes, don't duplicate
2. Integrate with existing managers (EmailActionManager, SnoozeReminderManager)
3. Maintain Mail Summary's glass card UI design
4. Add features as optional toggles in settings
5. Test with large email archives (10,000+ emails)

---

**Document Version:** 1.0
**Last Updated:** January 30, 2026

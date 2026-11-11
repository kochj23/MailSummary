# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.1.0] - 2026-11-11

### Changed
- AI: migrated to NovaAIKit 1.0.0 (one AI layer for all Jordan Koch macOS apps): AI on/off, Auto failover with
  timeouts and retries, backend + model pickers with editable URLs (Ollama, MLX, TinyLLM, TinyChat, OpenWebUI,
  Nova Gateway, OpenRouter, OpenAI), Keychain-only keys under `com.jkoch.mailsummary.*` (https only), status
  indicator in the dashboard header and menu bar, and validation of every AI reply with a built-in fallback for
  every feature (keyword categorization, rule-based priority, template summaries and replies).
- Settings window is now the standard NovaAIKit AI settings pane; the menu bar has "AI Settings…".
- Mailbox summary shows its source ("AI · backend (model)" or "Built-in").
- Calendar/Reminders access uses the macOS 14 full-access APIs (usage descriptions added).

### Removed
- The app's own AI client code: AIBackendManager (+ extensions), the status menu, the AI-capabilities stubs, the
  multi-model load balancer (LLMBackendManager, ModelRegistry, OpenRouterProvider, KeychainStore), and uncompiled
  AI engine files that were never part of the build.
- Google Cloud, Azure, AWS and IBM Watson backends.

### Security
- First launch moves a plaintext OpenAI key from UserDefaults into the Keychain, deletes stored secrets of the
  removed cloud backends and the old AI prompt log, and copies keys from the old shared Keychain items.

### Fixed
- All compiler warnings (deprecated APIs, captured-var mutation in process timeouts, unused values).
- `/api/status` reports the real app version.

### Planned
- Performance improvements
- Additional features based on community feedback

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core functionality
- macOS native interface
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/MailSummary/releases).*

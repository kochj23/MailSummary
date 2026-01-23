//
//  HTMLContentView.swift
//  Mail Summary
//
//  WKWebView wrapper for rendering HTML email content
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI
import WebKit

struct HTMLContentView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = false  // Disable JavaScript for security

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString(htmlWrapper, baseURL: nil)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed
    }

    private var htmlWrapper: String {
        // Truncate very large emails
        let truncatedHTML = html.count > 100_000 ? String(html.prefix(100_000)) + "\n\n[Email truncated for performance]" : html

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    padding: 16px;
                    background-color: #0a0a0a;
                    color: #ffffff;
                    margin: 0;
                }
                a {
                    color: #00d4ff;
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 4px;
                }
                pre {
                    background-color: #1a1a1a;
                    padding: 12px;
                    border-radius: 6px;
                    overflow-x: auto;
                }
                code {
                    background-color: #1a1a1a;
                    padding: 2px 6px;
                    border-radius: 3px;
                    font-family: "SF Mono", Monaco, monospace;
                }
                blockquote {
                    border-left: 3px solid #00d4ff;
                    padding-left: 12px;
                    margin-left: 0;
                    color: #aaaaaa;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 12px 0;
                }
                td, th {
                    border: 1px solid #333;
                    padding: 8px;
                    text-align: left;
                }
                th {
                    background-color: #1a1a1a;
                }
            </style>
        </head>
        <body>
            \(truncatedHTML)
        </body>
        </html>
        """
    }
}

#Preview {
    HTMLContentView(html: """
        <h1>Email Subject</h1>
        <p>This is a test email with <strong>bold</strong> and <em>italic</em> text.</p>
        <p>Here's a <a href="https://example.com">link</a>.</p>
        <ul>
            <li>Item 1</li>
            <li>Item 2</li>
            <li>Item 3</li>
        </ul>
        """)
    .frame(width: 600, height: 400)
}

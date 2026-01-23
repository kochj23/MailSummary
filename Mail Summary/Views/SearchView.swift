//
//  SearchView.swift
//  Mail Summary
//
//  Search overlay with multi-field search and filtering
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var searchManager: SearchFilterManager
    @ObservedObject var mailEngine: MailEngine
    @Binding var isPresented: Bool
    @State private var selectedEmail: Email?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.cyan)
                    .font(.title2)

                TextField("Search emails...", text: $searchManager.filters.query)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .font(.title3)
                    .onChange(of: searchManager.filters.query) { _ in
                        searchManager.search(in: mailEngine.emails)
                    }

                if searchManager.filters.isActive {
                    Button(action: {
                        searchManager.clearFilters()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black)

            Divider()
                .background(Color.cyan)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Quick filters
                    QuickFilterChip(title: "Unread Only", isActive: searchManager.filters.unreadOnly) {
                        searchManager.filters.unreadOnly.toggle()
                        searchManager.search(in: mailEngine.emails)
                    }

                    QuickFilterChip(title: "High Priority", isActive: searchManager.filters.minPriority != nil) {
                        if searchManager.filters.minPriority == nil {
                            searchManager.filters.minPriority = 7
                        } else {
                            searchManager.filters.minPriority = nil
                        }
                        searchManager.search(in: mailEngine.emails)
                    }

                    Divider()
                        .frame(height: 20)

                    // Category filters
                    ForEach(Email.EmailCategory.allCases, id: \.self) { category in
                        CategoryFilterChip(
                            category: category,
                            isActive: searchManager.filters.categories.contains(category)
                        ) {
                            if searchManager.filters.categories.contains(category) {
                                searchManager.filters.categories.remove(category)
                            } else {
                                searchManager.filters.categories.insert(category)
                            }
                            searchManager.search(in: mailEngine.emails)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color.white.opacity(0.05))

            Divider()

            // Results
            if searchManager.isSearching {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))

                    Text("Searching...")
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
            } else if searchManager.results.isEmpty && searchManager.filters.isActive {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text("Try different keywords or filters")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxHeight: .infinity)
            } else if !searchManager.filters.isActive {
                VStack(spacing: 20) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.cyan.opacity(0.5))

                    Text("Start typing to search")
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text("Search by subject, sender, or body content")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // Results count
                        HStack {
                            Text("\(searchManager.results.count) result\(searchManager.results.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.cyan)

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Results list
                        ForEach(searchManager.results) { result in
                            SearchResultRow(result: result)
                                .onTapGesture {
                                    selectedEmail = result.email
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 800, height: 600)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan, lineWidth: 3)
        )
        .sheet(item: $selectedEmail) { email in
            EmailDetailView(email: email, mailEngine: mailEngine)
        }
    }
}

// MARK: - Supporting Views

/// Quick filter chip
private struct QuickFilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isActive ? Color.cyan : Color.gray.opacity(0.3), lineWidth: isActive ? 2 : 1)
                        )
                )
                .foregroundColor(isActive ? .cyan : .gray)
        }
        .buttonStyle(.plain)
    }
}

/// Category filter chip
private struct CategoryFilterChip: View {
    let category: Email.EmailCategory
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)

                Text(category.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? categoryColor.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActive ? categoryColor : Color.gray.opacity(0.3), lineWidth: isActive ? 2 : 1)
                    )
            )
            .foregroundColor(isActive ? categoryColor : .gray)
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch category {
        case .bills: return .red
        case .orders: return .green
        case .work: return .blue
        case .personal: return .cyan
        case .marketing: return .orange
        case .newsletters: return .purple
        case .social: return .pink
        case .spam: return .gray
        case .other: return .yellow
        }
    }
}

/// Search result row
private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            if let category = result.email.category {
                Image(systemName: category.icon)
                    .foregroundColor(categoryColor(category))
            }

            VStack(alignment: .leading, spacing: 4) {
                // Subject (with highlight if matched)
                Text(result.email.subject)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Sender
                Text("From: \(result.email.sender)")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Matched text preview
                if !result.matchedText.isEmpty && result.matchedText != result.email.subject {
                    Text(result.matchedText)
                        .font(.caption)
                        .foregroundColor(.cyan.opacity(0.7))
                        .lineLimit(2)
                }

                // Matched fields
                if !result.matchedFields.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(result.matchedFields).sorted(), id: \.self) { field in
                            Text(field)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.2))
                                .cornerRadius(4)
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }

            Spacer()

            // Priority and date
            VStack(alignment: .trailing, spacing: 4) {
                if let priority = result.email.priority {
                    Text("⭐ \(priority)")
                        .font(.caption)
                        .foregroundColor(priorityColor(priority))
                }

                Text(formatDate(result.email.dateReceived))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func categoryColor(_ category: Email.EmailCategory) -> Color {
        switch category {
        case .bills: return .red
        case .orders: return .green
        case .work: return .blue
        case .personal: return .cyan
        case .marketing: return .orange
        case .newsletters: return .purple
        case .social: return .pink
        case .spam: return .gray
        case .other: return .yellow
        }
    }

    private func priorityColor(_ priority: Int) -> Color {
        if priority >= 9 { return .red }
        if priority >= 7 { return .orange }
        if priority >= 5 { return .yellow }
        return .green
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

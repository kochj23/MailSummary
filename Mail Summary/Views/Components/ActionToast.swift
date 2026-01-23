//
//  ActionToast.swift
//  Mail Summary
//
//  Toast notification for action success/failure feedback
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct ActionToast: View {
    let message: String
    let isSuccess: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(isSuccess ? .green : .red)

            Text(message)
                .font(.body)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSuccess ? Color.green : Color.red, lineWidth: 2)
                )
        )
        .shadow(color: (isSuccess ? Color.green : Color.red).opacity(0.3), radius: 8)
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        ActionToast(message: "Email deleted successfully", isSuccess: true)
        ActionToast(message: "Failed to archive email", isSuccess: false)
    }
    .padding()
    .background(Color.black)
}

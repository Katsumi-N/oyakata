//
//  AuthViewModel.swift
//  oyakata-app
//
//  Created by Claude on 2025/07/20.
//

import Foundation
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isSignUpMode = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var isLoading = false
    
    private var authService: AuthService?
    
    var isFormValid: Bool {
        if isSignUpMode {
            return !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    func setAuthService(_ service: AuthService) {
        self.authService = service
    }
    
    func signUp() {
        guard isFormValid else {
            alertMessage = "入力内容を確認してください"
            showingAlert = true
            return
        }
        
        Task {
            await MainActor.run {
                isLoading = true
            }
            await authService?.signUp(email: email, password: password)
            await MainActor.run {
                isLoading = false
                if let error = authService?.errorMessage {
                    alertMessage = error
                    showingAlert = true
                } else {
                    clearForm()
                }
            }
        }
    }
    
    func signIn() {
        guard isFormValid else {
            alertMessage = "メールアドレスとパスワードを入力してください"
            showingAlert = true
            return
        }
        
        Task {
            await MainActor.run {
                isLoading = true
            }
            await authService?.signIn(email: email, password: password)
            await MainActor.run {
                isLoading = false
                if let error = authService?.errorMessage {
                    alertMessage = error
                    showingAlert = true
                } else {
                    clearForm()
                }
            }
        }
    }
    
    func signOut() {
        Task {
            await authService?.signOut()
        }
    }
    
    func resetPassword() {
        guard !email.isEmpty else {
            alertMessage = "メールアドレスを入力してください"
            showingAlert = true
            return
        }
        
        Task {
            await MainActor.run {
                isLoading = true
            }
            await authService?.resetPassword(email: email)
            await MainActor.run {
                isLoading = false
                if let error = authService?.errorMessage {
                    alertMessage = error
                } else {
                    alertMessage = "パスワードリセットメールを送信しました"
                }
                showingAlert = true
            }
        }
    }
    
    func toggleAuthMode() {
        isSignUpMode.toggle()
        clearForm()
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
    }
}
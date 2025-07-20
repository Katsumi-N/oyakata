//
//  AuthService.swift
//  oyakata-app
//
//  Created by Claude on 2025/07/20.
//

import Foundation
import Supabase

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var client: SupabaseClient {
        return supabase
    }
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        isLoading = true
        Task {
            do {
                let session = try await client.auth.session
                await MainActor.run {
                    self.user = session.user
                    self.isAuthenticated = session.user != nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.isLoading = false
                }
            }
        }
    }
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await client.auth.signUp(
                email: email, 
                password: password,
                redirectTo: URL(string: "oyakata-app://auth/callback")
            )
            await MainActor.run {
                self.user = response.user
                self.isAuthenticated = response.user != nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await client.auth.signIn(email: email, password: password)
            await MainActor.run {
                self.user = response.user
                self.isAuthenticated = response.user != nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() async {
        isLoading = true
        
        do {
            try await client.auth.signOut()
            await MainActor.run {
                self.user = nil
                self.isAuthenticated = false
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await client.auth.resetPasswordForEmail(
                email
            )
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

}
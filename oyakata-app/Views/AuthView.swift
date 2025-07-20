//
//  AuthView.swift
//  oyakata-app
//
//  Created by Claude on 2025/07/20.
//

import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(viewModel.isSignUpMode ? "アカウント作成" : "ログイン")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)
                
                VStack(spacing: 15) {
                    TextField("メールアドレス", text: $viewModel.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("パスワード", text: $viewModel.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if viewModel.isSignUpMode {
                        SecureField("パスワード確認", text: $viewModel.confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal, 20)
                
                Button(action: {
                    if viewModel.isSignUpMode {
                        viewModel.signUp()
                    } else {
                        viewModel.signIn()
                    }
                }) {
                    if viewModel.authService_.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(viewModel.isSignUpMode ? "アカウント作成" : "ログイン")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .disabled(!viewModel.isFormValid || viewModel.authService_.isLoading)
                
                if !viewModel.isSignUpMode {
                    Button("パスワードを忘れた場合") {
                        viewModel.resetPassword()
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.toggleAuthMode()
                }) {
                    Text(viewModel.isSignUpMode ? "既にアカウントをお持ちですか？ログイン" : "アカウントをお持ちでない場合は？サインアップ")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .alert("通知", isPresented: $viewModel.showingAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

#Preview {
    AuthView()
}

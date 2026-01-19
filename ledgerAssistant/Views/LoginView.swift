import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject var globalAuth: AuthViewModel // Used to update parent state
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            DotPattern()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(MangaTheme.yellow)
                        .comicBorder(width: 3, cornerRadius: 40)
                    
                    Text("歡迎回來")
                        .font(.system(size: 32, weight: .black))
                        .italic()
                    
                    Text("請輸入 Email 登入您的帳本")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                if !viewModel.isShowingOTP {
                    // Email Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("EMAIL")
                            .font(.system(size: 14, weight: .black))
                        
                        TextField("your@email.com", text: $viewModel.email)
                            .padding()
                            .background(Color.white)
                            .comicBorder(width: 3, cornerRadius: 12)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: viewModel.sendOTP) {
                        if viewModel.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("傳送驗證碼")
                                .font(.system(size: 18, weight: .black))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(MangaTheme.yellow)
                    .foregroundColor(.black)
                    .comicBorder(width: 3, cornerRadius: 15)
                    .padding(.horizontal, 40)
                    .disabled(viewModel.isLoading)
                    
                } else {
                    // OTP Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("驗證碼 (OTP)")
                            .font(.system(size: 14, weight: .black))
                        
                        TextField("請輸入 6 位數代碼", text: $viewModel.otpToken)
                            .padding()
                            .background(Color.white)
                            .comicBorder(width: 3, cornerRadius: 12)
                            .keyboardType(.numberPad)
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: {
                        viewModel.verifyOTP()
                    }) {
                        if viewModel.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("確認登入")
                                .font(.system(size: 18, weight: .black))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .comicBorder(width: 3, cornerRadius: 15)
                    .padding(.horizontal, 40)
                    .disabled(viewModel.isLoading)
                    
                    Button("返回修改 Email") {
                        viewModel.isShowingOTP = false
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                }
                
                // OR Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                    Text("或使用以下方式")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal, 40)
                
                // Social Logins
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: viewModel.prepareAppleSignInRequest,
                        onCompletion: viewModel.handleAppleSignInResult
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .comicBorder(width: 3, cornerRadius: 15)
                    .padding(.horizontal, 40)
                    
                    // Google Sign In Placeholder
                    Button(action: {
                        // In a real app, this would trigger GIDSignIn.sharedInstance.signIn
                        viewModel.errorMessage = "Google 登入需要先在專案中安裝 GoogleSignIn SDK"
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("使用 Google 登入")
                                .font(.system(size: 16, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .comicBorder(width: 3, cornerRadius: 15)
                    }
                    .padding(.horizontal, 40)
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .comicBorder(width: 1, cornerRadius: 8, color: .red)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            }
        }
        .onChange(of: viewModel.isAuthenticated) { authenticated in
            if authenticated {
                globalAuth.isAuthenticated = true
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(AuthViewModel())
}

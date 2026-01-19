import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit

class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var otpToken: String = ""
    @Published var isShowingOTP = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isAuthenticated = false
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        Task {
            do {
                let session = try await SupabaseManager.shared.getSession()
                await MainActor.run {
                    self.isAuthenticated = (session != nil)
                }
            } catch {
                print("Session check failed: \(error)")
            }
        }
    }
    
    func sendOTP() {
        guard !email.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.signIn(email: email)
                await MainActor.run {
                    self.isLoading = false
                    self.isShowingOTP = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "發送失敗: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Apple Sign In Support
    private var currentNonce: String?
    
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let identityToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: identityToken, encoding: .utf8) else {
                    self.errorMessage = "無法取得 Identity Token"
                    return
                }
                
                isLoading = true
                Task {
                    do {
                        try await SupabaseManager.shared.signInWithApple(idToken: idTokenString, nonce: currentNonce)
                        await MainActor.run {
                            self.isLoading = false
                            self.isAuthenticated = true
                        }
                    } catch {
                        await MainActor.run {
                            self.isLoading = false
                            self.errorMessage = "Apple 登入失敗: \(error.localizedDescription)"
                        }
                    }
                }
            }
        case .failure(let error):
            self.errorMessage = "Apple 授權失敗: \(error.localizedDescription)"
        }
    }
    
    // Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
    
    func verifyOTP() {
        guard !otpToken.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.verifyOTP(email: email, token: otpToken)
                await MainActor.run {
                    self.isLoading = false
                    self.isAuthenticated = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "驗證失敗: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                try await SupabaseManager.shared.signOut()
                await MainActor.run {
                    self.isAuthenticated = false
                    self.email = ""
                    self.otpToken = ""
                    self.isShowingOTP = false
                }
            } catch {
                print("Logout failed: \(error)")
            }
        }
    }
}

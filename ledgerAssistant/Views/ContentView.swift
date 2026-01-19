//
//  ContentView.swift
//  ledgerAssistant
//
//  Created by Tsunghuan1 Lee on 2026/1/11.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        MangaStyleDashboardView()
            .environmentObject(authViewModel)
    }
}

#Preview {
    ContentView()
}

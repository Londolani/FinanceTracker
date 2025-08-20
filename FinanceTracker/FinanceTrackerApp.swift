//
//  FinanceTrackerApp.swift
//  FinanceTracker
//
//  Created by Londolani Ndou on 2025/08/19.
//

import SwiftUI

@main
struct FinanceTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppwriteService.shared)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appwriteService: AppwriteService
    
    var body: some View {
        Group {
            if appwriteService.isLoading {
                LoadingView()
            } else if appwriteService.isAuthenticated {
                DashboardView()
            } else {
                AuthView()
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Finance Tracker")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
            }
        }
    }
}

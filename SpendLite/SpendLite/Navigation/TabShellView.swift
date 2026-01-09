//
//  TabShellView.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/13/25.
//

import SwiftUI

struct TabShellView: View {
    @Environment(\.container) private var container
    var body: some View {
        TabView {
            // Home
            makeTab(
                title: "Home",
                systemImage: "house.fill",
                navTitle: "SpendLite") {
                    HomeScreen(expense: container.expenses)
                }
            
            // Add expense
            makeTab(
                title: "Add",
                systemImage: "plus.circle.fill",
                navTitle: "Add Expense") {
                    Text("Add Expense")
                        .font(.title)
                }
            
            //Insights
            makeTab(
                title: "Insights",
                systemImage: "chart.pie.fill",
                navTitle: "Insights") {
                    Text("Insights")
                        .font(.title)
                }
            
            
            //History
            makeTab(
                title: "History",
                systemImage: "clock.arrow.circlepath",
                navTitle: "History") {
                    Text("History")
                        .font(.title)
                }
            
            //Settings
            makeTab(
                title: "Settings",
                systemImage: "gearshape.fill",
                navTitle: "Settings") {
                    Text("Settings")
                        .font(.title)
                }
        }
        
    }
    
    private func makeTab<Content: View>(
        title: String,
        systemImage: String,
        navTitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationTitle(navTitle)
        }
        .tabItem {
            Label(title, systemImage: systemImage)
        }
    }
}

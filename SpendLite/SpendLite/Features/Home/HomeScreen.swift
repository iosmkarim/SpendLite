//
//  HomeScreen.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/14/25.
//

import SwiftUI

struct HomeScreen: View {
    
    @StateObject var viewModel : HomeViewModel
    
    init(expense: ExpenseRepository) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(expenses: expense))
    }
    
    var body: some View {
        Group {
            if viewModel.hasAnyExpense {
                populatedHomePlaceholder
            } else {
                emptyHome
            }
        }.onAppear {
            viewModel.onAppear()
        }
    }
    // MARK: - Views
    ///Temporary placeholder for the "real" Home Screen with Data.
    private var populatedHomePlaceholder: some View {
        Text("Home with data goes here")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Empty-state Home Screen - matches the UX idea
    private var emptyHome: some View {
        VStack(spacing: 24) {
            Spacer()
            
            //Icon placeholder
            
            Image(systemName: "creditCard")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.blue)
            
            VStack(spacing: 8) {
                Text("No expenses yet")
                    .font(.title2).bold()
                Text("Add your first expense to see insights and track your budget.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                // later: router.present(.addExpense)
            } label: {
                Text("Add Expense")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 32)
            
            Button {
                // later: load samle data
                viewModel.addSampleData()
            } label: {
                Text("Add sample data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    HomeScreen(expense: AppContainer(inMemory: true).expenses)
}

//
//  HomeSummary.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 1/9/26.
//

import Foundation

struct HomeSummary {
    let monthlyBudget: Double
    let totalSpent: Double
    
    var remaining: Double {
        monthlyBudget - totalSpent
    }
    
    var progress: Double {
        guard monthlyBudget > 0 else { return 0 }
        return totalSpent / monthlyBudget 
    }
}

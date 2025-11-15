//
//  Router.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/13/25.
//

import SwiftUI
import Combine

/// Simple generic router we can reuse per tab later.
final class Router<Route: Hashable>: ObservableObject {
    @Published var path: [Route] = []
    @Published var sheet: Route? = nil
    
    func push(_ route: Route) {
        path.append(route)
    }
    
    func pop() {
        _ = path.popLast()
    }
    
    func reset() {
        path.removeAll()
    }
    
    func present(_ route: Route) {
        sheet = route
    }
    
    func dismiss() {
        sheet = nil
    }
}

import SwiftUI
import Combine

final class NavCoordinator: ObservableObject {
    enum Route: Hashable {
        case insights
        case transactions
    }

    @Published var path: [Route] = []

    // MARK: - Navigation API
    func goToInsights() {
        path.append(.insights)
    }

    func goToTransactions() {
        path.append(.transactions)
    }

    func pop() {
        _ = path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}

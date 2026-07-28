import SwiftUI

// The top-level sections available in the sidebar.
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard
    case products
    case stock
    case documents
    case users
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .products:  return "Products & Prices"
        case .stock:     return "Stock"
        case .documents: return "Documents"
        case .users:     return "User Management"
        case .settings:  return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .products:  return "tag.fill"
        case .stock:     return "shippingbox.fill"
        case .documents: return "doc.text.fill"
        case .users:     return "person.2.fill"
        case .settings:  return "gearshape.fill"
        }
    }
}

struct NavigationSidebarView: View {
    @Bindable var auth: AuthManager
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.icon)
                        .tag(item)
                }
            }
            .navigationTitle("Octopus")
            .scrollContentBackground(.hidden)
            .background(sidebarBackground)
        } detail: {
            detailView
        }
        .tint(.teal)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .dashboard {
        case .dashboard: DashboardView(auth: auth)
        case .products:  ProductsView(auth: auth)
        case .stock:     StockView(auth: auth)
        case .documents: DocumentsView(auth: auth)
        case .users:     UsersView(auth: auth)
        case .settings:  SettingsView(auth: auth)
        }
    }

    // Liquid Glass sidebar: plain black/white base with a translucent material layer.
    private var sidebarBackground: some View {
        ZStack {
            (isDarkMode ? Color.black : Color.white)
            Rectangle().fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
    }
}

import SwiftUI

struct UsersView: View {
    @Bindable var auth: AuthManager
    @State private var vm = UsersViewModel()
    @State private var userPendingReset: UserDto? = nil
    @State private var resultMessage: String? = nil
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.users.isEmpty {
                    ProgressView().controlSize(.large)
                } else if let error = vm.errorMessage, vm.users.isEmpty {
                    ContentUnavailableView("Couldn't load users",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text(error))
                } else {
                    List(vm.users) { user in
                        userRow(user)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("User Management")
            .background(.ultraThinMaterial)
            .refreshable { await reload() }
            .task { await reload() }
            .confirmationDialog("Reset this user's password?",
                                isPresented: Binding(
                                    get: { userPendingReset != nil },
                                    set: { if !$0 { userPendingReset = nil } }),
                                titleVisibility: .visible,
                                presenting: userPendingReset) { user in
                Button("Reset Password", role: .destructive) {
                    Task { await performReset(for: user) }
                }
                Button("Cancel", role: .cancel) { userPendingReset = nil }
            } message: { user in
                Text("An admin password reset will be triggered for \(user.userName ?? user.email ?? "this user").")
            }
            .alert("Password Reset", isPresented: $showResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(resultMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func userRow(_ user: UserDto) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.userName ?? user.email ?? "Unknown")
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(user.role ?? "No role")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    statusBadge(isBlocked: user.isBlocked ?? false)
                }
            }
            Spacer()
            Button {
                userPendingReset = user
            } label: {
                Image(systemName: "key.horizontal.fill")
                    .foregroundColor(.teal)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusBadge(isBlocked: Bool) -> some View {
        Text(isBlocked ? "Blocked" : "Active")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background((isBlocked ? Color.red : Color.green).opacity(0.2), in: Capsule())
            .foregroundColor(isBlocked ? .red : .green)
    }

    private func reload() async {
        guard let token = auth.jwtToken else { return }
        await vm.load(apiBaseUrl: auth.apiBaseUrl, token: token)
    }

    private func performReset(for user: UserDto) async {
        let ok = await vm.resetPassword(for: user, apiBaseUrl: auth.apiBaseUrl, token: auth.jwtToken ?? "")
        userPendingReset = nil
        resultMessage = ok
            ? "Password reset triggered for \(user.userName ?? user.email ?? "the user")."
            : (vm.errorMessage ?? "Password reset failed.")
        showResult = true
    }
}

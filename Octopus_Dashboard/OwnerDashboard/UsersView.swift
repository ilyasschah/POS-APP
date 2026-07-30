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
            .onAppear { Task { await reload() } }
            .sheet(item: $userPendingReset) { user in
                ResetPasswordSheet(user: user) { newPassword in
                    await performReset(for: user, newPassword: newPassword)
                }
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
                Text(user.displayName)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(user.roleName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    statusBadge(isEnabled: user.isEnabled)
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
    private func statusBadge(isEnabled: Bool) -> some View {
        Text(isEnabled ? "Active" : "Disabled")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background((isEnabled ? Color.green : Color.red).opacity(0.2), in: Capsule())
            .foregroundColor(isEnabled ? .green : .red)
    }

    private func reload() async {
        guard let token = auth.jwtToken else { return }
        await vm.load(apiBaseUrl: auth.apiBaseUrl, token: token)
    }

    private func performReset(for user: UserDto, newPassword: String) async -> Bool {
        let ok = await vm.resetPassword(for: user,
                                        newPassword: newPassword,
                                        apiBaseUrl: auth.apiBaseUrl,
                                        token: auth.jwtToken ?? "")
        resultMessage = ok
            ? "Password reset for \(user.displayName)."
            : (vm.errorMessage ?? "Password reset failed.")
        showResult = true
        return ok
    }
}

// MARK: - Reset password sheet

struct ResetPasswordSheet: View {
    let user: UserDto
    let onReset: (String) async -> Bool

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    private var canSubmit: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reset password for \(user.displayName)") {
                    SecureField("New password", text: $newPassword)
                    SecureField("Confirm password", text: $confirmPassword)
                    if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text("Passwords don't match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            let ok = await onReset(newPassword)
                            isSaving = false
                            if ok { dismiss() }
                        }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Reset") }
                    }
                    .disabled(isSaving || !canSubmit)
                }
            }
        }
    }
}

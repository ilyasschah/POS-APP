import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_controller.dart';
import '../../core/screen_state.dart';
import '../../models/user.dart';

class UsersController extends AsyncController<List<StaffUser>> {
  @override
  Future<List<StaffUser>> fetch(CancelToken cancelToken) =>
      api.fetchUsers(cancelToken: cancelToken);

  /// Admin-triggered forced password reset.
  ///
  /// Errors propagate so the dialog can stay open and show the server's own
  /// message (a Cashier-level token gets a 403 from the `ManagerOnly` policy).
  Future<void> resetPassword({
    required int userId,
    required String newPassword,
  }) => api.adminResetPassword(userId: userId, newPassword: newPassword);
}

final usersProvider =
    NotifierProvider<UsersController, ScreenState<List<StaffUser>>>(
      UsersController.new,
    );

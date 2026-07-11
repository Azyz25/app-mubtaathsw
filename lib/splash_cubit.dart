import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';

part 'splash_state.dart';

/// [SplashCubit] controls the splash screen lifecycle:
/// 1. Emit [SplashAnimating] so the page starts entrance animations.
/// 2. In parallel, verify the stored auth token against the server.
/// 3. After minimum display duration, route to the appropriate screen.
final class SplashCubit extends Cubit<SplashState> {
  SplashCubit() : super(SplashInitial());

  /// Minimum time the splash is visible (brand feels premium, not rushed)
  static const Duration _minimumSplashDuration = Duration(milliseconds: 2800);

  /// Called once when [SplashPage] is mounted
  Future<void> initialize() async {
    emit(SplashAnimating());

    // Run auth check and minimum timer concurrently
    final results = await Future.wait([
      _checkAuthStatus(),
      Future.delayed(_minimumSplashDuration),
    ]);

    final bool isLoggedIn = results[0] as bool;

    if (isLoggedIn) {
      emit(SplashNavigateToHome());
    } else {
      emit(SplashNavigateToOnboarding());
    }
  }

  /// Validates the stored token against GET /api/auth/me.
  /// Returns false and clears storage on 401 (revoked/expired token).
  /// Returns true on network errors — avoids false logout when offline.
  Future<bool> _checkAuthStatus() async {
    final token = await SecureStorageService.readAuthToken();
    if (token == null) return false;

    try {
      await appDio.get('/auth/me');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await SecureStorageService.clearAll();
        return false;
      }
      // Network/server error — keep user logged in; API calls will handle failures
      return true;
    } catch (_) {
      return true;
    }
  }
}

part of 'splash_cubit.dart';

/// States emitted by [SplashCubit]
sealed class SplashState {}

/// Initial state — animation not started yet
final class SplashInitial extends SplashState {}

/// Animation is running — logo fade + slide in progress
final class SplashAnimating extends SplashState {}

/// Navigate to onboarding — user has no saved session
final class SplashNavigateToOnboarding extends SplashState {}

/// Navigate directly to home — user session token is valid
final class SplashNavigateToHome extends SplashState {}

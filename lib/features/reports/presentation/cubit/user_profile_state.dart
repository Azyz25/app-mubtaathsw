part of 'user_profile_cubit.dart';

enum UserProfileStatus { initial, loading, loaded, error }

class UserProfileState {
  final UserProfileStatus status;
  final String? name;
  final String? username;
  final String? avatarUrl;
  final String? countryNameAr;
  final String? countryNameEn;
  final String? countryFlag;
  final String? errorMessage;

  const UserProfileState({
    this.status        = UserProfileStatus.initial,
    this.name,
    this.username,
    this.avatarUrl,
    this.countryNameAr,
    this.countryNameEn,
    this.countryFlag,
    this.errorMessage,
  });

  UserProfileState copyWith({
    UserProfileStatus? status,
    String?            name,
    String?            username,
    String?            avatarUrl,
    String?            countryNameAr,
    String?            countryNameEn,
    String?            countryFlag,
    String?            errorMessage,
  }) =>
      UserProfileState(
        status:        status        ?? this.status,
        name:          name          ?? this.name,
        username:      username      ?? this.username,
        avatarUrl:     avatarUrl     ?? this.avatarUrl,
        countryNameAr: countryNameAr ?? this.countryNameAr,
        countryNameEn: countryNameEn ?? this.countryNameEn,
        countryFlag:   countryFlag   ?? this.countryFlag,
        errorMessage:  errorMessage  ?? this.errorMessage,
      );
}

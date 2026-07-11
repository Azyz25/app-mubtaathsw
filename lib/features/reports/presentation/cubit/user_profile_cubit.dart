import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:mubtaath/core/services/dio_client.dart';

part 'user_profile_state.dart';

class UserProfileCubit extends Cubit<UserProfileState> {
  UserProfileCubit() : super(const UserProfileState());

  Future<void> fetchUser(int userId) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      final resp = await appDio.get('/users/$userId');
      final data = resp.data['data'] as Map<String, dynamic>;
      emit(state.copyWith(
        status:        UserProfileStatus.loaded,
        name:          data['full_name']      as String?,
        username:      data['username']       as String?,
        avatarUrl:     data['avatar_url']     as String?,
        countryNameAr: data['country_name_ar'] as String?,
        countryNameEn: data['country_name_en'] as String?,
        countryFlag:   data['country_flag']   as String?,
      ));
    } on DioException catch (e) {
      emit(state.copyWith(
        status:       UserProfileStatus.error,
        errorMessage: e.response?.data?['message'] as String?,
      ));
    }
  }
}

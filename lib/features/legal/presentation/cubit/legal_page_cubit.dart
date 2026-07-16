import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mubtaath/core/services/dio_client.dart';

part 'legal_page_state.dart';

/// Fetches a single dashboard-editable legal page (Terms, Privacy, ...) by
/// slug. Public endpoint — works pre-auth so it can be opened from the
/// registration screen before the user has a token.
class LegalPageCubit extends Cubit<LegalPageState> {
  final String slug;

  LegalPageCubit({required this.slug}) : super(const LegalPageState()) {
    _load();
  }

  Future<void> _load() async {
    emit(state.copyWith(status: LegalPageStatus.loading));
    try {
      final resp = await appDio.get('/legal-pages/$slug');
      final data = resp.data['data'] as Map<String, dynamic>;
      emit(state.copyWith(
        status: LegalPageStatus.loaded,
        page: LegalPageData.fromJson(data),
      ));
    } on DioException catch (_) {
      emit(state.copyWith(status: LegalPageStatus.failure));
    }
  }

  Future<void> retry() => _load();
}

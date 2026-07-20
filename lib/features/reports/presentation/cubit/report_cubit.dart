import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:mubtaath/core/services/dio_client.dart';

part 'report_state.dart';

class ReportCubit extends Cubit<ReportState> {
  ReportCubit() : super(const ReportState());

  /// Submit a general support ticket from the Help & Support page.
  Future<void> submitSupportTicket({
    required String category,
    required String description,
  }) async {
    emit(state.copyWith(status: ReportStatus.sending));
    try {
      await appDio.post('/reports', data: {
        'report_type': 'support_ticket',
        'reason':      category,
        'description': description,
        'severity':    'medium',
      });
      emit(state.copyWith(status: ReportStatus.success));
    } on DioException catch (e) {
      // No hardcoded fallback here — leaving errorMessage null lets the UI's
      // own `?? l10n.reportSentError` show a properly localized message when
      // the backend gives no text of its own.
      emit(state.copyWith(
        status: ReportStatus.failure,
        errorMessage: e.response?.data?['message'] as String?,
      ));
    }
  }

  /// Report another user (from in-room speaker tile or profile view).
  Future<void> reportUser({
    required int    reportedUserId,
    required String category,
    required String description,
    String?         roomId,
  }) async {
    emit(state.copyWith(status: ReportStatus.sending));
    try {
      await appDio.post('/reports', data: {
        'report_type':       'user_report',
        'reported_user_id':  reportedUserId,
        'reason':            category,
        'description':       description,
        'room_id':           roomId,
        'severity':          'high',
      });
      emit(state.copyWith(status: ReportStatus.success));
    } on DioException catch (e) {
      emit(state.copyWith(
        status: ReportStatus.failure,
        errorMessage: e.response?.data?['message'] as String?,
      ));
    }
  }

  /// Report a specific chat message.
  Future<void> reportMessage({
    required int    reportedUserId,
    required String messageContent,
    required String category,
    String?         roomId,
  }) async {
    emit(state.copyWith(status: ReportStatus.sending));
    try {
      await appDio.post('/reports', data: {
        'report_type':       'message_report',
        'reported_user_id':  reportedUserId,
        'reason':            category,
        'reported_message':  messageContent,
        'room_id':           roomId,
        'severity':          'high',
      });
      emit(state.copyWith(status: ReportStatus.success));
    } on DioException catch (e) {
      emit(state.copyWith(
        status: ReportStatus.failure,
        errorMessage: e.response?.data?['message'] as String?,
      ));
    }
  }

  /// Fetch the authenticated user's own report history (GET /user/reports).
  Future<void> fetchUserReports() async {
    emit(state.copyWith(historyStatus: HistoryStatus.loading));
    try {
      final resp = await appDio.get('/user/reports');
      final list = (resp.data['data'] as List<dynamic>)
          .map((e) => UserReport.fromJson(e as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(historyStatus: HistoryStatus.loaded, reports: list));
    } on DioException catch (e) {
      emit(state.copyWith(
        historyStatus: HistoryStatus.failure,
        historyError:  e.response?.data?['message'] as String?,
      ));
    }
  }

  /// User replies back to admin's response on their own report.
  /// Uses a dedicated [replyStatus] slice so it doesn't collide with form submission.
  Future<void> sendUserReply({
    required String reportId,
    required String message,
  }) async {
    emit(state.copyWith(replyStatus: ReplyStatus.sending));
    try {
      await appDio.post('/user/reports/$reportId/reply', data: {'message': message});
      emit(state.copyWith(replyStatus: ReplyStatus.success));
    } on DioException catch (e) {
      emit(state.copyWith(
        replyStatus: ReplyStatus.failure,
        replyError: e.response?.data?['message'] as String?,
      ));
    }
  }

  /// Reset the reply status slice after the detail page handles success/failure.
  void resetReply() =>
      emit(state.copyWith(replyStatus: ReplyStatus.initial, replyError: null));

  void reset() => emit(const ReportState());
}

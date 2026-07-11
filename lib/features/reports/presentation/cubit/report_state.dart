part of 'report_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum ReportStatus  { initial, sending, success, failure }
enum HistoryStatus { initial, loading, loaded, failure  }
enum ReplyStatus   { initial, sending, success, failure }

// ─────────────────────────────────────────────────────────────────────────────
// ReportMessage — a single entry in the conversation thread.
// Mirrors the backend's buildThread() output: { type, senderName, content, at }
// ─────────────────────────────────────────────────────────────────────────────

class ReportMessage {
  final String   type;        // 'user' | 'admin'
  final String   senderName;
  final String   content;
  final DateTime? at;

  const ReportMessage({
    required this.type,
    required this.senderName,
    required this.content,
    this.at,
  });

  factory ReportMessage.fromJson(Map<String, dynamic> json) => ReportMessage(
    type:       (json['type']       as String?) ?? 'user',
    senderName: (json['senderName'] as String?) ?? '—',
    content:    (json['content']    as String?) ?? '',
    at: json['at'] != null
        ? DateTime.tryParse(json['at'] as String)
        : null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// UserReport — a single report from the user's own history list.
// API fields are camelCase (from ReportResource / UserReportResource).
// ─────────────────────────────────────────────────────────────────────────────

class UserReport {
  final String              id;          // UUID string from HasUuids
  final String              status;      // pending | under_review | resolved | dismissed
  final String              category;    // maps from report.reason
  final String              description;
  final String              reportType;  // support_ticket | user_report | message_report
  final String?             adminReply;  // latest admin reply (for card preview)
  final String?             userReply;   // latest user reply-back (for card preview)
  final DateTime            createdAt;
  final List<ReportMessage> messages;    // full conversation thread

  const UserReport({
    required this.id,
    required this.status,
    required this.category,
    required this.description,
    required this.reportType,
    this.adminReply,
    this.userReply,
    required this.createdAt,
    this.messages = const [],
  });

  // API returns camelCase keys from UserReportResource
  factory UserReport.fromJson(Map<String, dynamic> json) => UserReport(
    id:          (json['id'] as Object).toString(),
    status:      (json['status']      as String?) ?? 'pending',
    category:    (json['reason']      as String?) ?? '',
    description: (json['description'] as String?) ?? '',
    reportType:  (json['reportType']  as String?) ?? 'support_ticket',
    adminReply:  json['adminReply']   as String?,
    userReply:   json['userReply']    as String?,
    createdAt:   json['createdAt'] != null
                   ? DateTime.parse(json['createdAt'] as String)
                   : DateTime.now(),
    messages:    (json['messages'] as List<dynamic>?)
                   ?.map((m) => ReportMessage.fromJson(m as Map<String, dynamic>))
                   .toList() ?? const [],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ReportState
// ─────────────────────────────────────────────────────────────────────────────

class ReportState {
  // New-report submission slice
  final ReportStatus status;
  final String?      errorMessage;

  // History list slice
  final HistoryStatus      historyStatus;
  final List<UserReport>   reports;
  final String?            historyError;

  // User reply-to-admin slice (isolated so it doesn't collide with form submit)
  final ReplyStatus replyStatus;
  final String?     replyError;

  const ReportState({
    this.status        = ReportStatus.initial,
    this.errorMessage,
    this.historyStatus = HistoryStatus.initial,
    this.reports       = const [],
    this.historyError,
    this.replyStatus   = ReplyStatus.initial,
    this.replyError,
  });

  ReportState copyWith({
    ReportStatus?     status,
    String?           errorMessage,
    HistoryStatus?    historyStatus,
    List<UserReport>? reports,
    String?           historyError,
    ReplyStatus?      replyStatus,
    String?           replyError,
  }) =>
      ReportState(
        status:        status        ?? this.status,
        errorMessage:  errorMessage  ?? this.errorMessage,
        historyStatus: historyStatus ?? this.historyStatus,
        reports:       reports       ?? this.reports,
        historyError:  historyError  ?? this.historyError,
        replyStatus:   replyStatus   ?? this.replyStatus,
        replyError:    replyError    ?? this.replyError,
      );
}

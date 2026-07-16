part of 'legal_page_cubit.dart';

enum LegalPageStatus { loading, loaded, failure }

/// A single legal page's bilingual content, as returned by
/// GET /legal-pages/{slug} (LegalPageResource on the backend).
class LegalPageData {
  final String slug;
  final String titleAr;
  final String titleEn;
  final String contentAr;
  final String contentEn;

  const LegalPageData({
    required this.slug,
    required this.titleAr,
    required this.titleEn,
    required this.contentAr,
    required this.contentEn,
  });

  factory LegalPageData.fromJson(Map<String, dynamic> json) => LegalPageData(
        slug:      (json['slug']      as String?) ?? '',
        titleAr:   (json['titleAr']   as String?) ?? '',
        titleEn:   (json['titleEn']   as String?) ?? '',
        contentAr: (json['contentAr'] as String?) ?? '',
        contentEn: (json['contentEn'] as String?) ?? '',
      );
}

class LegalPageState {
  final LegalPageStatus status;
  final LegalPageData?  page;

  const LegalPageState({
    this.status = LegalPageStatus.loading,
    this.page,
  });

  LegalPageState copyWith({
    LegalPageStatus? status,
    LegalPageData?   page,
  }) =>
      LegalPageState(
        status: status ?? this.status,
        page:   page   ?? this.page,
      );
}

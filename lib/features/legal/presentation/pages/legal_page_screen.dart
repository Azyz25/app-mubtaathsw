// =============================================================================
// LEGAL PAGE SCREEN — Terms of Service / Privacy Policy / ... (by slug)
//
// Content is fully dashboard-editable (LegalPageCubit → GET /legal-pages/
// {slug}, public endpoint). Arabic/English fields are separate on the
// backend; this screen just picks the one matching the current app locale.
// Reachable pre-auth (registration checkbox) and post-auth (Settings).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/widgets/shared_widgets.dart';
import 'package:mubtaath/features/legal/presentation/cubit/legal_page_cubit.dart';

// Content is dashboard-authored rich HTML (bold/size, images, links) — the
// admin's WYSIWYG editor is the only thing that ever writes it, and its
// output is sanitized server-side before it reaches here.
Future<void> _openLink(String url) async {
  final normalized = url.trim().startsWith('http') ? url.trim() : 'https://${url.trim()}';
  try {
    await launchUrl(Uri.parse(normalized), mode: LaunchMode.externalApplication);
  } catch (_) {
    // No handler app installed — silently ignore.
  }
}

class LegalPageScreen extends StatelessWidget {
  final String slug; // 'terms' | 'privacy'
  final String fallbackTitle; // shown while loading, before the server title arrives

  const LegalPageScreen({
    super.key,
    required this.slug,
    required this.fallbackTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LegalPageCubit(slug: slug),
      child: _LegalPageView(fallbackTitle: fallbackTitle),
    );
  }
}

class _LegalPageView extends StatelessWidget {
  final String fallbackTitle;
  const _LegalPageView({required this.fallbackTitle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<LegalPageCubit, LegalPageState>(
          builder: (context, state) {
            final title = state.page != null
                ? (isArabic ? state.page!.titleAr : state.page!.titleEn)
                : fallbackTitle;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SharedHeader(title: title, showBack: true),
                const SizedBox(height: 20),
                Expanded(child: _body(context, state, l10n, isArabic)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    LegalPageState state,
    AppLocalizations l10n,
    bool isArabic,
  ) {
    switch (state.status) {
      case LegalPageStatus.loading:
        return const Center(
          child: MubtaathLoader(color: AppColors.primary, strokeWidth: 2.5),
        );

      case LegalPageStatus.failure:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.legalPageLoadError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.read<LegalPageCubit>().retry(),
                  child: Text(
                    l10n.tryAgain,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case LegalPageStatus.loaded:
        final content =
            isArabic ? state.page!.contentAr : state.page!.contentEn;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          // Dashboard-authored rich text (bold/size, images, links) — plain
          // text saved before the rich editor existed renders identically,
          // since untagged text is just a text node to the HTML parser.
          child: Html(
            data: content,
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontFamily: 'Tajawal',
                fontSize: FontSize(14.5),
                lineHeight: const LineHeight(1.9),
                color: AppColors.darkText,
                textAlign: TextAlign.start,
              ),
              'a': Style(
                color: AppColors.primary,
                textDecoration: TextDecoration.underline,
              ),
              'img': Style(
                margin: Margins.symmetric(vertical: 10),
              ),
            },
            onLinkTap: (url, attributes, element) {
              if (url != null && url.isNotEmpty) _openLink(url);
            },
          ),
        );
    }
  }
}

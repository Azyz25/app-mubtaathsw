// =============================================================================
// SUPPORT PAGE — Help & Support
//
// Tab 0 — New Report: submit a support ticket (Technical / Suggestion / Complaint)
// Tab 1 — My Reports: history list from GET /api/user/reports with status badges
//                     and admin reply display. Tapping a card opens the detail
//                     thread view where the user can also reply back to admin.
//
// Architecture: single ReportCubit handles submit, history fetch, and user reply.
// ReportStatus slice → new report submission
// HistoryStatus slice → list fetch
// ReplyStatus   slice → user reply to admin (isolated so listeners don't collide)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/auth_notifier.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/core/utils/bilingual_date.dart';
import 'package:mubtaath/core/widgets/mubtaath_loader.dart';
import 'package:mubtaath/features/reports/presentation/cubit/report_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root widget — provides the Cubit
// ─────────────────────────────────────────────────────────────────────────────

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportCubit(),
      child: const _SupportView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stateful view — owns TabController + form state
// ─────────────────────────────────────────────────────────────────────────────

class _SupportView extends StatefulWidget {
  const _SupportView();

  @override
  State<_SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<_SupportView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedCategory;
  final _descController = TextEditingController();
  final _formKey        = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ReportCubit>().fetchUserReports(),
    );
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
      context.read<ReportCubit>().fetchUserReports();
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _descController.dispose();
    super.dispose();
  }

  List<_CategoryOption> _categories(AppLocalizations l10n) => [
    _CategoryOption(value: l10n.categoryTechnical,  icon: LucideIcons.cpu),
    _CategoryOption(value: l10n.categorySuggestion, icon: LucideIcons.lightbulb),
    _CategoryOption(value: l10n.categoryComplaint,  icon: LucideIcons.alertTriangle),
  ];

  void _submit(BuildContext context, AppLocalizations l10n) {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.categoryRequired,
              style: const TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    context.read<ReportCubit>().submitSupportTicket(
      category:    _selectedCategory!,
      description: _descController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n       = AppLocalizations.of(context)!;
    final categories = _categories(l10n);

    return BlocConsumer<ReportCubit, ReportState>(
      // Only listen on the form-submission slice
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == ReportStatus.success) {
          setState(() => _selectedCategory = null);
          _descController.clear();
          _showSuccessSheet(context, l10n);
          context.read<ReportCubit>().fetchUserReports();
          _tabController.animateTo(1);
        } else if (state.status == ReportStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage ?? l10n.reportSentError,
                style: const TextStyle(
                    fontFamily: 'Tajawal', color: AppColors.white),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      },
      builder: (context, state) {
        final isSending = state.status == ReportStatus.sending;
        // When the user is suspended, support is reached FROM the suspended
        // screen — never let "back" leak them into the app. Route it back to
        // /suspended instead, and block the system/gesture back the same way.
        final isSuspended = suspendedNotifier.value;

        return PopScope(
          canPop: !isSuspended,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && isSuspended) context.go('/suspended');
          },
          child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor:        AppColors.background,
            elevation:              0,
            scrolledUnderElevation: 0,
            leading: isSuspended
                ? IconButton(
                    icon: const Icon(LucideIcons.arrowRight,
                        color: AppColors.darkText),
                    onPressed: () => context.go('/suspended'),
                  )
                : BackButton(color: AppColors.darkText),
            title: Text(
              l10n.helpAndSupport,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   17,
                fontWeight: FontWeight.w800,
                color:      AppColors.darkText,
              ),
            ),
            centerTitle: true,
            bottom: TabBar(
              controller:           _tabController,
              labelColor:           AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor:       AppColors.primary,
              indicatorWeight:      2.5,
              // Remove the full-width grey divider; only the indicator shows
              dividerColor: const Color(0x00000000),
              labelStyle: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: l10n.newReport),
                Tab(text: l10n.myReports),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildNewReportTab(context, l10n, categories, isSending),
              _buildHistoryTab(context, state, l10n),
            ],
          ),
        ),
        );
      },
    );
  }

  // ── New Report tab ────────────────────────────────────────────────────────

  Widget _buildNewReportTab(
    BuildContext context,
    AppLocalizations l10n,
    List<_CategoryOption> categories,
    bool isSending,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 20, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(l10n.selectCategory),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((cat) {
                final selected = _selectedCategory == cat.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat.icon,
                          size:  16,
                          color: selected
                              ? AppColors.white
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.value,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.white
                                : AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            _SectionLabel(l10n.describeIssue),
            const SizedBox(height: 12),

            TextFormField(
              controller:    _descController,
              maxLines:      6,
              textDirection: TextDirection.rtl,
              textAlign:     TextAlign.right,
              decoration: InputDecoration(
                hintText:  l10n.describeIssueHint,
                hintStyle: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize:   13,
                  color:      AppColors.textSecondary,
                ),
                filled:          true,
                fillColor:       AppColors.surface,
                contentPadding:  const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.cardBorder, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.cardBorder, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.6),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.error, width: 1.2),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l10n.descriptionRequired;
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSending
                    ? null
                    : () => _submit(context, l10n),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation:              0,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.55),
                ),
                child: isSending
                    ? const SizedBox(
                        width:  22,
                        height: 22,
                        child: MubtaathLoader(
                          color:       AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        l10n.submitReport,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── History tab ───────────────────────────────────────────────────────────

  Widget _buildHistoryTab(
    BuildContext context,
    ReportState state,
    AppLocalizations l10n,
  ) {
    switch (state.historyStatus) {
      case HistoryStatus.loading:
      case HistoryStatus.initial:
        return const Center(
          child: MubtaathLoader(color: AppColors.primary),
        );

      case HistoryStatus.failure:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.wifiOff,
                    color: AppColors.textSecondary, size: 40),
                const SizedBox(height: 12),
                Text(
                  state.historyError ?? l10n.genericError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize:   14,
                    color:      AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () =>
                      context.read<ReportCubit>().fetchUserReports(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    l10n.tryAgain,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );

      case HistoryStatus.loaded:
        if (state.reports.isEmpty) {
          return _EmptyHistoryState(l10n: l10n);
        }
        return ListView.separated(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 24),
          itemCount:        state.reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, index) {
            final report = state.reports[index];
            return GestureDetector(
              onTap: () => Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: ctx.read<ReportCubit>(),
                    child: _ReportDetailPage(report: report),
                  ),
                ),
              ),
              child: _ReportHistoryCard(report: report, l10n: l10n),
            );
          },
        );
    }
  }

  // ── Success bottom sheet ───────────────────────────────────────────────────

  void _showSuccessSheet(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    const Color(0x00000000),
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color:        AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.reportSubmittedTitle,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   18,
                fontWeight: FontWeight.w800,
                color:      AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reportSubmittedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize:   14,
                color:      AppColors.textSecondary,
                height:     1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  l10n.back,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Detail Page — rolling chat thread with a fixed bottom input bar.
//
// Layout:
//   AppBar  (title + status badge)
//   _MetadataStrip  (category + date — pinned below AppBar)
//   Expanded ListView  (chat bubbles — scrollable)
//   Bottom bar  — one of three states:
//     • _ChatInputBar   : ticket open AND last message is from admin
//     • _WaitingBar     : ticket open AND waiting for admin reply
//     • _ClosedBar      : ticket resolved or dismissed
//
// Local state:
//   _localMessages  starts from widget.report.messages (server snapshot) and
//                   optimistically appends when the user sends. After the HTTP
//                   request succeeds, fetchUserReports() runs in the background
//                   and updates _localMessages with the authoritative server
//                   data (correct timestamps + sender name).
// ─────────────────────────────────────────────────────────────────────────────

class _ReportDetailPage extends StatefulWidget {
  final UserReport report;
  const _ReportDetailPage({required this.report});

  @override
  State<_ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<_ReportDetailPage> {
  final _replyController  = TextEditingController();
  final _scrollController = ScrollController();
  late List<ReportMessage> _localMessages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _localMessages = List.from(widget.report.messages);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  bool get _isClosed {
    final s = widget.report.status;
    return s == 'resolved' || s == 'dismissed';
  }

  // Input bar visible only when ticket is open AND admin has the last word.
  bool get _canSend {
    if (_isClosed || _sending) return false;
    if (_localMessages.isEmpty) return true;
    return _localMessages.last.type == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context)!;
    final report = widget.report;

    return BlocConsumer<ReportCubit, ReportState>(
      listenWhen: (prev, curr) =>
          prev.replyStatus   != curr.replyStatus ||
          prev.historyStatus != curr.historyStatus,
      listener: (context, state) {
        if (state.replyStatus == ReplyStatus.success) {
          setState(() => _sending = false);
          // Background refresh — don't block the page.
          context.read<ReportCubit>()
            ..resetReply()
            ..fetchUserReports();
        } else if (state.replyStatus == ReplyStatus.failure) {
          // Roll back the optimistic message.
          setState(() {
            _localMessages = List.from(widget.report.messages);
            _sending       = false;
          });
          context.read<ReportCubit>().resetReply();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.replyError ?? l10n.reportSentError,
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
              ),
              backgroundColor: AppColors.error,
              behavior:        SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }

        // When the background refetch arrives, sync local thread with the
        // authoritative server data (gives us real timestamps + sender names).
        if (state.historyStatus == HistoryStatus.loaded) {
          final matches = state.reports.where((r) => r.id == widget.report.id).toList();
          if (matches.isNotEmpty &&
              matches.first.messages.length >= _localMessages.length) {
            setState(() => _localMessages = List.from(matches.first.messages));
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
        }
      },
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor:        AppColors.background,
            elevation:              0,
            scrolledUnderElevation: 0,
            leading: BackButton(color: AppColors.darkText),
            title: Text(
              l10n.ticketDetails,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   16,
                fontWeight: FontWeight.w800,
                color:      AppColors.darkText,
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(
                  child: _ReportStatusBadge(status: report.status, l10n: l10n),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Metadata strip (category + date, pinned) ─────────────
              _MetadataStrip(report: report),

              // ── Scrollable chat thread ───────────────────────────────
              Expanded(
                child: _localMessages.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            16, 16, 16, 8),
                        itemCount: _localMessages.length,
                        itemBuilder: (_, i) => _ChatBubble(
                          msg:     _localMessages[i],
                          pending: _sending && i == _localMessages.length - 1,
                        ),
                      ),
              ),

              // ── Bottom action bar ────────────────────────────────────
              if (_isClosed)
                _ClosedBar(l10n: l10n, status: report.status)
              else if (_canSend)
                _ChatInputBar(
                  controller: _replyController,
                  onSend:     () => _sendReply(context),
                )
              else
                const _WaitingBar(),
            ],
          ),
        );
      },
    );
  }

  void _sendReply(BuildContext context) {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;

    // Derive reporter name from first user message for the optimistic bubble.
    final reporterName = _localMessages.isNotEmpty
        ? (_localMessages.firstWhere(
            (m) => m.type == 'user',
            orElse: () => const ReportMessage(
                type: 'user', senderName: '—', content: ''),
          ).senderName)
        : '—';

    setState(() {
      _localMessages = [
        ..._localMessages,
        ReportMessage(
          type:       'user',
          senderName: reporterName,
          content:    text,
          at:         DateTime.now(),
        ),
      ];
      _sending = true;
    });
    _replyController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    context.read<ReportCubit>().sendUserReply(
      reportId: widget.report.id,
      message:  text,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat bubble — renders a single ReportMessage in the conversation thread.
// User messages align right (blue tint); admin messages align left (green tint).
// ─────────────────────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ReportMessage msg;
  // pending = true → optimistic message still in-flight (shows clock icon)
  final bool pending;
  const _ChatBubble({required this.msg, this.pending = false});

  @override
  Widget build(BuildContext context) {
    final isAdmin    = msg.type == 'admin';
    final bubbleColor  = isAdmin
        ? AppColors.success.withValues(alpha: 0.08)
        : AppColors.info.withValues(alpha: 0.08);
    final borderColor  = isAdmin
        ? AppColors.success.withValues(alpha: 0.28)
        : AppColors.info.withValues(alpha: 0.28);
    final labelColor   = isAdmin ? AppColors.success : AppColors.info;
    final icon         = isAdmin ? LucideIcons.shieldCheck : LucideIcons.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Sender label + icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: isAdmin
                ? [
                    Icon(icon, size: 13, color: labelColor),
                    const SizedBox(width: 5),
                    Text(
                      msg.senderName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   11,
                        fontWeight: FontWeight.w700,
                        color:      labelColor,
                      ),
                    ),
                  ]
                : [
                    Text(
                      msg.senderName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   11,
                        fontWeight: FontWeight.w700,
                        color:      labelColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(icon, size: 13, color: labelColor),
                  ],
          ),
          const SizedBox(height: 5),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color:        bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft:     Radius.circular(isAdmin ? 4 : 14),
                topRight:    Radius.circular(isAdmin ? 14 : 4),
                bottomLeft:  const Radius.circular(14),
                bottomRight: const Radius.circular(14),
              ),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Text(
              msg.content,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize:   13,
                color:      AppColors.darkText,
                height:     1.55,
              ),
            ),
          ),
          // Timestamp / pending indicator
          const SizedBox(height: 3),
          if (pending)
            const Icon(LucideIcons.clock, size: 11, color: AppColors.textSecondary)
          else if (msg.at != null)
            Text(
              formatShortDateTime(msg.at!, Localizations.localeOf(context).languageCode),
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize:   10,
                color:      AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metadata strip — category + date pinned between AppBar and thread list
// ─────────────────────────────────────────────────────────────────────────────

class _MetadataStrip extends StatelessWidget {
  final UserReport report;
  const _MetadataStrip({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              report.category.isNotEmpty ? report.category : report.reportType,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   13,
                fontWeight: FontWeight.w700,
                color:      AppColors.darkText,
              ),
            ),
          ),
          Text(
            formatShortDate(report.createdAt, Localizations.localeOf(context).languageCode),
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize:   11,
              color:      AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat input bar — fixed at the bottom when the ticket is open and the admin
// has the last word (user's turn to respond).
// ─────────────────────────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _ChatInputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller:    controller,
              maxLines:      4,
              minLines:      1,
              maxLength:     1000,
              textAlign:     TextAlign.start,
              decoration: InputDecoration(
                hintText:    l10n.typeYourReply,
                counterText: '',
                hintStyle: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize:   13,
                  color:      AppColors.textSecondary,
                ),
                filled:         true,
                fillColor:      AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                      color: AppColors.cardBorder, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                      color: AppColors.cardBorder, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.6),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width:  44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.send, size: 18, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waiting bar — shown when ticket is open but it's the admin's turn to reply
// ─────────────────────────────────────────────────────────────────────────────

class _WaitingBar extends StatelessWidget {
  const _WaitingBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.clock, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            l10n.waitingForSupportReply,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize:   12.5,
              color:      AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Closed bar — shown when ticket is resolved or dismissed
// ─────────────────────────────────────────────────────────────────────────────

class _ClosedBar extends StatelessWidget {
  final AppLocalizations l10n;
  final String           status;
  const _ClosedBar({required this.l10n, required this.status});

  @override
  Widget build(BuildContext context) {
    final isResolved = status == 'resolved';
    final color      = isResolved ? AppColors.success : AppColors.textSecondary;
    final icon       = isResolved ? LucideIcons.checkCircle : LucideIcons.xCircle;
    final label      = isResolved ? l10n.statusResolved : l10n.statusDismissed;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(
            top: BorderSide(color: color.withValues(alpha: 0.20), width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            l10n.ticketLabel(label),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize:   12.5,
              fontWeight: FontWeight.w700,
              color:      color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty-state widget for the history tab
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHistoryState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyHistoryState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.clipboardList,
                  color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noReportsYet,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize:   16,
                fontWeight: FontWeight.w800,
                color:      AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noReportsSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize:   13,
                color:      AppColors.textSecondary,
                height:     1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single report card for the history list
// ─────────────────────────────────────────────────────────────────────────────

class _ReportHistoryCard extends StatelessWidget {
  final UserReport       report;
  final AppLocalizations l10n;
  const _ReportHistoryCard({required this.report, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: category + status ──────────────────────────────
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    report.category.isNotEmpty
                        ? report.category
                        : report.reportType,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.darkText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _ReportStatusBadge(status: report.status, l10n: l10n),
              ],
            ),
          ),

          // ── Description ───────────────────────────────────────────
          if (report.description.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 10),
              child: Text(
                report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign:     TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize:   12.5,
                  color:      AppColors.body,
                  height:     1.5,
                ),
              ),
            ),

          // ── Admin reply preview ────────────────────────────────────
          if (report.adminReply != null) ...[
            Container(
              margin: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25),
                    width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.messageSquare,
                          size: 13, color: AppColors.success),
                      const SizedBox(width: 5),
                      Text(
                        l10n.adminReply,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.adminReply!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize:   12.5,
                      color:      AppColors.darkText,
                      height:     1.45,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 14),

          // ── Footer: date + tap hint ────────────────────────────────
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 10),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
            ),
            child: Row(
              children: [
                Text(
                  formatShortDate(report.createdAt, Localizations.localeOf(context).languageCode),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize:   11,
                    color:      AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                // Subtle "tap to view" hint
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.viewDetails,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? LucideIcons.chevronLeft
                          : LucideIcons.chevronRight,
                      size: 12, color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge chip
// ─────────────────────────────────────────────────────────────────────────────

class _ReportStatusBadge extends StatelessWidget {
  final String           status;
  final AppLocalizations l10n;
  const _ReportStatusBadge({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'resolved'     => (l10n.statusResolved,    AppColors.success),
      'dismissed'    => (l10n.statusDismissed,   AppColors.textSecondary),
      'under_review' => (l10n.statusUnderReview, AppColors.info),
      _              => (l10n.statusPending,      AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize:   11,
          fontWeight: FontWeight.w700,
          color:      color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize:   14,
        fontWeight: FontWeight.w700,
        color:      AppColors.darkText,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category option data class
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryOption {
  final String   value;
  final IconData icon;
  const _CategoryOption({required this.value, required this.icon});
}

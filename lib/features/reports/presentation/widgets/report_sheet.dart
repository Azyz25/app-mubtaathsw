import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mubtaath/core/l10n/app_localizations.dart';
import 'package:mubtaath/core/theme/app_colors.dart';
import 'package:mubtaath/features/reports/presentation/cubit/report_cubit.dart';

/// Bottom sheet for reporting a user or a specific chat message.
///
/// Usage — report a user:
///   showReportUserSheet(context, userId: uid, roomId: roomId);
///
/// Usage — report a message:
///   showReportMessageSheet(context, userId: uid, roomId: roomId, messageContent: text);
void showReportUserSheet(
  BuildContext context, {
  required int userId,
  String? roomId,
}) {
  _showSheet(
    context,
    userId: userId,
    roomId: roomId,
    messageContent: null,
  );
}

void showReportMessageSheet(
  BuildContext context, {
  required int userId,
  required String messageContent,
  String? roomId,
}) {
  _showSheet(
    context,
    userId: userId,
    roomId: roomId,
    messageContent: messageContent,
  );
}

void _showSheet(
  BuildContext context, {
  required int userId,
  required String? roomId,
  required String? messageContent,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => ReportCubit(),
      child: _ReportSheet(
        userId: userId,
        roomId: roomId,
        messageContent: messageContent,
      ),
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final int userId;
  final String? roomId;
  final String? messageContent;

  const _ReportSheet({
    required this.userId,
    required this.roomId,
    required this.messageContent,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selectedCategory;
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _isMessageReport => widget.messageContent != null;

  List<_CategoryOption> _categories(AppLocalizations l10n) => [
        _CategoryOption(value: l10n.categoryInappropriate, icon: LucideIcons.alertOctagon),
        _CategoryOption(value: l10n.categorySpam, icon: LucideIcons.ban),
        _CategoryOption(value: l10n.categoryComplaint, icon: LucideIcons.alertTriangle),
      ];

  Future<void> _submit(BuildContext context, AppLocalizations l10n) async {
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

    final cubit = context.read<ReportCubit>();

    if (_isMessageReport) {
      await cubit.reportMessage(
        reportedUserId: widget.userId,
        messageContent: widget.messageContent!,
        category: _selectedCategory!,
        roomId: widget.roomId,
      );
    } else {
      await cubit.reportUser(
        reportedUserId: widget.userId,
        category: _selectedCategory!,
        description: _descController.text.trim(),
        roomId: widget.roomId,
      );
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = _categories(l10n);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return BlocConsumer<ReportCubit, ReportState>(
      listener: (context, state) {
        if (state.status == ReportStatus.success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.reportSentSuccess,
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        } else if (state.status == ReportStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage ?? l10n.reportSentError,
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      },
      builder: (context, state) {
        final isSending = state.status == ReportStatus.sending;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ──────────────────────────────────────────
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.flag,
                          color: AppColors.error, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isMessageReport ? l10n.reportMessage : l10n.reportUser,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Message preview (message reports only) ───────────────
                if (_isMessageReport) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder, width: 1.2),
                    ),
                    child: Text(
                      widget.messageContent!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Category label ───────────────────────────────────────
                Text(
                  l10n.selectCategory,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Category chips ───────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final selected = _selectedCategory == cat.value;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.error
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppColors.error
                                : AppColors.cardBorder,
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 14,
                              color: selected ? Colors.white : AppColors.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.value,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppColors.darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── Description field ────────────────────────────────────
                Text(
                  l10n.describeIssue,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: l10n.describeIssueHint,
                    hintStyle: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.cardBorder, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.cardBorder, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.6),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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

                const SizedBox(height: 24),

                // ── Submit button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        isSending ? null : () => _submit(context, l10n),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      disabledBackgroundColor:
                          AppColors.error.withValues(alpha: 0.50),
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            l10n.submitReport,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryOption {
  final String value;
  final IconData icon;
  const _CategoryOption({required this.value, required this.icon});
}

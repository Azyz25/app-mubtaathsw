import 'package:flutter/material.dart';
import 'package:mubtaath/core/theme/app_colors.dart';

/// Displays a single remote participant identified only by their Agora UID.
/// Replace the UID-based avatar seed with a real display name / avatar URL
/// once the backend maps Agora UIDs to user profiles.
class SpeakerTile extends StatelessWidget {
  final int uid;

  const SpeakerTile({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.8,
            ),
          ),
          child: const Icon(Icons.person, color: AppColors.primary, size: 30),
        ),
        const SizedBox(height: 6),
        Text(
          'UID $uid',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

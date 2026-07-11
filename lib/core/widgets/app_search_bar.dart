// Canonical search bar — directional (RTL/LTR) via EdgeInsetsDirectional.
// textDirection and textAlign.right purged; direction inferred from locale.

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AppSearchBar extends StatefulWidget {
  final String                  hintText;
  final ValueChanged<String>    onChanged;
  final VoidCallback?           onClear;
  final TextEditingController?  controller;
  final String                  initialQuery;

  const AppSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.controller,
    this.initialQuery = '',
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _ctrl;
  bool _ownsController = false;
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
      _ownsController = false;
    } else {
      _ctrl = TextEditingController(text: widget.initialQuery);
      _ownsController = true;
    }
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    if (_ownsController) _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF305544).withValues(alpha: _focused ? 1.0 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF305544).withValues(alpha: _focused ? 0.12 : 0.05),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TextField(
          controller:  _ctrl,
          focusNode:   _focus,
          // textAlign.start + no explicit textDirection → follows ambient locale
          textAlign:   TextAlign.start,
          cursorColor: const Color(0xFF305544),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize:   14,
            fontWeight: FontWeight.w500,
            color:      Color(0xFF051C16),
          ),
          onChanged: (val) {
            setState(() {});
            widget.onChanged(val);
          },
          decoration: InputDecoration(
            hintText:  widget.hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize:   14,
              fontWeight: FontWeight.w400,
              color:      Colors.grey,
            ),
            filled:         true,
            fillColor:      Colors.white,
            border:         InputBorder.none,
            enabledBorder:  InputBorder.none,
            focusedBorder:  InputBorder.none,
            contentPadding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            // EdgeInsetsDirectional: start = right in RTL, left in LTR
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
              child: Icon(
                LucideIcons.search,
                size:  20,
                color: const Color(0xFF305544).withValues(alpha: _focused ? 1.0 : 0.5),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            suffixIcon: _ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _ctrl.clear();
                      widget.onChanged('');
                      widget.onClear?.call();
                      setState(() {});
                    },
                    child: const Padding(
                      padding: EdgeInsetsDirectional.only(end: 12, start: 8),
                      child: Icon(LucideIcons.x, size: 18, color: Colors.grey),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AnimatedDayItem extends StatelessWidget {
  const AnimatedDayItem({
    super.key,
    required this.header,
    required this.editor,
  });
  final Widget header;
  final Widget? editor;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header,
      if (MediaQuery.disableAnimationsOf(context))
        editor ?? const SizedBox(width: double.infinity)
      else
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          alignment: Alignment.topCenter,
          curve: Curves.easeInOutCubic,
          child: editor ?? const SizedBox(width: double.infinity),
        ),
    ],
  );
}

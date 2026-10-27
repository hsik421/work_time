import 'dart:math';

import 'package:flutter/material.dart';

final _random = Random();
const saveSuccessImages = [
  'assets/save_success/1.png',
  'assets/save_success/2.png',
  'assets/save_success/3.png',
  'assets/save_success/4.png',
];

void showSaveSuccessOverlay(
  OverlayState overlay, {
  required bool reduceMotion,
}) {
  final asset = saveSuccessImages[_random.nextInt(saveSuccessImages.length)];
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => SaveSuccessOverlay(
      imageAsset: asset,
      reduceMotion: reduceMotion,
      onComplete: () {
        entry.remove();
        entry.dispose();
      },
    ),
  );
  overlay.insert(entry);
}

class SaveSuccessOverlay extends StatefulWidget {
  const SaveSuccessOverlay({
    super.key,
    required this.imageAsset,
    required this.reduceMotion,
    required this.onComplete,
  });
  final String imageAsset;
  final bool reduceMotion;
  final VoidCallback onComplete;
  @override
  State<SaveSuccessOverlay> createState() => _SaveSuccessOverlayState();
}

class _SaveSuccessOverlayState extends State<SaveSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    animationBehavior: AnimationBehavior.preserve,
  );
  @override
  void initState() {
    super.initState();
    _rotation.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
    _rotation.forward();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(color: Color(0x80000000), dismissible: false),
        Center(
          child: Semantics(
            label: '저장 완료',
            liveRegion: true,
            child: FractionallySizedBox(
              widthFactor: 0.55,
              heightFactor: 0.55,
              child: Center(
                child: RotationTransition(
                  turns:
                      widget.reduceMotion ||
                          MediaQuery.disableAnimationsOf(context)
                      ? const AlwaysStoppedAnimation(0.0)
                      : _rotation,
                  child: Image.asset(
                    widget.imageAsset,
                    width: 210,
                    height: 210,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

class StatBar extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final clampedFraction = fraction.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(value, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clampedFraction,
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }
}

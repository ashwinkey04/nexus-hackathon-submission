import 'package:flutter/material.dart';

class NexusTopBar extends StatelessWidget {
  final bool isBusy;
  final String statusMessage;
  final Color cardDark;
  final Color accentGreen;

  const NexusTopBar({
    super.key,
    required this.isBusy,
    required this.statusMessage,
    required this.cardDark,
    required this.accentGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CircleAvatar(
          backgroundColor: cardDark,
          child: const Icon(Icons.menu, color: Colors.white),
        ),
        // Status Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isBusy ? Colors.amber : accentGreen.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isBusy ? Colors.amber : accentGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

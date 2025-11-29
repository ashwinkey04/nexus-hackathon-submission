import 'package:flutter/material.dart';

class NexusNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final VoidCallback onFabTap;
  final bool isBusy;
  final Color cardDark;
  final Color accentGreen;

  const NexusNavBar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onFabTap,
    required this.isBusy,
    required this.cardDark,
    required this.accentGreen,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: cardDark,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.home_filled,
                  color: selectedIndex == 0 ? accentGreen : Colors.grey),
              onPressed: () => onIndexChanged(0),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.grey),
              onPressed: () => onIndexChanged(1),
            ),
            const SizedBox(width: 40), // Space for FAB
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
              onPressed: () => onIndexChanged(2),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.grey),
              onPressed: () => onIndexChanged(3),
            ),
          ],
        ),
      ),
    );
  }
}


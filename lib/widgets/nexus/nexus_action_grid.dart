import 'package:flutter/material.dart';

class NexusActionGrid extends StatelessWidget {
  final Color accentGreen;
  final Color accentPaleGreen;
  final Color accentPurple;
  final VoidCallback onChatTap;
  final VoidCallback onSearchTap;
  final VoidCallback onManageTap;

  const NexusActionGrid({
    super.key,
    required this.accentGreen,
    required this.accentPaleGreen,
    required this.accentPurple,
    required this.onChatTap,
    required this.onSearchTap,
    required this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Big Left Card (Chat - Promoted)
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: onChatTap,
            child: Container(
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accentGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline,
                        color: Colors.black, size: 24),
                  ),
                  const Text(
                    'Chat\nwith\nNexus',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right Column
        Expanded(
          flex: 1,
          child: Column(
            children: [
              // Top Right Card (Search)
              GestureDetector(
                onTap: onSearchTap,
                child: Container(
                  height: 82,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentPaleGreen,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.search, color: Colors.black),
                      Flexible(
                        child: Text(
                          'Search\nDocs',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bottom Right Card (Manage Knowledge)
              GestureDetector(
                onTap: onManageTap,
                child: Container(
                  height: 82,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentPurple,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.edit_note, color: Colors.black),
                      Flexible(
                        child: Text(
                          'Manage\nKnowledge',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

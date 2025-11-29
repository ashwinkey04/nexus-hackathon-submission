import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart'; // For DatabaseStats

class NexusRecentActivity extends StatelessWidget {
  final DatabaseStats? dbStats;
  final Color cardDark;
  final Color accentPurple;
  final Color accentGreen;
  final VoidCallback onViewAllTap;

  const NexusRecentActivity({
    super.key,
    required this.dbStats,
    required this.cardDark,
    required this.accentPurple,
    required this.accentGreen,
    required this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Knowledge Base (${dbStats?.totalDocuments ?? 0} docs)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: onViewAllTap,
              child: Text(
                'View All',
                style: TextStyle(color: accentGreen),
              ),
            ),
          ],
        ),
        // Recent List
        if (dbStats != null && dbStats!.totalDocuments > 0)
          _buildRecentItem(
            icon: Icons.description_outlined,
            color: accentPurple,
            title: 'Recent Document',
            subtitle: 'Tap "Manage Knowledge" to see all',
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Text(
              'No documents yet. Add some!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.more_horiz, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}


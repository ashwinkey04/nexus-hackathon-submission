import 'package:flutter/material.dart';

class ManageKnowledgeSheet extends StatelessWidget {
  final Color cardDark;
  final Color accentGreen;
  final Color accentPurple;
  final VoidCallback onUploadTap;
  final VoidCallback onPasteTap;
  final VoidCallback onClearTap;
  final VoidCallback onLoadDemoDataTap;
  final VoidCallback onReloadDemoDataTap;

  const ManageKnowledgeSheet({
    super.key,
    required this.cardDark,
    required this.accentGreen,
    required this.accentPurple,
    required this.onUploadTap,
    required this.onPasteTap,
    required this.onClearTap,
    required this.onLoadDemoDataTap,
    required this.onReloadDemoDataTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Manage Knowledge',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.upload_file, color: accentGreen),
            ),
            title: const Text('Upload File',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('PDF, TXT, or MD',
                style: TextStyle(color: Colors.grey)),
            onTap: onUploadTap,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: accentPurple.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.paste, color: accentPurple),
            ),
            title:
                const Text('Paste Text', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Manually add content',
                style: TextStyle(color: Colors.grey)),
            onTap: onPasteTap,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_download, color: Colors.blueAccent),
            ),
            title: const Text('Load Demo Data',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Load sample LinkedIn posts (cached locally)',
                style: TextStyle(color: Colors.grey)),
            onTap: onLoadDemoDataTap,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.refresh, color: Colors.orangeAccent),
            ),
            title: const Text('Reload Demo Data',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Force refresh from API',
                style: TextStyle(color: Colors.grey)),
            onTap: onReloadDemoDataTap,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            title: const Text('Clear All Data',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Remove all documents',
                style: TextStyle(color: Colors.grey)),
            onTap: onClearTap,
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';

class PasteTextDialog extends StatefulWidget {
  final Color cardDark;
  final Color accentGreen;
  final Function(String title, String content) onSave;

  const PasteTextDialog({
    super.key,
    required this.cardDark,
    required this.accentGreen,
    required this.onSave,
  });

  @override
  State<PasteTextDialog> createState() => _PasteTextDialogState();
}

class _PasteTextDialogState extends State<PasteTextDialog> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Text Content',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Title (e.g., Meeting Notes)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[800]!)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: widget.accentGreen)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 6,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Paste or type your content here...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[800]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[800]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentGreen),
                ),
                filled: true,
                fillColor: Colors.black26,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentGreen,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    if (titleController.text.isEmpty ||
                        contentController.text.isEmpty) return;
                    widget.onSave(titleController.text, contentController.text);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class UpdateService {
  final String currentVersion = "1.0.0"; // Change this whenever you build a new APK

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      DocumentSnapshot config = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_info')
          .get();

      if (config.exists && config.data() != null) {
        final data = config.data() as Map<String, dynamic>;
        String latestVersion = data['latest_version'] ?? currentVersion;
        String downloadUrl = data['download_url'] ?? '';

        if (currentVersion != latestVersion && downloadUrl.isNotEmpty) {
          _showUpdateDialog(context, downloadUrl, latestVersion);
        }
      }
    } catch (e) {
      debugPrint('Update Check Error: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, String url, String version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ChatTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: ChatTheme.primary),
            const SizedBox(width: 10),
            Text('Update to v$version'),
          ],
        ),
        content: const Text(
          'We have added new features and fixed bugs to make your chat experience smoother!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: ChatTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final Uri uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ChatTheme.primary, foregroundColor: Colors.black),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}

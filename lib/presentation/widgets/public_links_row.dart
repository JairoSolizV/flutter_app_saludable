import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/public_links.dart';
import '../../core/theme/app_theme.dart';

class PublicLinksRow extends StatelessWidget {
  const PublicLinksRow({super.key});

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        TextButton(
          onPressed: () => _open(PublicLinks.privacy),
          child: const Text(
            'Privacidad',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
        ),
        const Text('•', style: TextStyle(color: Colors.grey)),
        TextButton(
          onPressed: () => _open(PublicLinks.support),
          child: const Text(
            'Soporte',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }
}

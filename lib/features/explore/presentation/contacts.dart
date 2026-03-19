import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  static const routeName = 'contacts';
  static const routePath = '/contacts';

  static final Uri _xUrl = Uri.parse(
    'https://x.com/run_edu?t=fPjrpFVpSlAUUKxVKm7fEQ&s=09',
  );
  static final Uri _instagramUrl =
      Uri.parse('https://instagram.com/redeemersuniversity');
  static final Uri _youtubeUrl =
      Uri.parse('https://www.youtube.com/c/RedeemersUniversity');
  static final Uri _linkedInUrl =
      Uri.parse('https://ng.linkedin.com/school/redeemersuniversity/');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── University Logo ──────────────────────────────────────────
          Center(
            child: ClipOval(
              child: Image.asset(
                'assets/images/run_logo.jpg',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Emergency Contacts ──────────────────────────────────────
          Text(
            'Contacts',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.runBlue,
            ),
          ),
          const SizedBox(height: 12),
          _EmergencyContactTile(
            name: 'University Security',
            phone: '+234 800 000 0001',
            icon: Icons.security,
          ),
          _EmergencyContactTile(
            name: 'Health Centre',
            phone: '+234 800 000 0002',
            icon: Icons.local_hospital,
          ),
          _EmergencyContactTile(
            name: 'Student Affairs',
            phone: '+234 800 000 0003',
            icon: Icons.school,
          ),
          _EmergencyContactTile(
            name: 'Fire Service',
            phone: '+234 800 000 0004',
            icon: Icons.fire_truck,
          ),
          _EmergencyContactTile(
            name: 'Counselling Unit',
            phone: '+234 800 000 0005',
            icon: Icons.support_agent,
          ),
          const SizedBox(height: 28),

          // ── School Handles ───────────────────────────────────────────
          Text(
            'School Handles',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.runBlue,
            ),
          ),
          const SizedBox(height: 12),
          _HandleTile(
            label: 'X (Twitter)',
            subtitle: 'run_edu',
            icon: Icons.alternate_email,
            url: _xUrl,
          ),
          _HandleTile(
            label: 'Instagram',
            subtitle: '@redeemersuniversity',
            icon: Icons.camera_alt_outlined,
            url: _instagramUrl,
          ),
          _HandleTile(
            label: 'YouTube',
            subtitle: 'Redeemer\'s University',
            icon: Icons.play_circle_outline,
            url: _youtubeUrl,
          ),
          _HandleTile(
            label: 'LinkedIn',
            subtitle: 'Redeemer\'s University',
            icon: Icons.business_center_outlined,
            url: _linkedInUrl,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EmergencyContactTile extends StatelessWidget {
  const _EmergencyContactTile({
    required this.name,
    required this.phone,
    required this.icon,
  });

  final String name;
  final String phone;
  final IconData icon;

  Future<void> _callNumber(BuildContext context) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.runBlue),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(phone),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: () => _callNumber(context),
        ),
        onTap: () => _callNumber(context),
      ),
    );
  }
}

class _HandleTile extends StatelessWidget {
  const _HandleTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.url,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Uri url;

  Future<void> _openLink(BuildContext context) async {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $label')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.runBlue),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new, size: 20),
        onTap: () => _openLink(context),
      ),
    );
  }
}


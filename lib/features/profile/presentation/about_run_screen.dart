import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

class AboutRunScreen extends StatelessWidget {
  const AboutRunScreen({super.key});

  static const routeName = 'about-run';
  static const routePath = '/about-run';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About RUN'),
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

          // ── History ──────────────────────────────────────────────────
          Text(
            'History',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.runBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Redeemer's University (RUN) is a private Christian university "
            "located in Ede, Osun State, Nigeria. Founded in 2005 by the "
            "Redeemed Christian Church of God (RCCG), the university is "
            "committed to raising a new generation of leaders who are "
            "morally upright, intellectually sound, and technologically "
            "proficient.\n\n"
            "The university offers undergraduate and postgraduate programmes "
            "across multiple faculties including Natural Sciences, Management "
            "Sciences, Humanities, Engineering, Law, and Environmental Sciences. "
            "RUN prides itself on academic excellence, a serene learning "
            "environment, and strong moral values.\n\n"
            "With a growing community of students, faculty, and alumni, "
            "Redeemer's University continues to make significant contributions "
            "to research, community development, and national progress.",
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 32),

          // ── Emergency Contacts ──────────────────────────────────────
          Text(
            'Emergency Contacts',
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

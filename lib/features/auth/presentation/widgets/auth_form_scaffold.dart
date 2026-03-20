import 'package:flutter/material.dart';

/// Shared scaffold layout for auth screens (login, fresher sign-in, etc.).
/// Provides consistent SafeArea, SingleChildScrollView, and padding.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Shared card layout for auth form content.
/// Provides consistent padding for form fields.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: child,
      ),
    );
  }
}

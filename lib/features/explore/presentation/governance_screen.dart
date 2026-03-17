import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../data/governance_html_repository.dart';

/// Asset key for the bundled Governance page. Using [loadFlutterAsset] lets
/// relative paths like ./Governance_files/*.css resolve from the asset bundle.
const String _kGovernanceAssetKey = 'assets/webpages/Governance.html';

class GovernanceScreen extends StatefulWidget {
  const GovernanceScreen({super.key});

  static const routeName = 'governance';
  static const routePath = '/governance';

  @override
  State<GovernanceScreen> createState() => _GovernanceScreenState();
}

class _GovernanceScreenState extends State<GovernanceScreen> {
  late final WebViewController _controller;
  late final GovernanceHtmlRepository _repository;

  /// True only after content has loaded and cleanup CSS has been injected.
  /// Keeps the WebView hidden until then so users never see elements being removed.
  bool _contentReady = false;

  @override
  void initState() {
    super.initState();
    _repository = GovernanceHtmlRepository();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (_) {},
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _onPageFinished(),
          onNavigationRequest: (req) {
            if (req.url.startsWith('https://run.edu.ng/')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    // 1) Load bundled HTML via loadFlutterAsset so ./Governance_files/* resolves.
    _controller.loadFlutterAsset(_kGovernanceAssetKey).catchError((_) async {
      try {
        final html = await rootBundle.loadString(_kGovernanceAssetKey);
        if (!mounted) return;
        await _controller.loadHtmlString(html);
        await _injectCleanupCSS();
        if (mounted) setState(() => _contentReady = true);
      } catch (_) {}
    });

    // 2) Quietly refresh from live site in background.
    _refreshFromNetworkSilently();
  }

  /// Runs after page load: inject cleanup CSS, then reveal content to the user.
  Future<void> _onPageFinished() async {
    await _injectCleanupCSS();
    if (mounted) setState(() => _contentReady = true);
  }

  /// Injects CSS to hide sidebar, header, footer, Calendly badge, etc.
  Future<void> _injectCleanupCSS() {
    return _controller.runJavaScript('''
      (function() {
        if (!document.head) return;
        var style = document.createElement('style');
        style.textContent = [
          '#menu-1-3fd610bc { display: none !important; }',
          '.elementor-nav-menu { display: none !important; }',
          '.elementor-widget-nav-menu { display: none !important; }',
          '.d-button { display: none !important; }',
          'header.site-header { display: none !important; }',
          'footer.site-footer { display: none !important; }',
          '.pum-overlay, #cookie-law-info-bar { display: none !important; }',
          '.calendly-badge-widget { display: none !important; }',
        ].join('');
        document.head.appendChild(style);
      })();
    ''');
  }

  /// Fetches the latest HTML in the background. On success: hide, swap content,
  /// inject cleanup, then reveal. User never sees the raw page or elements being removed.
  Future<void> _refreshFromNetworkSilently() async {
    final html = await _repository.fetchLatestHtml();
    if (!mounted || html == null) return;

    setState(() => _contentReady = false);
    await _controller.loadHtmlString(html);
    // onPageFinished will run cleanup and set _contentReady = true
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Governance'),
        backgroundColor: AppTheme.runBlue,
        foregroundColor: Colors.white,
      ),
      body: Opacity(
        opacity: _contentReady ? 1.0 : 0.0,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

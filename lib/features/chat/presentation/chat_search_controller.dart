import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/message.dart';

/// Holds the result of a single search operation.
///
/// [matchIndexes] contains absolute indexes into the chronologically-ascending
/// messages list. Index 0 = oldest message (visual top), last = newest (visual
/// bottom). [currentMatchIndex] is an index *into* [matchIndexes], not into the
/// messages list directly — use [currentAbsoluteIndex] for the latter.
class ChatSearchController extends ChangeNotifier {
  bool _isActive = false;
  String _query = '';

  /// Indexes into the messages list (ascending = oldest-first order).
  List<int> _matchIndexes = [];

  /// Pointer into [_matchIndexes]. -1 means no active match.
  int _currentMatchIndex = -1;

  Timer? _debounce;

  // ── Public read-only state ─────────────────────────────────────────────────

  bool get isActive => _isActive;

  /// The normalised (trimmed, lowercase) query string used for matching.
  String get query => _query;

  List<int> get matchIndexes => List.unmodifiable(_matchIndexes);

  int get currentMatchIndex => _currentMatchIndex;

  int get totalMatches => _matchIndexes.length;

  /// The absolute index into the messages list for the currently-focused match.
  /// Returns -1 when there is no active match.
  int get currentAbsoluteIndex =>
      (_currentMatchIndex >= 0 && _matchIndexes.isNotEmpty)
          ? _matchIndexes[_currentMatchIndex]
          : -1;

  /// Human-readable counter, e.g. "3/10" or "0/0".
  String get counterText {
    if (!_isActive || _query.isEmpty) return '';
    if (_matchIndexes.isEmpty) return '0/0';
    return '${_currentMatchIndex + 1}/${_matchIndexes.length}';
  }

  bool get hasNoResults => _isActive && _query.isNotEmpty && _matchIndexes.isEmpty;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Enter search mode. Call when the user taps the search icon.
  void activate() {
    _isActive = true;
    _query = '';
    _matchIndexes = [];
    _currentMatchIndex = -1;
    notifyListeners();
  }

  /// Exit search mode and reset all state. Call when the user dismisses search.
  void deactivate() {
    _debounce?.cancel();
    _isActive = false;
    _query = '';
    _matchIndexes = [];
    _currentMatchIndex = -1;
    notifyListeners();
  }

  // ── Query handling ─────────────────────────────────────────────────────────

  /// Called on every keystroke. Debounces 300 ms before running the O(n) scan.
  void onQueryChanged(String rawQuery, List<ChatMessage> messages) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _computeMatches(rawQuery.trim().toLowerCase(), messages);
    });
  }

  /// Refreshes match indexes when the messages list itself changes (new
  /// messages arrive) while search is still active. Called without debounce
  /// because the query hasn't changed — only the dataset has.
  void refreshMatches(List<ChatMessage> messages) {
    if (!_isActive || _query.isEmpty) return;
    _computeMatches(_query, messages);
  }

  void _computeMatches(String normalisedQuery, List<ChatMessage> messages) {
    _query = normalisedQuery;

    if (_query.isEmpty) {
      _matchIndexes = [];
      _currentMatchIndex = -1;
      notifyListeners();
      return;
    }

    final newMatches = <int>[];
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].content.toLowerCase().contains(_query)) {
        newMatches.add(i);
      }
    }

    // Try to preserve the focused message across refreshes. If the previously
    // focused absolute index still has a match, keep it selected.
    final previousAbsolute = currentAbsoluteIndex;
    _matchIndexes = newMatches;

    if (_matchIndexes.isEmpty) {
      _currentMatchIndex = -1;
    } else {
      final preserved = _matchIndexes.indexOf(previousAbsolute);
      if (preserved >= 0) {
        // Keep the same message focused.
        _currentMatchIndex = preserved;
      } else {
        // Default: jump to the most recent (visually lowest) match.
        _currentMatchIndex = _matchIndexes.length - 1;
      }
    }

    notifyListeners();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Move to the next (older / visually higher) match.
  /// Down arrow (↓) in the AppBar corresponds to this.
  void nextMatch() {
    if (_matchIndexes.isEmpty) return;
    // Decrement wraps from 0 → last (i.e. jumps to the oldest match).
    _currentMatchIndex =
        (_currentMatchIndex - 1 + _matchIndexes.length) % _matchIndexes.length;
    notifyListeners();
  }

  /// Move to the previous (newer / visually lower) match.
  /// Up arrow (↑) in the AppBar corresponds to this.
  void previousMatch() {
    if (_matchIndexes.isEmpty) return;
    // Increment wraps from last → 0 (i.e. jumps to the newest match).
    _currentMatchIndex =
        (_currentMatchIndex + 1) % _matchIndexes.length;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

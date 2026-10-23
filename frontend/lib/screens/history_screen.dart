import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/tts_service.dart';
import '../models/conversation.dart';
import '../widgets/connectivity_badge.dart';
import '../widgets/history_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Conversation> _history = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreHistory = true;
  String? _loadError;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _hasMoreHistory = true;
    });
    try {
      final history = await DatabaseHelper.instance.getHistory(limit: 50);
      if (mounted) {
        setState(() {
          _history = history;
          _hasMoreHistory = history.length == 50;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreHistory();
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || !_hasMoreHistory) return;
    setState(() => _isLoadingMore = true);
    try {
      final moreHistory = await DatabaseHelper.instance.getHistory(
        limit: 50,
        offset: _history.length,
      );
      if (mounted) {
        setState(() {
          _history.addAll(moreHistory);
          _hasMoreHistory = moreHistory.length == 50;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load more history: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    await _loadHistory();
  }

  Future<void> _speakConversation(Conversation conversation) async {
    try {
      await context.read<TtsService>().speak(conversation.text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play speech: $error')),
        );
      }
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    if (conversation.id != null) {
      await DatabaseHelper.instance.deleteConversation(conversation.id!);
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation History'),
        actions: [const ConnectivityBadge(), const SizedBox(width: 16)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load history: $_loadError'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadHistory,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _history.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _history.length + (_hasMoreHistory ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _history.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _isLoadingMore
                            ? const CircularProgressIndicator()
                            : const SizedBox.shrink(),
                      ),
                    );
                  }
                  final conversation = _history[index];
                  return Dismissible(
                    key: ValueKey(conversation.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: theme.colorScheme.errorContainer,
                      child: Icon(
                        Icons.delete,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete'),
                          content: Text('Delete "${conversation.text}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) => _deleteConversation(conversation),
                    child: HistoryTile(
                      conversation: conversation,
                      onSpeak: () => _speakConversation(conversation),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No history yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Translate a sign or speech and tap Save to see it here',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

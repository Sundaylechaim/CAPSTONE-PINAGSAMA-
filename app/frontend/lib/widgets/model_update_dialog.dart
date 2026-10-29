import 'package:flutter/material.dart';
import '../../services/model_updater.dart';

class ModelUpdateDialog extends StatefulWidget {
  final ModelUpdater modelUpdater;
  final VoidCallback? onUpdateComplete;

  const ModelUpdateDialog({
    super.key,
    required this.modelUpdater,
    this.onUpdateComplete,
  });

  @override
  State<ModelUpdateDialog> createState() => _ModelUpdateDialogState();
}

class _ModelUpdateDialogState extends State<ModelUpdateDialog> {
  ModelUpdateInfo? _updateInfo;
  Stream<ModelUpdateInfo>? _downloadStream;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final info = await widget.modelUpdater.checkForUpdates();
    if (!mounted) return;
    setState(() {
      _updateInfo = info;
    });

    if (info.status == UpdateStatus.updateAvailable) {
      _startDownload(info);
    }
  }

  void _startDownload(ModelUpdateInfo info) {
    _downloadStream = widget.modelUpdater.downloadUpdate(info);
    _downloadStream!.listen(
      (update) {
        if (!mounted) return;
        setState(() {
          _updateInfo = update;
        });
        if (update.status == UpdateStatus.upToDate && update.progress >= 1.0) {
          widget.onUpdateComplete?.call();
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _updateInfo = info.copyWith(status: UpdateStatus.error);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _updateInfo;

    if (info == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AlertDialog(
      title: const Text('Model Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current version: ${info.version}'),
          const SizedBox(height: 16),
          if (info.status == UpdateStatus.upToDate && info.progress < 1.0) ...[
            const Text('Model is up to date'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ] else if (info.status == UpdateStatus.updateAvailable) ...[
            const Text('Update available! Downloading...'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: info.progress),
            const SizedBox(height: 8),
            Text('${(info.progress * 100).toInt()}%'),
          ] else if (info.status == UpdateStatus.downloading) ...[
            const Text('Downloading update...'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: info.progress),
            const SizedBox(height: 8),
            Text('${(info.progress * 100).toInt()}%'),
          ] else if (info.status == UpdateStatus.error) ...[
            const Text('Failed to check for updates'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkForUpdates,
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    return StreamBuilder<ConnectivityStatus>(
      initialData: connectivity.currentStatus,
      stream: connectivity.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectivityStatus.checking;
        final isOnline = status == ConnectivityStatus.online;
        final isChecking = status == ConnectivityStatus.checking;
        final isOffline = status == ConnectivityStatus.offline;
        final color = isOnline
            ? Colors.green
            : isOffline
            ? Colors.orange
            : Colors.grey;
        final label = isChecking
            ? 'Checking'
            : isOnline
            ? 'Connected'
            : isOffline
            ? 'No connection'
            : 'Unknown';

        return Tooltip(
          message: connectivity.lastError ?? label,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline
                      ? Icons.wifi
                      : isOffline
                      ? Icons.wifi_off
                      : Icons.wifi_find,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

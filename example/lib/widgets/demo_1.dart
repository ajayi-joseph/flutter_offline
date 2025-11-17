import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_offline/flutter_offline.dart';

class Demo1 extends StatefulWidget {
  const Demo1({Key? key}) : super(key: key);

  @override
  State<Demo1> createState() => _Demo1State();
}

class _Demo1State extends State<Demo1> {
  OfflineBuilderState? _offlineBuilderState;
  bool _isConnected = true; // Track connection state
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {}); // Refresh UI to update button state
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBuilder(
      maxRetries: 5,
      retryCooldown: const Duration(seconds: 2),
      onRetry: () async {
        // Custom retry logic can be added here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retrying connectivity check...'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      onBuilderReady: (state) {
        _offlineBuilderState = state;
      },
      connectivityBuilder: (
        BuildContext context,
        List<ConnectivityResult> connectivity,
        Widget child,
      ) {
        final connected = !connectivity.contains(ConnectivityResult.none);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isConnected != connected) {
            setState(() {
              _isConnected = connected;
            });
          }
        });

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              height: 32.0,
              left: 0.0,
              right: 0.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                color: connected
                    ? const Color(0xFF00EE44)
                    : const Color(0xFFEE4400),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: connected
                      ? const Text('ONLINE')
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('OFFLINE'),
                            const SizedBox(width: 8.0),
                            if (_offlineBuilderState?.isRetrying == true) ...[
                              const SizedBox(width: 8.0),
                              const Text('RETRYING...'),
                            ] else ...[
                              const SizedBox(
                                width: 12.0,
                                height: 12.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Enhanced Demo with Retry Functionality',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Turn off your internet to see the offline state.',
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: !_isConnected &&
                        _offlineBuilderState?.canRetry == true &&
                        _offlineBuilderState?.isRetrying == false
                    ? () async {
                        setState(() {}); // Force UI refresh before retry
                        await _offlineBuilderState?.retry();
                        _startCooldownTimer(); // Start timer to refresh UI
                        setState(() {}); // Refresh UI after retry
                      }
                    : null,
                icon: _offlineBuilderState?.isRetrying == true
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_offlineBuilderState?.isRetrying == true
                    ? 'Retrying...'
                    : 'Retry Connection'),
              ),
              const SizedBox(height: 8),
              Text(
                'Retry attempts: ${_offlineBuilderState?.retryCount ?? 0}/5',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              if (!_isConnected) ...[
                if (_offlineBuilderState?.isRetrying == true)
                  Text(
                    'Retrying (delay: ${1 << (_offlineBuilderState?.retryCount ?? 0)}s)...',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  )
                else if (_offlineBuilderState?.retryCount == 5)
                  const Text(
                    'Max retries reached (5/5)',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  )
                else if (_offlineBuilderState?.canRetry == false)
                  const Text(
                    'Cooldown active (wait before next retry)',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  )
                else
                  const Text(
                    'Ready to retry',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

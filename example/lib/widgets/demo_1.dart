import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_offline/flutter_offline.dart';

class Demo1 extends StatefulWidget {
  const Demo1({Key? key}) : super(key: key);

  @override
  State<Demo1> createState() => _Demo1State();
}

class _Demo1State extends State<Demo1> {
  final GlobalKey<OfflineBuilderState> _offlineKey = GlobalKey<OfflineBuilderState>();
  late final RetryController _retryController;
  bool _isConnected = true; // Track connection state
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _retryController = RetryController(
      onRetry: () async {
        // Custom retry logic can be added here
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Retrying connectivity check...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      onRetryError: (error, stackTrace) {
        // Handle retry errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Retry failed: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

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

        // Stop timer if we can retry again (cooldown ended)
        if (_offlineKey.currentState?.canRetry == true) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBuilder(
      key: _offlineKey,
      maxRetries: 5,
      retryCooldown: const Duration(seconds: 2),
      retryController: _retryController,
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
                color: connected ? const Color(0xFF00EE44) : const Color(0xFFEE4400),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: connected
                      ? const Text('ONLINE')
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('OFFLINE'),
                            const SizedBox(width: 8.0),
                            if (_offlineKey.currentState?.isRetrying == true) ...[
                              const SizedBox(width: 8.0),
                              const Text('RETRYING...'),
                            ] else ...[
                              const SizedBox(
                                width: 12.0,
                                height: 12.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                onPressed: !_isConnected && _offlineKey.currentState?.canRetry == true
                    ? () async {
                        setState(() {}); // Force UI refresh before retry
                        await _offlineKey.currentState?.retry();
                        _startCooldownTimer(); // Start timer to refresh UI
                        setState(() {}); // Refresh UI after retry
                      }
                    : null,
                icon: _offlineKey.currentState?.isRetrying == true
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_offlineKey.currentState?.isRetrying == true ? 'Retrying...' : 'Retry Connection'),
              ),
              const SizedBox(height: 8),
              Text(
                'Retry attempts: ${_offlineKey.currentState?.retryCount ?? 0}/5',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              if (!_isConnected) ...[
                if (_offlineKey.currentState?.isRetrying == true)
                  Text(
                    'Retrying with ${1 << (_offlineKey.currentState?.retryCount ?? 0)}s exponential backoff...',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  )
                else if (_offlineKey.currentState?.retryCount == 5)
                  const Text(
                    'Max retries reached (5/5)',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  )
                else if (!(_offlineKey.currentState?.canRetry ?? true) &&
                    (_offlineKey.currentState?.retryCount ?? 0) > 0 &&
                    !(_offlineKey.currentState?.isRetrying ?? false))
                  const Text(
                    'Cooldown active - wait 2s before next retry',
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

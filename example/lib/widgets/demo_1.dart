import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_offline/flutter_offline.dart';

class Demo1 extends StatefulWidget {
  const Demo1({Key? key}) : super(key: key);

  @override
  State<Demo1> createState() => _Demo1State();
}

class _Demo1State extends State<Demo1> {
  late final OfflineRetryController _retryController;
  bool _isConnected = true; // Track connection state
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _retryController = OfflineRetryController(
      maxRetries: 5,
      retryCooldown: const Duration(seconds: 2),
    );

    // Listen to controller changes to update UI
    _retryController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _retryController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {}); // Refresh UI to update button state

        // Stop timer if we can retry again (cooldown ended)
        if (_retryController.canRetry) {
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
                            if (_retryController.isRetrying) ...[
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
                onPressed: !_isConnected && _retryController.canRetry
                    ? () async {
                        setState(() {}); // Force UI refresh before retry
                        await _retryController.retry();
                        _startCooldownTimer(); // Start timer to refresh UI
                        setState(() {}); // Refresh UI after retry
                      }
                    : null,
                icon: _retryController.isRetrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_retryController.isRetrying ? 'Retrying...' : 'Retry Connection'),
              ),
              const SizedBox(height: 8),
              Text(
                'Retry attempts: ${_retryController.retryCount}/5',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              if (!_isConnected) ...[
                if (_retryController.isRetrying)
                  Text(
                    'Retrying with ${1 << _retryController.retryCount}s exponential backoff...',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  )
                else if (_retryController.retryCount == 5)
                  const Text(
                    'Max retries reached (5/5)',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  )
                else if (!_retryController.canRetry && _retryController.retryCount > 0 && !_retryController.isRetrying)
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

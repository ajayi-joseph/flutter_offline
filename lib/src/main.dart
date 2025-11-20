import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_offline/src/utils.dart';
import 'package:network_info_plus/network_info_plus.dart';

const kOfflineDebounceDuration = Duration(seconds: 3);
const kDefaultMaxRetries = 5;
const kDefaultRetryCooldown = Duration(seconds: 2);

typedef ValueWidgetBuilder<T> = Widget Function(BuildContext context, T value, Widget child);
typedef RetryCallback = Future<void> Function();

class OfflineBuilder extends StatefulWidget {
  factory OfflineBuilder({
    Key? key,
    required ValueWidgetBuilder<List<ConnectivityResult>> connectivityBuilder,
    Duration debounceDuration = kOfflineDebounceDuration,
    WidgetBuilder? builder,
    Widget? child,
    WidgetBuilder? errorBuilder,
    int maxRetries = kDefaultMaxRetries,
    Duration retryCooldown = kDefaultRetryCooldown,
    RetryCallback? onRetry,
    void Function(OfflineBuilderState)? onBuilderReady,
  }) {
    return OfflineBuilder.initialize(
      key: key,
      connectivityBuilder: connectivityBuilder,
      connectivityService: Connectivity(),
      wifiInfo: NetworkInfo(),
      debounceDuration: debounceDuration,
      builder: builder,
      errorBuilder: errorBuilder,
      maxRetries: maxRetries,
      retryCooldown: retryCooldown,
      onRetry: onRetry,
      onBuilderReady: onBuilderReady,
      child: child,
    );
  }

  @visibleForTesting
  const OfflineBuilder.initialize({
    Key? key,
    required this.connectivityBuilder,
    required this.connectivityService,
    required this.wifiInfo,
    this.debounceDuration = kOfflineDebounceDuration,
    this.builder,
    this.child,
    this.errorBuilder,
    this.maxRetries = kDefaultMaxRetries,
    this.retryCooldown = kDefaultRetryCooldown,
    this.onRetry,
    this.onBuilderReady,
  })  : assert(!(builder is WidgetBuilder && child is Widget) && !(builder == null && child == null),
            'You should specify either a builder or a child'),
        super(key: key);

  /// Override connectivity service used for testing
  final Connectivity connectivityService;

  final NetworkInfo wifiInfo;

  /// Debounce duration from epileptic network situations
  final Duration debounceDuration;

  /// Used for building the Offline and/or Online UI
  final ValueWidgetBuilder<List<ConnectivityResult>> connectivityBuilder;

  /// Used for building the child widget
  final WidgetBuilder? builder;

  /// The widget below this widget in the tree.
  final Widget? child;

  /// Used for building the error widget incase of any platform errors
  final WidgetBuilder? errorBuilder;

  /// Maximum number of retry attempts with exponential backoff
  final int maxRetries;

  /// Minimum duration between manual retry attempts to prevent spam
  final Duration retryCooldown;

  /// Callback function that gets executed when retry is triggered
  final RetryCallback? onRetry;

  /// Callback to get access to the OfflineBuilder state for retry functionality
  final void Function(OfflineBuilderState)? onBuilderReady;

  @override
  OfflineBuilderState createState() => OfflineBuilderState();
}

class OfflineBuilderState extends State<OfflineBuilder> {
  late Stream<List<ConnectivityResult>> _connectivityStream;

  int _retryCount = 0;
  DateTime? _lastRetryTime;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();

    _connectivityStream = Stream.fromFuture(widget.connectivityService.checkConnectivity())
        .asyncExpand((data) => widget.connectivityService.onConnectivityChanged.transform(startsWith(data)))
        .transform(debounce(widget.debounceDuration));

    // Expose state to parent widget for retry functionality
    widget.onBuilderReady?.call(this);
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Manually retry connectivity check with exponential backoff
  Future<void> retry() async {
    if (_isRetrying) {
      return;
    }

    final now = DateTime.now();
    if (_lastRetryTime != null && now.difference(_lastRetryTime!) < widget.retryCooldown) {
      return; // Still in cooldown period
    }

    if (_retryCount >= widget.maxRetries) {
      return; // Max retries exceeded
    }

    setState(() {
      _isRetrying = true;
    });

    // Set last retry time at the start
    _lastRetryTime = now;

    try {
      // Execute custom retry callback if provided
      if (widget.onRetry != null) {
        await widget.onRetry!();
      }

      // Calculate exponential backoff delay
      final delaySeconds = (1 << _retryCount); // 2^retryCount
      await Future.delayed(Duration(seconds: delaySeconds));

      // Force a connectivity check - this will trigger the stream naturally
      await widget.connectivityService.checkConnectivity();

      _retryCount++;
    } catch (e) {
      // Handle retry errors gracefully
      debugPrint('Retry failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  /// Reset retry counter when connection is restored
  void _resetRetryCounter() {
    if (_retryCount > 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _retryCount = 0;
            _lastRetryTime = null;
          });
        }
      });
    }
  }

  /// Check if retry is currently available
  bool get canRetry {
    if (_isRetrying) {
      return false;
    }
    if (_retryCount >= widget.maxRetries) {
      return false;
    }

    final now = DateTime.now();
    if (_lastRetryTime != null && now.difference(_lastRetryTime!) < widget.retryCooldown) {
      return false;
    }

    return true;
  }

  /// Get current retry count for UI display
  int get retryCount => _retryCount;

  /// Check if currently retrying for UI display
  bool get isRetrying => _isRetrying;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: _connectivityStream,
      builder: (BuildContext context, AsyncSnapshot<List<ConnectivityResult>> snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const SizedBox();
        }

        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context);
          }
          throw OfflineBuilderError(snapshot.error!);
        }

        final connectivity = snapshot.data!;
        final isConnected = !connectivity.contains(ConnectivityResult.none);

        // Reset retry counter when connection is restored
        if (isConnected) {
          _resetRetryCounter();
        }

        return widget.connectivityBuilder(context, connectivity, widget.child ?? widget.builder!(context));
      },
    );
  }
}

class OfflineBuilderError extends Error {
  OfflineBuilderError(this.error);

  final Object error;

  @override
  String toString() => error.toString();
}

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_offline/src/utils.dart';
import 'package:network_info_plus/network_info_plus.dart';

const kOfflineDebounceDuration = Duration(seconds: 3);
const kDefaultMaxRetries = 5;
const kDefaultRetryCooldown = Duration(seconds: 2);

typedef ValueWidgetBuilder<T> = Widget Function(
    BuildContext context, T value, Widget child);

/// Controller for managing retry callbacks
class RetryController {
  RetryController({
    this.onRetry,
    this.onRetryError,
  });

  /// Callback function that gets executed when retry is triggered
  final Future<void> Function()? onRetry;

  /// Callback function that gets executed when retry fails
  final void Function(Object error, StackTrace stackTrace)? onRetryError;
}

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
    RetryController? retryController,
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
      retryController: retryController,
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
    this.retryController,
  })  : assert(
            !(builder is WidgetBuilder && child is Widget) &&
                !(builder == null && child == null),
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

  /// Controller for managing retry functionality and state
  final RetryController? retryController;

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

    _connectivityStream =
        Stream.fromFuture(widget.connectivityService.checkConnectivity())
            .asyncExpand((data) => widget
                .connectivityService.onConnectivityChanged
                .transform(startsWith(data)))
            .transform(debounce(widget.debounceDuration))
            .map((connectivity) {
      // Reset retry counter when connection is restored
      final isConnected = !connectivity.contains(ConnectivityResult.none);
      if (isConnected && _retryCount > 0) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _retryCount = 0;
              _lastRetryTime = null;
            });
          }
        });
      }
      return connectivity;
    });
  }

  /// Manually retry connectivity check with exponential backoff
  Future<void> retry() async {
    if (!_canRetryNow()) return;

    setState(() {
      _isRetrying = true;
    });

    _lastRetryTime = clock.now();

    try {
      // Execute custom retry callback if provided
      if (widget.retryController?.onRetry != null) {
        await widget.retryController!.onRetry!();
      }

      // Calculate exponential backoff delay
      final delaySeconds = (1 << _retryCount); // 2^retryCount
      await Future.delayed(Duration(seconds: delaySeconds));

      // Force a connectivity check - this will trigger the stream naturally
      await widget.connectivityService.checkConnectivity();

      _retryCount++;
    } catch (e, stackTrace) {
      // Communicate error back to caller via controller
      if (widget.retryController?.onRetryError != null) {
        widget.retryController!.onRetryError!(e, stackTrace);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  /// Get current retry count for UI display
  int get retryCount => _retryCount;

  /// Check if currently retrying for UI display
  bool get isRetrying => _isRetrying;

  /// Check if retry is currently available
  /// Useful for UI to enable/disable retry button
  bool get canRetry => _canRetryNow();

  /// Internal helper to check if retry is available
  bool _canRetryNow() {
    if (_isRetrying) return false;
    if (_retryCount >= widget.maxRetries) return false;

    final now = clock.now();
    if (_lastRetryTime != null &&
        now.difference(_lastRetryTime!) < widget.retryCooldown) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: _connectivityStream,
      builder: (BuildContext context,
          AsyncSnapshot<List<ConnectivityResult>> snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const SizedBox();
        }

        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context);
          }
          throw OfflineBuilderError(snapshot.error!);
        }

        return widget.connectivityBuilder(
            context, snapshot.data!, widget.child ?? widget.builder!(context));
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

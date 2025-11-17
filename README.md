# ✈️ Flutter Offline

[![Format, Analyze and Test](https://github.com/jogboms/flutter_offline/actions/workflows/main.yml/badge.svg)](https://github.com/jogboms/flutter_offline/actions/workflows/main.yml) [![codecov](https://codecov.io/gh/jogboms/flutter_offline/branch/master/graph/badge.svg)](https://codecov.io/gh/jogboms/flutter_offline) [![pub package](https://img.shields.io/pub/v/flutter_offline.svg)](https://pub.dartlang.org/packages/flutter_offline)

A tidy utility to handle offline/online connectivity like a Boss. It provides support for both iOS and Android platforms (offcourse).

## 🎖 Installing

```yaml
dependencies:
  flutter_offline: "^6.0.0"
```

### ⚡️ Import

```dart
import 'package:flutter_offline/flutter_offline.dart';
```

### ✔ Add Permission to Manifest

```dart
<uses-permission android:name="android.permission.INTERNET"/>
```

## 🎮 How To Use

```dart
import 'package:flutter/material.dart';
import 'package:flutter_offline/flutter_offline.dart';

class DemoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Offline Demo"),
      ),
      body: OfflineBuilder(
        connectivityBuilder: (
          BuildContext context,
          List<ConnectivityResult> connectivity,
          Widget child,
        ) {
          final bool connected = !connectivity.contains(ConnectivityResult.none);
          return new Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                height: 24.0,
                left: 0.0,
                right: 0.0,
                child: Container(
                  color: connected ? Color(0xFF00EE44) : Color(0xFFEE4400),
                  child: Center(
                    child: Text("${connected ? 'ONLINE' : 'OFFLINE'}"),
                  ),
                ),
              ),
              Center(
                child: new Text(
                  'Yay!',
                ),
              ),
            ],
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Text(
              'There are no bottons to push :)',
            ),
            new Text(
              'Just turn off your internet.',
            ),
          ],
        ),
      ),
    );
  }
}
```

For more info, please, refer to the `main.dart` in the example.

## 🔄 Manual Retry Functionality

The library now supports manual retry functionality with exponential backoff and retry limits, providing users with a simple retry button for connectivity checks.

### Basic Usage with Retry

```dart
import 'package:flutter/material.dart';
import 'package:flutter_offline/flutter_offline.dart';

class DemoPageWithRetry extends StatefulWidget {
  @override
  _DemoPageWithRetryState createState() => _DemoPageWithRetryState();
}

class _DemoPageWithRetryState extends State<DemoPageWithRetry> {
  OfflineBuilderState? _offlineBuilderState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Offline Demo with Retry")),
      body: OfflineBuilder(
        maxRetries: 5,
        retryCooldown: Duration(seconds: 2),
        onRetry: () async {
          // Custom retry logic
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Retrying connectivity check...')),
          );
        },
        onBuilderReady: (state) {
          _offlineBuilderState = state;
        },
        connectivityBuilder: (context, connectivity, child) {
          final bool connected = !connectivity.contains(ConnectivityResult.none);
          return Column(
            children: [
              Container(
                height: 50,
                color: connected ? Colors.green : Colors.red,
                child: Center(
                  child: Text(connected ? 'ONLINE' : 'OFFLINE'),
                ),
              ),
              Expanded(child: child),
              if (!connected) ...[
                ElevatedButton.icon(
                  onPressed: _offlineBuilderState?.canRetry == true
                      ? () async {
                          await _offlineBuilderState?.retry();
                          setState(() {});
                        }
                      : null,
                  icon: _offlineBuilderState?.isRetrying == true
                      ? CircularProgressIndicator()
                      : Icon(Icons.refresh),
                  label: Text(_offlineBuilderState?.isRetrying == true ? 'Retrying...' : 'Retry Connection'),
                ),
                Text('Attempts: ${_offlineBuilderState?.retryCount ?? 0}/5'),
              ],
            ],
          );
        },
        child: Center(child: Text('Your app content here')),
      ),
    );
  }
}
```

### Retry Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `maxRetries` | `int` | `5` | Maximum number of retry attempts |
| `retryCooldown` | `Duration` | `2 seconds` | Minimum time between manual retries |
| `onRetry` | `RetryCallback?` | `null` | Custom callback executed on retry |
| `onBuilderReady` | `Function?` | `null` | Callback to access OfflineBuilderState |

### Retry State Properties

Access these through the `OfflineBuilderState` instance:

| Property | Description |
|----------|-------------|
| `retry()` | Manually trigger a connectivity retry |
| `canRetry` | Check if retry is currently available |
| `isRetrying` | Check if a retry is in progress |
| `retryCount` | Current number of retry attempts |

### Features

- **Exponential Backoff**: Retry delays increase exponentially (1s, 2s, 4s, 8s, 16s)
- **Retry Limits**: Configurable maximum retry attempts
- **Cooldown Protection**: Prevents spam retries
- **Custom Callbacks**: Execute custom logic on retry
- **State Access**: Direct access to retry state for UI updates
- **Automatic Reset**: Retry counter resets when connection is restored

## 🧪 Testing

The library includes comprehensive tests covering:

- Core connectivity monitoring functionality  
- Retry functionality integration tests
- Debounce and utility function tests
- Error handling and edge cases

All tests are located in the `test/` directory and follow Flutter's testing conventions.

Run tests with:
```bash
flutter test
```

## 📷 Screenshots

<table>
  <tr>
    <td align="center">
      <img src="https://raw.githubusercontent.com/jogboms/flutter_offline/master/screenshots/demo_1.gif" width="250px">
    </td>
    <td align="center">
      <img src="https://raw.githubusercontent.com/jogboms/flutter_offline/master/screenshots/demo_2.gif" width="250px">
    </td>
    <td align="center">
      <img src="https://raw.githubusercontent.com/jogboms/flutter_offline/master/screenshots/demo_3.gif" width="250px">
    </td>
  </tr>
</table>

## 🐛 Bugs/Requests

If you encounter any problems feel free to open an issue. If you feel the library is
missing a feature, please raise a ticket on Github and I'll look into it.
Pull request are also welcome.

### ❗️ Note

For help getting started with Flutter, view our online
[documentation](https://flutter.io/).

For help on editing plugin code, view the [documentation](https://flutter.io/platform-plugins/#edit-code).

### 🤓 Mentions

Simon Lightfoot ([@slightfoot](https://github.com/slightfoot)) is just awesome 👍.

## ⭐️ License

MIT License

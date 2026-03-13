import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'auth/mock_auth_service.dart';
import 'position/position_resolver.dart';
import 'session/session_broker.dart';
import 'bridge/shell_bridge.dart';

void main() {
  runApp(const FoundryShellApp());
}

class FoundryShellApp extends StatelessWidget {
  const FoundryShellApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foundry Shell',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ShellHomePage(),
    );
  }
}

class ShellHomePage extends StatefulWidget {
  const ShellHomePage({Key? key}) : super(key: key);

  @override
  State<ShellHomePage> createState() => _ShellHomePageState();
}

class _ShellHomePageState extends State<ShellHomePage> {
  // Services
  late final MockAuthService _authService;
  late final PositionResolver _positionResolver;
  late final SessionBroker _sessionBroker;
  late ShellBridge _shellBridge;

  // WebView controller
  late final WebViewController _webViewController;

  // State
  bool _isAuthenticated = false;
  bool _isLoading = false;
  Position? _currentPosition;
  String _statusMessage = 'Ready to authenticate';

  // Text controllers for login
  final _usernameController = TextEditingController(text: 'demo_user');
  final _passwordController = TextEditingController(text: 'password');

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeWebView();
  }

  /// Initializes core services
  void _initializeServices() {
    _authService = MockAuthService();
    _positionResolver = PositionResolver();
    _sessionBroker = SessionBroker();

    // Initialize bridge
    const channel = MethodChannel('com.foundry.shell/bridge');
    _shellBridge = ShellBridge(
      channel: channel,
      authService: _authService,
      positionResolver: _positionResolver,
      sessionBroker: _sessionBroker,
    );
  }

  /// Initializes WebView with platform-specific settings
  void _initializeWebView() {
    // Platform-specific WebView parameters
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webViewController = WebViewController.fromPlatformCreationParams(params);

    // Configure WebView
    _webViewController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            _injectBridgeInterface();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'shellBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      );

    // Enable debugging on Android
    if (_webViewController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_webViewController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  /// Injects bridge interface into WebView JavaScript context
  Future<void> _injectBridgeInterface() async {
    // Inject bridge adapter that connects JavaScript to Flutter channel
    await _webViewController.runJavaScript('''
      window.shellBridge = {
        postMessage: async function(method, args) {
          return new Promise((resolve, reject) => {
            // For Phase 1, we use a simplified synchronous bridge
            // Production would implement async message passing
            try {
              const result = window.flutter_inappwebview?.callHandler('${_getBridgeChannelName()}', {
                method: method,
                args: args || {}
              });
              resolve(result || { success: false, error: 'No response' });
            } catch (error) {
              reject(error);
            }
          });
        }
      };
      console.log('[Shell] Bridge interface injected');
    ''');
  }

  String _getBridgeChannelName() {
    return 'com.foundry.shell/bridge';
  }

  /// Handles bridge messages from JavaScript
  void _handleBridgeMessage(String message) {
    debugPrint('Bridge message received: $message');
    // Additional message handling if needed
  }

  /// Handles authentication flow
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Authenticating...';
    });

    try {
      // Step 1: Authenticate user (mock system browser flow)
      final success = await _authService.authenticateUser(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (!success) {
        throw Exception('Authentication failed');
      }

      setState(() {
        _statusMessage = 'Resolving position...';
      });

      // Step 2: Resolve user's position
      final username = await _authService.getCurrentUsername();
      if (username == null) {
        throw Exception('Cannot determine user');
      }

      _currentPosition = await _positionResolver.resolvePosition(username);
      _shellBridge.setCurrentPosition(_currentPosition!);

      setState(() {
        _isAuthenticated = true;
        _statusMessage = 'Loading runtime host...';
      });

      // Step 3: Load runtime host in WebView
      await _loadRuntimeHost();

      setState(() {
        _statusMessage = 'Runtime host loaded - Position: ${_currentPosition!.positionName}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      debugPrint('Login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Loads runtime host HTML in WebView
  Future<void> _loadRuntimeHost() async {
    // For Phase 1, load runtime host from local assets or embedded HTML
    // In production, this would load from secure backend
    final positionName = _currentPosition?.positionName ?? 'Unknown';
    final runtimeHostHtml = '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Foundry Runtime Host</title>
        </head>
        <body>
          <div id="runtime-container">
            <h2>Runtime Host Loading...</h2>
            <p>Bootstrapping session...</p>
          </div>
          <script>
            console.log('[RuntimeHost] Loaded in WebView');
            // Runtime host initialization would happen here
            // For Phase 1, we simulate the bootstrap flow
            setTimeout(() => {
              document.getElementById('runtime-container').innerHTML =
                '<h2>Runtime Host Ready</h2><p>Position: $positionName</p>';
            }, 1000);
          </script>
        </body>
      </html>
    ''';

    await _webViewController.loadHtmlString(runtimeHostHtml);
  }

  /// Handles logout
  Future<void> _handleLogout() async {
    await _authService.logout();
    _shellBridge.clearPosition();

    setState(() {
      _isAuthenticated = false;
      _currentPosition = null;
      _statusMessage = 'Logged out';
    });

    // Clear WebView
    await _webViewController.loadHtmlString('<html><body></body></html>');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foundry Shell'),
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _isAuthenticated ? Colors.green.shade700 : Colors.blue.shade700,
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),

          // Main content area
          Expanded(
            child: _isAuthenticated ? _buildWebViewContainer() : _buildLoginForm(),
          ),
        ],
      ),
    );
  }

  /// Builds login form
  Widget _buildLoginForm() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mock Authentication',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter any credentials to simulate system browser auth',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds WebView container
  Widget _buildWebViewContainer() {
    return Column(
      children: [
        // Position info bar
        if (_currentPosition != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Position: ${_currentPosition!.positionName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Org: ${_currentPosition!.orgId} | Position ID: ${_currentPosition!.positionId}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

        // WebView
        Expanded(
          child: WebViewWidget(controller: _webViewController),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

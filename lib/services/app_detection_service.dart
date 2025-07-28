import 'dart:async';
import 'package:flutter/services.dart';

class AppDetectionService {
  static const MethodChannel _channel = MethodChannel('app_detection_channel');
  
  // Stream controller for app detection events
  final StreamController<String> _appDetectionController = StreamController<String>.broadcast();
  Stream<String> get appDetectionStream => _appDetectionController.stream;
  
  // Stream controller for overlay close events
  final StreamController<void> _overlayClosedController = StreamController<void>.broadcast();
  Stream<void> get overlayClosedStream => _overlayClosedController.stream;
  
  // Current foreground app
  String? _currentApp;
  String? get currentApp => _currentApp;
  
  // List of apps to monitor
  List<String> _blockedApps = [];
  
  // Timer for periodic checking
  Timer? _checkTimer;
  bool _isMonitoring = false;
  
  // Check if overlay permission is granted
  Future<bool> hasOverlayPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('hasOverlayPermission');
      return hasPermission;
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  // Request overlay permission
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      print('Error requesting overlay permission: $e');
    }
  }

  // Initialize the service
  Future<void> initialize() async {
    try {
      // Set up method channel for native communication
      _channel.setMethodCallHandler(_handleMethodCall);
      // Do not request permissions here
    } catch (e) {
      print('Error initializing app detection service: $e');
    }
  }
  
  // Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAppDetected':
        String appPackage = call.arguments as String;
        _handleAppDetection(appPackage);
        break;
      case 'onPermissionResult':
        bool granted = call.arguments as bool;
        if (granted) {
          print('Usage stats permission granted');
        } else {
          print('Usage stats permission denied');
        }
        break;
      case 'onOverlayClosed':
        _overlayClosedController.add(null);
        break;
    }
  }
  
  // Request usage stats permission
  Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } catch (e) {
      print('Error requesting usage stats permission: $e');
    }
  }
  
  // Set the list of apps to monitor
  void setBlockedApps(List<String> apps) {
    _blockedApps = apps;
    print('Blocked apps set: $_blockedApps');
  }
  
  // Start monitoring for app usage
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    
    try {
      await _channel.invokeMethod('startAppMonitoring', {
        'blockedApps': _blockedApps,
      });
      
      _isMonitoring = true;
      print('App monitoring started');
    } catch (e) {
      print('Error starting app monitoring: $e');
    }
  }
  
  // Stop monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;
    
    try {
      await _channel.invokeMethod('stopAppMonitoring');
      
      _isMonitoring = false;
      _checkTimer?.cancel();
      print('App monitoring stopped');
    } catch (e) {
      print('Error stopping app monitoring: $e');
    }
  }
  
  // Handle when a monitored app is detected
  void _handleAppDetection(String appPackage) {
    if (_blockedApps.contains(appPackage)) {
      _currentApp = appPackage;
      _appDetectionController.add(appPackage);
      print('Blocked app detected: $appPackage');
    }
  }
  
  // Check if usage stats permission is granted
  Future<bool> hasUsageStatsPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('hasUsageStatsPermission');
      return hasPermission;
    } catch (e) {
      print('Error checking usage stats permission: $e');
      return false;
    }
  }
  
  // Get list of installed apps
  Future<List<String>> getInstalledApps() async {
    try {
      final List<dynamic> apps = await _channel.invokeMethod('getInstalledApps');
      return apps.cast<String>();
    } catch (e) {
      print('Error getting installed apps: $e');
      return [];
    }
  }
  
  // Dispose resources
  void dispose() {
    stopMonitoring();
    _appDetectionController.close();
    _overlayClosedController.close();
  }
}
/**
 * Bridge Helper - Parallel Modules Architecture
 * Provides JavaScript interface for per-module bridge communication
 *
 * Each module gets its own bridge channel:
 * - Module 1 (port 8080) → shellBridge_test-quality-inspector
 * - Module 2 (port 8081) → shellBridge_sample-warehouse
 * - Module 3 (port 8082) → shellBridge_test-inventory-checker
 *
 * Auto-detects module ID from URL origin and provides unified API
 */

(function() {
  'use strict';

  // Auto-detect module ID from current origin
  function getModuleIdFromOrigin() {
    const port = window.location.port;
    const portToModuleMap = {
      '8080': 'test-quality-inspector',
      '8081': 'sample-warehouse',
      '8082': 'test-inventory-checker',
    };
    return portToModuleMap[port] || 'unknown';
  }

  const MODULE_ID = getModuleIdFromOrigin();
  const CHANNEL_NAME = `shellBridge_${MODULE_ID}`;

  console.log('[BridgeHelper] Initializing for module:', MODULE_ID);
  console.log('[BridgeHelper] Channel name:', CHANNEL_NAME);
  console.log('[BridgeHelper] Origin:', window.location.origin);

  // Callback registry for pending calls
  window.__bridgeCallbacks = window.__bridgeCallbacks || {};
  let callIdCounter = 0;

  /**
   * Call a bridge method
   * @param {string} method - Method name
   * @param {object} args - Method arguments
   * @returns {Promise<any>} - Result from Flutter
   */
  async function callBridge(method, args = {}) {
    return new Promise((resolve, reject) => {
      // Check if bridge channel exists
      if (typeof window[CHANNEL_NAME] === 'undefined') {
        console.error('[BridgeHelper] Bridge channel not available:', CHANNEL_NAME);
        reject(new Error(`Bridge channel ${CHANNEL_NAME} not available`));
        return;
      }

      // Generate unique call ID
      const callId = `call_${MODULE_ID}_${Date.now()}_${callIdCounter++}`;

      // Register callback
      window.__bridgeCallbacks[callId] = (resultData) => {
        try {
          const result = typeof resultData === 'string' ? JSON.parse(resultData) : resultData;

          if (result.result && result.result.success) {
            resolve(result.result.data);
          } else {
            reject(new Error(result.result?.error || 'Bridge call failed'));
          }
        } catch (e) {
          console.error('[BridgeHelper] Error parsing result:', e);
          reject(e);
        }
      };

      // Set timeout
      setTimeout(() => {
        if (window.__bridgeCallbacks[callId]) {
          delete window.__bridgeCallbacks[callId];
          reject(new Error('Bridge call timeout'));
        }
      }, 30000); // 30 second timeout

      // Send message to Flutter
      const message = JSON.stringify({
        method,
        args,
        callId,
        moduleId: MODULE_ID,
      });

      console.log('[BridgeHelper] Calling bridge:', method, args);

      try {
        window[CHANNEL_NAME].postMessage(message);
      } catch (e) {
        delete window.__bridgeCallbacks[callId];
        console.error('[BridgeHelper] Error calling bridge:', e);
        reject(e);
      }
    });
  }

  /**
   * Check if bridge is available
   */
  function isBridgeAvailable() {
    return typeof window[CHANNEL_NAME] !== 'undefined';
  }

  /**
   * Get current module ID
   */
  function getModuleId() {
    return MODULE_ID;
  }

  /**
   * Event handler registry
   */
  const eventHandlers = {};

  function _handleEvent(eventName, data) {
    console.log('[BridgeHelper] Event received:', eventName, data);
    const handlers = eventHandlers[eventName] || [];
    handlers.forEach(handler => {
      try {
        handler(data);
      } catch (e) {
        console.error('[BridgeHelper] Error in event handler:', e);
      }
    });
  }

  function addEventListener(eventName, handler) {
    if (!eventHandlers[eventName]) {
      eventHandlers[eventName] = [];
    }
    eventHandlers[eventName].push(handler);
  }

  function removeEventListener(eventName, handler) {
    if (eventHandlers[eventName]) {
      eventHandlers[eventName] = eventHandlers[eventName].filter(h => h !== handler);
    }
  }

  // Create unified bridge API
  window.shellBridge = {
    // Core API
    _call: callBridge,
    isAvailable: isBridgeAvailable,
    getModuleId: getModuleId,
    _handleEvent: _handleEvent,
    addEventListener: addEventListener,
    removeEventListener: removeEventListener,

    // Photo methods
    capturePhoto: (args) => callBridge('capturePhoto', args),

    // File methods
    saveFile: (args) => callBridge('saveFile', args),
    readFileBridge: (args) => callBridge('readFileBridge', args),
    deleteFile: (args) => callBridge('deleteFile', args),
    listFiles: () => callBridge('listFiles', {}),

    // Scanner methods
    scanBarcode: (args) => callBridge('scanBarcode', args),

    // Connectivity methods
    getConnectivityStatus: () => callBridge('getConnectivityStatus', {}),
    startConnectivityMonitoring: () => callBridge('startConnectivityMonitoring', {}),
    stopConnectivityMonitoring: () => callBridge('stopConnectivityMonitoring', {}),

    // Module info
    moduleId: MODULE_ID,
    channelName: CHANNEL_NAME,
  };

  console.log('[BridgeHelper] ✅ Bridge initialized for module:', MODULE_ID);
  console.log('[BridgeHelper] Bridge available:', isBridgeAvailable());

  // Emit ready event
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('shellBridgeReady', {
      detail: {
        moduleId: MODULE_ID,
        channelName: CHANNEL_NAME,
      }
    }));
  }
})();

/**
 * Bridge Helper - Single Global Bridge (Current Architecture)
 * 
 * ARCHITECTURE:
 * - ONE global bridge: window.shellBridge
 * - All modules share the same bridge
 * - IndexedDB separated by module_id filter
 * - Origin: localhost:8080 (shared by all modules)
 */

(function() {
  'use strict';

  console.log('[BridgeHelper] Initializing global bridge helper');
  console.log('[BridgeHelper] Origin:', window.location.origin);

  /**
   * Check if bridge is available
   */
  function isBridgeAvailable() {
    return typeof window.shellBridge !== 'undefined' && 
           typeof window.shellBridge._call === 'function';
  }

  /**
   * Wait for bridge to be ready
   */
  async function waitForBridge(timeout = 5000) {
    const startTime = Date.now();
    
    while (!isBridgeAvailable()) {
      if (Date.now() - startTime > timeout) {
        throw new Error('Bridge timeout');
      }
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    return true;
  }

  // If bridge not available yet, wait for it
  if (!isBridgeAvailable()) {
    console.log('[BridgeHelper] Bridge not ready yet, will check on first call');
  } else {
    console.log('[BridgeHelper] ✅ Bridge available immediately');
  }

  // Emit ready event
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('shellBridgeHelperReady', {
      detail: { origin: window.location.origin }
    }));
  }

  console.log('[BridgeHelper] ✅ Bridge helper loaded');
})();

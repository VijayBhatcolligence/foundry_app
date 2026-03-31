/**
 * SyncManager
 *
 * Manages syncing of pending actions from Flutter SQLite to backend API.
 * Handles retry logic, status updates, and error handling.
 *
 * Features:
 * - Process pending actions from ActionQueue (via bridge)
 * - Send to backend API based on action_type
 * - Handle 3 response types: 200 OK, 400 validation error, 500 server error
 * - Retry logic with max attempts (default: 3)
 * - Update action status in SQLite after each attempt
 * - Resume sync after module reload
 * - Provide status to UI
 */

const DEFAULT_MAX_RETRIES = 3;
const DEFAULT_RETRY_DELAY = 1000; // 1 second
const SYNC_API_BASE_URL = 'http://localhost:3000/api';

class SyncManager {
  /**
   * Create a new SyncManager
   * @param {string} moduleId - Unique module identifier
   * @param {object} options - Configuration options
   */
  constructor(moduleId, options = {}) {
    this.moduleId = moduleId;
    this.apiBaseUrl = options.apiBaseUrl || SYNC_API_BASE_URL;
    this.maxRetries = options.maxRetries || DEFAULT_MAX_RETRIES;
    this.retryDelay = options.retryDelay || DEFAULT_RETRY_DELAY;
    this.onProgress = options.onProgress || null; // Callback for progress updates
    this.onComplete = options.onComplete || null; // Callback when sync completes
    this.onError = options.onError || null; // Callback for errors

    this.isSyncing = false;
    this.currentActionId = null;

    console.log(`[SyncManager] Created for module: ${moduleId}`);
  }

  /**
   * Initialize the manager (check if ActionQueue bridge is available)
   */
  async initialize() {
    if (!window.ActionQueue) {
      throw new Error('ActionQueue bridge not available. Ensure bridge_helper.js is loaded.');
    }

    console.log('[SyncManager] ✅ Initialized successfully');
    console.log(`[SyncManager] Module ID: ${this.moduleId}`);
    console.log(`[SyncManager] API Base: ${this.apiBaseUrl}`);
    console.log(`[SyncManager] Max Retries: ${this.maxRetries}`);

    return true;
  }

  /**
   * Get current sync status
   * @returns {object} Status object with counts
   */
  async getStatus() {
    if (!window.ActionQueue) {
      return { pending: 0, syncing: 0, synced: 0, errors: 0 };
    }

    try {
      const allActions = await window.ActionQueue.getAll(this.moduleId);

      const status = {
        pending: 0,
        syncing: 0,
        synced: 0,
        errors: 0,
        total: allActions.length
      };

      allActions.forEach(action => {
        switch (action.status) {
          case 'pending':
            status.pending++;
            break;
          case 'syncing':
            status.syncing++;
            break;
          case 'synced':
            status.synced++;
            break;
          case 'error':
            status.errors++;
            break;
        }
      });

      return status;
    } catch (error) {
      console.error('[SyncManager] Failed to get status:', error);
      return { pending: 0, syncing: 0, synced: 0, errors: 0, total: 0 };
    }
  }

  /**
   * Sync all pending actions
   * @returns {Promise<object>} Sync results
   */
  async syncAll() {
    if (this.isSyncing) {
      console.warn('[SyncManager] Sync already in progress');
      return { skipped: true, reason: 'Already syncing' };
    }

    if (!window.ActionQueue) {
      throw new Error('ActionQueue bridge not available');
    }

    this.isSyncing = true;

    try {
      console.log('[SyncManager] ========================================');
      console.log('[SyncManager] Starting sync for module:', this.moduleId);

      // Get all pending actions
      const pendingActions = await window.ActionQueue.getPending(this.moduleId);

      if (pendingActions.length === 0) {
        console.log('[SyncManager] No pending actions to sync');
        return { synced: 0, failed: 0, skipped: 0 };
      }

      console.log(`[SyncManager] Found ${pendingActions.length} pending action(s)`);

      const results = {
        synced: 0,
        failed: 0,
        skipped: 0,
        errors: []
      };

      // Process each action
      for (const action of pendingActions) {
        try {
          const success = await this.syncOne(action.id);
          if (success) {
            results.synced++;
          } else {
            results.failed++;
          }
        } catch (error) {
          console.error(`[SyncManager] Error syncing action ${action.id}:`, error);
          results.failed++;
          results.errors.push({
            actionId: action.id,
            error: error.message
          });
        }

        // Call progress callback
        if (this.onProgress) {
          this.onProgress({
            current: results.synced + results.failed,
            total: pendingActions.length,
            synced: results.synced,
            failed: results.failed
          });
        }
      }

      console.log('[SyncManager] Sync completed');
      console.log(`[SyncManager] ✅ Synced: ${results.synced}`);
      console.log(`[SyncManager] ❌ Failed: ${results.failed}`);
      console.log('[SyncManager] ========================================');

      // Call complete callback
      if (this.onComplete) {
        this.onComplete(results);
      }

      return results;
    } finally {
      this.isSyncing = false;
      this.currentActionId = null;
    }
  }

  /**
   * Sync a single action by ID
   * @param {string} actionId - Action ID to sync
   * @returns {Promise<boolean>} True if synced successfully
   */
  async syncOne(actionId) {
    if (!window.ActionQueue) {
      throw new Error('ActionQueue bridge not available');
    }

    this.currentActionId = actionId;

    try {
      // Get action details
      const actions = await window.ActionQueue.getAll(this.moduleId);
      const action = actions.find(a => a.id === actionId);

      if (!action) {
        console.warn(`[SyncManager] Action not found: ${actionId}`);
        return false;
      }

      if (action.status === 'synced') {
        console.log(`[SyncManager] Action already synced: ${actionId}`);
        return true;
      }

      if (action.status === 'syncing') {
        console.warn(`[SyncManager] Action already being synced: ${actionId}`);
        return false;
      }

      console.log(`[SyncManager] Syncing action: ${actionId} (${action.action_type})`);

      // Mark as syncing
      await window.ActionQueue.markSyncing(actionId);

      // Prepare request
      const endpoint = this._getEndpoint(action.action_type);
      const payload = typeof action.payload === 'string'
        ? JSON.parse(action.payload)
        : action.payload;

      // Check if action has photo to upload
      if (payload.photoPath && payload.photoPath.startsWith('file://')) {
        console.log(`[SyncManager] 📸 Action has photo, uploading first: ${payload.photoPath}`);

        try {
          // Read photo from Flutter storage as base64
          const fileResult = await window.shellBridge.readFile(payload.photoPath);

          if (!fileResult.success) {
            throw new Error(`Failed to read photo: ${fileResult.error || 'Unknown error'}`);
          }

          console.log(`[SyncManager] Photo read: ${fileResult.data.fileName} (${fileResult.data.size} bytes)`);

          // Upload photo to backend
          const uploadResponse = await fetch(`${this.apiBaseUrl}/upload`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              fileName: fileResult.data.fileName,
              fileData: fileResult.data.fileData
            })
          });

          if (!uploadResponse.ok) {
            const uploadError = await uploadResponse.text();
            throw new Error(`Photo upload failed (${uploadResponse.status}): ${uploadError}`);
          }

          const uploadResult = await uploadResponse.json();

          if (!uploadResult.success || !uploadResult.fileUrl) {
            throw new Error(`Photo upload failed: ${uploadResult.error || 'No file URL returned'}`);
          }

          console.log(`[SyncManager] ✅ Photo uploaded: ${uploadResult.fileUrl}`);

          // Replace local file path with backend URL
          payload.photoPath = uploadResult.fileUrl;
          payload.photoUrl = uploadResult.fileUrl; // Also set photoUrl for compatibility

        } catch (photoError) {
          console.error(`[SyncManager] ❌ Photo upload failed:`, photoError);

          // Mark action as error (photo upload is critical)
          await window.ActionQueue.markError(
            actionId,
            `Photo upload failed: ${photoError.message}`
          );
          return false;
        }
      }

      console.log(`[SyncManager] → POST ${endpoint}`);

      // Send to backend
      try {
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(payload)
        });

        // Handle response based on status code
        if (response.ok) {
          // 200-299: Success
          console.log(`[SyncManager] ✅ Action synced successfully: ${actionId}`);
          await window.ActionQueue.markSynced(actionId);
          return true;
        } else if (response.status >= 400 && response.status < 500) {
          // 400-499: Client error (validation, not found, etc.)
          const errorText = await response.text();
          let errorMessage;

          try {
            const errorJson = JSON.parse(errorText);
            errorMessage = errorJson.error || errorJson.message || errorText;
          } catch {
            errorMessage = errorText;
          }

          console.error(`[SyncManager] ❌ Validation error (${response.status}): ${errorMessage}`);

          // Mark as error (no retry for validation errors)
          await window.ActionQueue.markError(actionId, `HTTP ${response.status}: ${errorMessage}`);
          return false;
        } else {
          // 500-599: Server error (retry)
          const errorText = await response.text();
          console.error(`[SyncManager] ⚠️ Server error (${response.status}): ${errorText}`);

          // Check retry count
          const retryCount = (action.retry_count || 0) + 1;

          if (retryCount >= this.maxRetries) {
            console.error(`[SyncManager] ❌ Max retries reached (${this.maxRetries}): ${actionId}`);
            await window.ActionQueue.markError(
              actionId,
              `Max retries reached after ${response.status} error`
            );
            return false;
          } else {
            console.log(`[SyncManager] 🔄 Retry ${retryCount}/${this.maxRetries}: ${actionId}`);
            // Mark back as pending with incremented retry count
            await window.ActionQueue.incrementRetry(actionId);
            return false;
          }
        }
      } catch (networkError) {
        // Network error (timeout, connection refused, etc.)
        console.error(`[SyncManager] ⚠️ Network error:`, networkError);

        // Check retry count
        const retryCount = (action.retry_count || 0) + 1;

        if (retryCount >= this.maxRetries) {
          console.error(`[SyncManager] ❌ Max retries reached (${this.maxRetries}): ${actionId}`);
          await window.ActionQueue.markError(
            actionId,
            `Max retries reached after network error: ${networkError.message}`
          );
          return false;
        } else {
          console.log(`[SyncManager] 🔄 Retry ${retryCount}/${this.maxRetries}: ${actionId}`);
          await window.ActionQueue.incrementRetry(actionId);

          // Wait before retry
          if (this.retryDelay > 0) {
            await this._sleep(this.retryDelay);
          }

          return false;
        }
      }
    } catch (error) {
      console.error(`[SyncManager] ❌ Sync failed for ${actionId}:`, error);

      // Call error callback
      if (this.onError) {
        this.onError({
          actionId,
          error: error.message
        });
      }

      throw error;
    } finally {
      this.currentActionId = null;
    }
  }

  /**
   * Retry all failed actions
   * @returns {Promise<object>} Retry results
   */
  async retryFailed() {
    if (!window.ActionQueue) {
      throw new Error('ActionQueue bridge not available');
    }

    console.log('[SyncManager] Retrying failed actions...');

    try {
      // Get all actions and filter errors
      const allActions = await window.ActionQueue.getAll(this.moduleId);
      const failedActions = allActions.filter(a => a.status === 'error');

      if (failedActions.length === 0) {
        console.log('[SyncManager] No failed actions to retry');
        return { retried: 0, synced: 0, failed: 0 };
      }

      console.log(`[SyncManager] Found ${failedActions.length} failed action(s)`);

      const results = {
        retried: failedActions.length,
        synced: 0,
        failed: 0
      };

      // Reset each failed action to pending
      for (const action of failedActions) {
        try {
          // Reset to pending status with retry count = 0
          await window.ActionQueue.resetAction(action.id);
          console.log(`[SyncManager] Reset action to pending: ${action.id}`);

          // Try to sync immediately
          const success = await this.syncOne(action.id);
          if (success) {
            results.synced++;
          } else {
            results.failed++;
          }
        } catch (error) {
          console.error(`[SyncManager] Error retrying ${action.id}:`, error);
          results.failed++;
        }
      }

      console.log(`[SyncManager] Retry completed: ${results.synced} synced, ${results.failed} failed`);

      return results;
    } catch (error) {
      console.error('[SyncManager] Retry failed:', error);
      throw error;
    }
  }

  /**
   * Stop current sync operation
   */
  stop() {
    if (this.isSyncing) {
      console.log('[SyncManager] Stopping sync...');
      this.isSyncing = false;
      this.currentActionId = null;
    }
  }

  /**
   * Get endpoint URL for action type
   * @private
   */
  _getEndpoint(actionType) {
    // Map action types to API endpoints
    const endpoints = {
      // Inventory Checker
      'stock_count': '/stock-counts',
      'audit_trail': '/audit-trail',

      // Quality Inspector
      'inspection_log': '/inspection-logs',
      'submit_report': '/reports',

      // Sample Warehouse
      'transaction': '/transactions',
      'water_temp': '/water-temp',
      'complaint': '/complaints',

      // Generic
      'submission': '/submissions',
      'update': '/updates'
    };

    const path = endpoints[actionType];
    if (!path) {
      throw new Error(`Unknown action type: ${actionType}. Add mapping in _getEndpoint().`);
    }

    return `${this.apiBaseUrl}${path}`;
  }

  /**
   * Sleep for specified milliseconds
   * @private
   */
  _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Export for use in modules
if (typeof window !== 'undefined') {
  window.SyncManager = SyncManager;
}

// Also support ES6 module export
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SyncManager;
}

console.log('[SyncManager] Component loaded and ready');

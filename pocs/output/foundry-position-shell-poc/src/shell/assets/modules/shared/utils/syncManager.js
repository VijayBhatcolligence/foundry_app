/**
 * SyncManager - Syncs actions from IndexedDB to backend
 *
 * ARCHITECTURE:
 * 1. Reads pending actions from IndexedDB ActionQueue
 * 2. If action has photo_path, reads file from Flutter via bridge
 * 3. Attaches photo as base64 to payload
 * 4. Sends to backend
 * 5. Marks as synced in IndexedDB
 * 6. Optionally deletes file after successful sync
 *
 * Usage:
 * ```javascript
 * const syncManager = new SyncManager('my-module-id', {
 *   maxRetries: 3,
 *   deleteFilesAfterSync: true,
 *   onProgress: (progress) => { ... }
 * });
 *
 * await syncManager.initialize();
 * await syncManager.syncAll();
 * ```
 */

import { ActionQueue } from './actionQueue.js';

const DEFAULT_OPTIONS = {
  maxRetries: 3,
  deleteFilesAfterSync: true,  // Clean up files after successful sync
  onProgress: null,  // Progress callback (current, total, action)
  endpoints: {
    // Default endpoints - override per action_type
    submit_report: '/api/reports',
    upload_photo: '/api/photos',
  }
};

export class SyncManager {
  constructor(moduleId, options = {}) {
    this.moduleId = moduleId;
    this.options = { ...DEFAULT_OPTIONS, ...options };
    this.actionQueue = new ActionQueue(moduleId);
    this.isSyncing = false;
  }

  /**
   * Initialize the sync manager
   */
  async initialize() {
    try {
      await this.actionQueue.initialize();
      console.log('[SyncManager] Initialized for module:', this.moduleId);
    } catch (err) {
      console.error('[SyncManager] Initialization error:', err);
      throw err;
    }
  }

  /**
   * Sync all pending actions
   * @returns {object} - Sync result {synced: number, failed: number}
   */
  async syncAll() {
    if (this.isSyncing) {
      console.warn('[SyncManager] Sync already in progress');
      return { synced: 0, failed: 0 };
    }

    try {
      this.isSyncing = true;

      console.log('[SyncManager] Starting sync for module:', this.moduleId);

      // Get pending actions
      const pendingActions = await this.actionQueue.getPending();

      if (pendingActions.length === 0) {
        console.log('[SyncManager] No pending actions to sync');
        return { synced: 0, failed: 0 };
      }

      console.log(`[SyncManager] Found ${pendingActions.length} pending action(s)`);

      let synced = 0;
      let failed = 0;

      // Sync each action
      for (let i = 0; i < pendingActions.length; i++) {
        const action = pendingActions[i];

        try {
          // Progress callback
          if (this.options.onProgress) {
            this.options.onProgress(i + 1, pendingActions.length, action);
          }

          console.log(`[SyncManager] Syncing action ${action.id}: ${action.action_type}`);

          await this.syncAction(action);

          synced++;
          console.log(`[SyncManager] ✅ Action ${action.id} synced successfully`);

        } catch (err) {
          failed++;
          console.error(`[SyncManager] ❌ Failed to sync action ${action.id}:`, err);

          // Mark as failed if max retries exceeded
          if (action.retry_count >= this.options.maxRetries) {
            console.warn(`[SyncManager] Max retries exceeded for action ${action.id}`);
            await this.actionQueue.markFailed(action.id, err.message);
          } else {
            // Increment retry count
            await this.actionQueue.markFailed(action.id, err.message);
          }
        }
      }

      console.log(`[SyncManager] Sync complete: ${synced} synced, ${failed} failed`);

      return { synced, failed };

    } finally {
      this.isSyncing = false;
    }
  }

  /**
   * Sync a single action
   * @param {object} action - Action object from IndexedDB
   */
  async syncAction(action) {
    try {
      let payload = { ...action.payload };

      // If action has photo_path, read file from Flutter
      if (payload.photo_path) {
        console.log(`[SyncManager] Action has photo, reading file: ${payload.photo_path}`);

        const fileResult = await this.readFile(payload.photo_path);

        if (!fileResult.success) {
          throw new Error(`Failed to read file: ${fileResult.error}`);
        }

        // Attach photo as base64 to payload
        payload.photo = fileResult.data;
        console.log(`[SyncManager] Photo attached to payload (${fileResult.size} bytes)`);
      }

      // Get endpoint for this action type
      const endpoint = this.getEndpoint(action.action_type);

      console.log(`[SyncManager] → POST ${endpoint}`);

      // Send to backend
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Backend error: ${response.status} - ${errorText}`);
      }

      const result = await response.json();

      if (!result.success) {
        throw new Error(result.error || 'Unknown backend error');
      }

      console.log(`[SyncManager] Backend response:`, result);

      // Mark as synced in IndexedDB
      await this.actionQueue.markSynced(action.id);

      // Delete file if configured
      if (payload.photo_path && this.options.deleteFilesAfterSync) {
        console.log(`[SyncManager] Deleting file after successful sync: ${payload.photo_path}`);
        try {
          await this.deleteFile(payload.photo_path);
        } catch (deleteErr) {
          console.warn(`[SyncManager] Failed to delete file (non-critical):`, deleteErr);
        }
      }

    } catch (err) {
      console.error(`[SyncManager] Sync error:`, err);
      throw err;
    }
  }

  /**
   * Get endpoint for action type
   * @param {string} actionType - Action type
   * @returns {string} - API endpoint
   */
  getEndpoint(actionType) {
    const baseUrl = this.options.backendUrl || 'http://localhost:3000';
    const path = this.options.endpoints[actionType] || `/api/${actionType}`;
    return `${baseUrl}${path}`;
  }

  /**
   * Read file from Flutter via bridge
   * @param {string} filePath - File path
   * @returns {object} - {success: bool, data: string (base64), size: number, error: string?}
   */
  async readFile(filePath) {
    try {
      if (!window.shellBridge || !window.shellBridge._call) {
        throw new Error('Flutter bridge not available');
      }

      const result = await window.shellBridge._call('readFileBridge', {
        filePath: filePath
      });

      return result;

    } catch (err) {
      console.error('[SyncManager] Error reading file:', err);
      return {
        success: false,
        error: err.message
      };
    }
  }

  /**
   * Delete file from Flutter via bridge
   * @param {string} filePath - File path
   */
  async deleteFile(filePath) {
    try {
      if (!window.shellBridge || !window.shellBridge._call) {
        throw new Error('Flutter bridge not available');
      }

      const result = await window.shellBridge._call('deleteFile', {
        filePath: filePath
      });

      if (!result.success) {
        throw new Error(result.error || 'Unknown error');
      }

      console.log('[SyncManager] File deleted:', filePath);

    } catch (err) {
      console.error('[SyncManager] Error deleting file:', err);
      throw err;
    }
  }

  /**
   * Get pending count
   * @returns {number} - Count of pending actions
   */
  async getPendingCount() {
    try {
      return await this.actionQueue.getPendingCount();
    } catch (err) {
      console.error('[SyncManager] Error getting pending count:', err);
      return 0;
    }
  }

  /**
   * Check if currently syncing
   * @returns {boolean}
   */
  get syncing() {
    return this.isSyncing;
  }
}

export default SyncManager;

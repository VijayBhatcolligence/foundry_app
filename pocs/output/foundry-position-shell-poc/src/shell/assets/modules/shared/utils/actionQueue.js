/**
 * IndexedDB-based Action Queue
 *
 * ARCHITECTURE DECISION:
 * - ALL actions (with or without photos) stored in IndexedDB
 * - Photos stored separately in Flutter file system
 * - IndexedDB stores photo_path reference
 * - SyncManager reads from IndexedDB, attaches file when syncing
 *
 * REPLACES: SQLite ActionQueue (Flutter)
 *
 * Usage:
 * ```javascript
 * const queue = new ActionQueue('my-module-id');
 * await queue.initialize();
 *
 * // Save action (with or without photo_path)
 * const actionId = await queue.save('submit_report', {
 *   title: "Report",
 *   photo_path: "/data/files/file_123.jpg"  // Optional
 * });
 *
 * // Get pending actions
 * const pending = await queue.getPending();
 *
 * // Mark as synced
 * await queue.markSynced(actionId);
 * ```
 */

import { openDB } from 'idb';

const DB_NAME = 'action_queue_db';
const STORE_NAME = 'actions';
const DB_VERSION = 1;

export class ActionQueue {
  constructor(moduleId) {
    this.moduleId = moduleId;
    this.db = null;
  }

  /**
   * Initialize the database
   */
  async initialize() {
    try {
      this.db = await openDB(DB_NAME, DB_VERSION, {
        upgrade(db) {
          // Create object store if it doesn't exist
          if (!db.objectStoreNames.contains(STORE_NAME)) {
            const store = db.createObjectStore(STORE_NAME, {
              keyPath: 'id',
              autoIncrement: true
            });

            // Indexes for efficient querying
            store.createIndex('module_id', 'module_id');
            store.createIndex('status', 'status');
            store.createIndex('module_status', ['module_id', 'status']);
            store.createIndex('created_at', 'created_at');

            console.log('[ActionQueue] Created object store:', STORE_NAME);
          }
        }
      });

      console.log('[ActionQueue] Initialized for module:', this.moduleId);
    } catch (err) {
      console.error('[ActionQueue] Initialization error:', err);
      throw new Error(`Failed to initialize action queue: ${err.message}`);
    }
  }

  /**
   * Save an action to the queue
   * @param {string} actionType - Type of action (e.g., 'submit_report', 'upload_photo')
   * @param {object} payload - Action payload (can include photo_path)
   * @returns {number} - Action ID
   */
  async save(actionType, payload) {
    try {
      const action = {
        module_id: this.moduleId,
        action_type: actionType,
        payload: payload,  // Can include photo_path
        status: 'pending',
        created_at: Date.now(),
        retry_count: 0,
        error: null
      };

      const tx = this.db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const id = await store.add(action);

      await tx.done;

      console.log(`[ActionQueue] Saved action: ${actionType} (ID: ${id})`);
      return id;

    } catch (err) {
      console.error('[ActionQueue] Error saving action:', err);
      throw new Error(`Failed to save action: ${err.message}`);
    }
  }

  /**
   * Get pending actions for this module
   * @returns {Array} - Array of pending actions
   */
  async getPending() {
    try {
      const tx = this.db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const index = store.index('module_status');

      // Get all actions for this module with status='pending'
      const actions = await index.getAll([this.moduleId, 'pending']);

      console.log(`[ActionQueue] Found ${actions.length} pending action(s)`);
      return actions;

    } catch (err) {
      console.error('[ActionQueue] Error getting pending actions:', err);
      throw new Error(`Failed to get pending actions: ${err.message}`);
    }
  }

  /**
   * Get all actions for this module (any status)
   * @returns {Array} - Array of all actions
   */
  async getAll() {
    try {
      const tx = this.db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const index = store.index('module_id');

      const actions = await index.getAll(this.moduleId);

      console.log(`[ActionQueue] Found ${actions.length} total action(s)`);
      return actions;

    } catch (err) {
      console.error('[ActionQueue] Error getting all actions:', err);
      throw new Error(`Failed to get all actions: ${err.message}`);
    }
  }

  /**
   * Get pending count for this module
   * @returns {number} - Count of pending actions
   */
  async getPendingCount() {
    try {
      const pending = await this.getPending();
      return pending.length;
    } catch (err) {
      console.error('[ActionQueue] Error getting pending count:', err);
      return 0;
    }
  }

  /**
   * Mark action as synced
   * @param {number} actionId - Action ID
   */
  async markSynced(actionId) {
    try {
      const tx = this.db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);

      const action = await store.get(actionId);
      if (!action) {
        console.warn(`[ActionQueue] Action ${actionId} not found`);
        return;
      }

      action.status = 'synced';
      action.synced_at = Date.now();

      await store.put(action);
      await tx.done;

      console.log(`[ActionQueue] Marked action ${actionId} as synced`);

    } catch (err) {
      console.error('[ActionQueue] Error marking as synced:', err);
      throw new Error(`Failed to mark action as synced: ${err.message}`);
    }
  }

  /**
   * Mark action as failed
   * @param {number} actionId - Action ID
   * @param {string} error - Error message
   */
  async markFailed(actionId, error) {
    try {
      const tx = this.db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);

      const action = await store.get(actionId);
      if (!action) {
        console.warn(`[ActionQueue] Action ${actionId} not found`);
        return;
      }

      action.status = 'failed';
      action.error = error;
      action.retry_count += 1;
      action.last_attempt_at = Date.now();

      await store.put(action);
      await tx.done;

      console.log(`[ActionQueue] Marked action ${actionId} as failed (retry ${action.retry_count})`);

    } catch (err) {
      console.error('[ActionQueue] Error marking as failed:', err);
      throw new Error(`Failed to mark action as failed: ${err.message}`);
    }
  }

  /**
   * Delete an action
   * @param {number} actionId - Action ID
   */
  async delete(actionId) {
    try {
      const tx = this.db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);

      await store.delete(actionId);
      await tx.done;

      console.log(`[ActionQueue] Deleted action ${actionId}`);

    } catch (err) {
      console.error('[ActionQueue] Error deleting action:', err);
      throw new Error(`Failed to delete action: ${err.message}`);
    }
  }

  /**
   * Clear all actions for this module
   */
  async clear() {
    try {
      const actions = await this.getAll();

      const tx = this.db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);

      for (const action of actions) {
        await store.delete(action.id);
      }

      await tx.done;

      console.log(`[ActionQueue] Cleared all actions for module: ${this.moduleId}`);

    } catch (err) {
      console.error('[ActionQueue] Error clearing actions:', err);
      throw new Error(`Failed to clear actions: ${err.message}`);
    }
  }

  /**
   * Get action by ID
   * @param {number} actionId - Action ID
   * @returns {object} - Action object
   */
  async get(actionId) {
    try {
      const tx = this.db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);

      const action = await store.get(actionId);

      if (!action) {
        console.warn(`[ActionQueue] Action ${actionId} not found`);
        return null;
      }

      return action;

    } catch (err) {
      console.error('[ActionQueue] Error getting action:', err);
      throw new Error(`Failed to get action: ${err.message}`);
    }
  }
}

export default ActionQueue;

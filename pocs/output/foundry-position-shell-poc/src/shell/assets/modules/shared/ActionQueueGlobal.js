/**
 * ActionQueue Global Wrapper
 *
 * Provides a simplified global API for modules to interact with the action queue
 * This is a wrapper around IndexedDB for storing actions
 */

(function() {
  'use strict';

  console.log('[ActionQueueGlobal] Initializing global ActionQueue API');

  // Simple ActionQueue implementation using IndexedDB
  class ActionQueueImpl {
    constructor() {
      this.db = null;
      this.dbName = 'action_queue_db';
      this.storeName = 'actions';
      this.initialized = false;
    }

    /**
     * Check if ActionQueue is available
     */
    isAvailable() {
      return typeof indexedDB !== 'undefined';
    }

    /**
     * Initialize the database
     */
    async initialize() {
      if (this.initialized) {
        return true;
      }

      try {
        return new Promise((resolve, reject) => {
          const request = indexedDB.open(this.dbName, 1);

          request.onerror = () => {
            console.error('[ActionQueueGlobal] Failed to open database');
            reject(new Error('Failed to open database'));
          };

          request.onsuccess = () => {
            this.db = request.result;
            this.initialized = true;
            console.log('[ActionQueueGlobal] Database initialized');
            resolve(true);
          };

          request.onupgradeneeded = (event) => {
            const db = event.target.result;

            if (!db.objectStoreNames.contains(this.storeName)) {
              const store = db.createObjectStore(this.storeName, {
                keyPath: 'id',
                autoIncrement: true
              });

              store.createIndex('module_id', 'module_id');
              store.createIndex('status', 'status');
              store.createIndex('module_status', ['module_id', 'status']);
              store.createIndex('created_at', 'created_at');

              console.log('[ActionQueueGlobal] Created object store');
            }
          };
        });
      } catch (err) {
        console.error('[ActionQueueGlobal] Initialization error:', err);
        throw err;
      }
    }

    /**
     * Save an action
     */
    async save(moduleId, actionType, payload) {
      await this.ensureInitialized();

      return new Promise((resolve, reject) => {
        const action = {
          module_id: moduleId,
          action_type: actionType,
          payload: payload,
          status: 'pending',
          created_at: Date.now(),
          retry_count: 0,
          error: null
        };

        const tx = this.db.transaction([this.storeName], 'readwrite');
        const store = tx.objectStore(this.storeName);
        const request = store.add(action);

        request.onsuccess = () => {
          console.log(`[ActionQueueGlobal] Saved action: ${actionType} (ID: ${request.result})`);
          resolve(request.result);
        };

        request.onerror = () => {
          console.error('[ActionQueueGlobal] Error saving action:', request.error);
          reject(request.error);
        };
      });
    }

    /**
     * Get pending actions for a module
     */
    async getPending(moduleId) {
      await this.ensureInitialized();

      return new Promise((resolve, reject) => {
        const tx = this.db.transaction([this.storeName], 'readonly');
        const store = tx.objectStore(this.storeName);
        const index = store.index('module_status');
        const request = index.getAll([moduleId, 'pending']);

        request.onsuccess = () => {
          console.log(`[ActionQueueGlobal] Found ${request.result.length} pending actions for ${moduleId}`);
          resolve(request.result);
        };

        request.onerror = () => {
          console.error('[ActionQueueGlobal] Error getting pending actions:', request.error);
          reject(request.error);
        };
      });
    }

    /**
     * Get pending count for a module
     */
    async getPendingCount(moduleId) {
      try {
        const pending = await this.getPending(moduleId);
        return pending.length;
      } catch (err) {
        console.error('[ActionQueueGlobal] Error getting pending count:', err);
        return 0;
      }
    }

    /**
     * Mark action as synced
     */
    async markSynced(actionId) {
      await this.ensureInitialized();

      return new Promise((resolve, reject) => {
        const tx = this.db.transaction([this.storeName], 'readwrite');
        const store = tx.objectStore(this.storeName);
        const getRequest = store.get(actionId);

        getRequest.onsuccess = () => {
          const action = getRequest.result;
          if (!action) {
            console.warn(`[ActionQueueGlobal] Action ${actionId} not found`);
            resolve();
            return;
          }

          action.status = 'synced';
          action.synced_at = Date.now();

          const putRequest = store.put(action);
          putRequest.onsuccess = () => {
            console.log(`[ActionQueueGlobal] Marked action ${actionId} as synced`);
            resolve();
          };
          putRequest.onerror = () => {
            console.error('[ActionQueueGlobal] Error updating action:', putRequest.error);
            reject(putRequest.error);
          };
        };

        getRequest.onerror = () => {
          console.error('[ActionQueueGlobal] Error getting action:', getRequest.error);
          reject(getRequest.error);
        };
      });
    }

    /**
     * Ensure database is initialized
     */
    async ensureInitialized() {
      if (!this.initialized) {
        await this.initialize();
      }
    }
  }

  // Create global instance
  window.ActionQueue = new ActionQueueImpl();

  // Auto-initialize
  window.ActionQueue.initialize()
    .then(() => {
      console.log('[ActionQueueGlobal] ✅ ActionQueue ready');
    })
    .catch(err => {
      console.error('[ActionQueueGlobal] ❌ Failed to initialize:', err);
    });

  console.log('[ActionQueueGlobal] ✅ Global ActionQueue API loaded');
})();

/**
 * SyncManager - Handles automatic syncing of offline data
 *
 * Responsibilities:
 * - Monitor network connectivity
 * - Auto-sync pending transactions, water checks, and complaints when online
 * - Retry failed syncs with exponential backoff
 * - Update sync status in RxDB
 */

import { submitTransactionToAPI } from '../api/TransactionAPI.js';

export class SyncManager {
  constructor(database) {
    if (!database) {
      throw new Error('Database instance is required');
    }

    this.db = database;
    this.isOnline = navigator.onLine;
    this.isSyncing = false;
    this.syncListeners = [];

    // Bind methods
    this.handleOnline = this.handleOnline.bind(this);
    this.handleOffline = this.handleOffline.bind(this);
    this.handleConnectivityChange = this.handleConnectivityChange.bind(this);

    // Set up connectivity listeners
    this.setupConnectivityListeners();

    console.log('[SyncManager] Initialized. Online:', this.isOnline);
  }

  /**
   * Set up connectivity event listeners
   */
  setupConnectivityListeners() {
    // Browser online/offline events
    window.addEventListener('online', this.handleOnline);
    window.addEventListener('offline', this.handleOffline);

    // Flutter connectivity bridge event
    window.onConnectivityChange = this.handleConnectivityChange;

    console.log('[SyncManager] Connectivity listeners registered');
  }

  /**
   * Handle browser online event
   */
  handleOnline() {
    console.log('[SyncManager] Browser reported ONLINE');
    this.isOnline = true;
    this.notifyListeners({ online: true, source: 'browser' });
    this.syncPendingTransactions();
    this.syncPendingWaterChecks();
    this.syncPendingComplaints();
  }

  /**
   * Handle browser offline event
   */
  handleOffline() {
    console.log('[SyncManager] Browser reported OFFLINE');
    this.isOnline = false;
    this.notifyListeners({ online: false, source: 'browser' });
  }

  /**
   * Handle Flutter connectivity change event
   */
  handleConnectivityChange(event) {
    console.log('[SyncManager] Flutter connectivity change:', event);
    const wasOnline = this.isOnline;
    this.isOnline = event.online;

    this.notifyListeners({ online: event.online, source: 'flutter' });

    // Trigger sync if we just came online
    if (!wasOnline && this.isOnline) {
      console.log('[SyncManager] Connectivity restored, triggering sync for all types');
      this.syncPendingTransactions();
      this.syncPendingWaterChecks();
      this.syncPendingComplaints();
    }
  }

  /**
   * Add listener for connectivity changes
   */
  addConnectivityListener(callback) {
    this.syncListeners.push(callback);
  }

  /**
   * Remove connectivity listener
   */
  removeConnectivityListener(callback) {
    this.syncListeners = this.syncListeners.filter(cb => cb !== callback);
  }

  /**
   * Notify all listeners of connectivity change
   */
  notifyListeners(event) {
    this.syncListeners.forEach(callback => {
      try {
        callback(event);
      } catch (error) {
        console.error('[SyncManager] Listener error:', error);
      }
    });
  }

  /**
   * Sync all pending transactions
   */
  async syncPendingTransactions() {
    if (!this.isOnline) {
      console.log('[SyncManager] Cannot sync: offline');
      return { success: false, reason: 'offline' };
    }

    if (this.isSyncing) {
      console.log('[SyncManager] Sync already in progress');
      return { success: false, reason: 'already_syncing' };
    }

    this.isSyncing = true;
    console.log('[SyncManager] Starting sync...');

    try {
      // Query pending transactions
      const pendingTransactions = await this.db.transactions
        .find({
          selector: {
            syncStatus: { $in: ['pending', 'failed'] }
          },
          sort: [{ createdAt: 'asc' }]
        })
        .exec();

      console.log(`[SyncManager] Found ${pendingTransactions.length} pending transactions`);

      if (pendingTransactions.length === 0) {
        this.isSyncing = false;
        return { success: true, synced: 0 };
      }

      // Sync in batches of 10
      const results = await this.syncBatch(pendingTransactions, 10);

      this.isSyncing = false;

      console.log('[SyncManager] Sync complete:', results);
      return results;

    } catch (error) {
      console.error('[SyncManager] Sync error:', error);
      this.isSyncing = false;
      return { success: false, error: error.message };
    }
  }

  /**
   * Sync transactions in batches
   */
  async syncBatch(transactions, batchSize = 10) {
    let synced = 0;
    let failed = 0;

    // Process in batches
    for (let i = 0; i < transactions.length; i += batchSize) {
      const batch = transactions.slice(i, i + batchSize);

      console.log(`[SyncManager] Processing batch ${i / batchSize + 1} (${batch.length} items)`);

      // Sync each transaction in the batch
      for (const transaction of batch) {
        try {
          const result = await this.syncTransaction(transaction);
          if (result.success) {
            synced++;
          } else {
            failed++;
          }

          // 2-second delay for demo visibility
          await this.delay(2000);

        } catch (error) {
          console.error('[SyncManager] Batch sync error:', error);
          failed++;
        }

        // Check if we went offline during sync
        if (!this.isOnline) {
          console.log('[SyncManager] Went offline during sync, stopping');
          break;
        }
      }

      // Stop processing if offline
      if (!this.isOnline) {
        break;
      }
    }

    return {
      success: true,
      synced,
      failed,
      total: transactions.length
    };
  }

  /**
   * Sync a single transaction
   */
  async syncTransaction(transaction) {
    const txData = transaction.toJSON();

    console.log(`[SyncManager] Syncing transaction ${txData.transactionId}...`);

    // Update status to syncing
    try {
      await transaction.update({
        $set: {
          syncStatus: 'syncing',
          lastSyncAttempt: Date.now()
        }
      });
    } catch (error) {
      console.error('[SyncManager] Failed to update transaction status:', error);
    }

    try {
      // Submit to API
      const response = await submitTransactionToAPI(txData);

      if (response.success) {
        // Update to synced
        await transaction.update({
          $set: {
            syncStatus: 'synced',
            retryCount: 0,
            lastError: null,
            lastSyncAttempt: Date.now()
          }
        });

        console.log(`[SyncManager] Transaction ${txData.transactionId} synced successfully`);
        return { success: true };

      } else {
        // API returned error
        throw new Error(response.error || 'API error');
      }

    } catch (error) {
      console.error(`[SyncManager] Sync failed for ${txData.transactionId}:`, error);

      // Update retry count
      const newRetryCount = txData.retryCount + 1;
      const maxRetries = 3;

      if (newRetryCount >= maxRetries) {
        // Max retries reached, mark as failed
        await transaction.update({
          $set: {
            syncStatus: 'failed',
            retryCount: newRetryCount,
            lastError: error.message,
            lastSyncAttempt: Date.now()
          }
        });

        console.log(`[SyncManager] Transaction ${txData.transactionId} marked as FAILED (max retries)`);

      } else {
        // Mark as pending for retry with backoff
        await transaction.update({
          $set: {
            syncStatus: 'pending',
            retryCount: newRetryCount,
            lastError: error.message,
            lastSyncAttempt: Date.now()
          }
        });

        console.log(`[SyncManager] Transaction ${txData.transactionId} will retry (attempt ${newRetryCount}/${maxRetries})`);

        // Schedule retry with exponential backoff
        const backoffDelay = Math.pow(2, newRetryCount) * 1000; // 2s, 4s, 8s
        console.log(`[SyncManager] Next retry in ${backoffDelay / 1000}s`);

        setTimeout(() => {
          if (this.isOnline && !this.isSyncing) {
            this.syncPendingTransactions();
          }
        }, backoffDelay);
      }

      return { success: false, error: error.message };
    }
  }

  /**
   * Sync all pending water checks
   */
  async syncPendingWaterChecks() {
    if (!this.isOnline) {
      console.log('[SyncManager] Cannot sync water checks: offline');
      return { success: false, reason: 'offline' };
    }

    if (this.isSyncing) {
      console.log('[SyncManager] Sync already in progress');
      return { success: false, reason: 'already_syncing' };
    }

    this.isSyncing = true;
    console.log('[SyncManager] Starting water check sync...');

    try {
      const pendingChecks = await this.db.waterchecks
        .find({
          selector: {
            syncStatus: { $in: ['pending', 'failed'] }
          },
          sort: [{ createdAt: 'asc' }]
        })
        .exec();

      console.log(`[SyncManager] Found ${pendingChecks.length} pending water checks`);

      if (pendingChecks.length === 0) {
        this.isSyncing = false;
        return { success: true, synced: 0 };
      }

      const results = await this.syncWaterCheckBatch(pendingChecks);
      this.isSyncing = false;

      console.log('[SyncManager] Water check sync complete:', results);
      return results;

    } catch (error) {
      console.error('[SyncManager] Water check sync error:', error);
      this.isSyncing = false;
      return { success: false, error: error.message };
    }
  }

  /**
   * Sync water checks in batch
   */
  async syncWaterCheckBatch(checks) {
    let synced = 0;
    let failed = 0;

    for (const check of checks) {
      try {
        const result = await this.syncWaterCheck(check);
        if (result.success) {
          synced++;
        } else {
          failed++;
        }
        await this.delay(1000);
      } catch (error) {
        console.error('[SyncManager] Water check batch sync error:', error);
        failed++;
      }

      if (!this.isOnline) {
        console.log('[SyncManager] Went offline during water check sync');
        break;
      }
    }

    return { success: true, synced, failed, total: checks.length };
  }

  /**
   * Sync a single water check
   */
  async syncWaterCheck(check) {
    const checkData = check.toJSON();
    console.log(`[SyncManager] Syncing water check ${checkData.id}...`);

    try {
      await check.update({
        $set: {
          syncStatus: 'syncing',
          lastSyncAttempt: Date.now()
        }
      });
    } catch (error) {
      console.error('[SyncManager] Failed to update water check status:', error);
    }

    try {
      const response = await fetch('http://192.168.0.163:3000/api/water-temp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(checkData)
      });

      if (response.ok) {
        await check.update({
          $set: {
            syncStatus: 'synced',
            retryCount: 0,
            lastError: null,
            lastSyncAttempt: Date.now()
          }
        });

        console.log(`[SyncManager] ✓ Water check ${checkData.id} synced`);
        return { success: true };
      } else {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch (error) {
      console.error(`[SyncManager] Sync failed for water check ${checkData.id}:`, error);

      const newRetryCount = checkData.retryCount + 1;
      const maxRetries = 3;

      if (newRetryCount >= maxRetries) {
        await check.update({
          $set: {
            syncStatus: 'failed',
            retryCount: newRetryCount,
            lastError: error.message,
            lastSyncAttempt: Date.now()
          }
        });
        console.log(`[SyncManager] Water check ${checkData.id} marked as FAILED`);
      } else {
        await check.update({
          $set: {
            syncStatus: 'pending',
            retryCount: newRetryCount,
            lastError: error.message,
            lastSyncAttempt: Date.now()
          }
        });
        console.log(`[SyncManager] Water check ${checkData.id} will retry (${newRetryCount}/${maxRetries})`);
      }

      return { success: false, error: error.message };
    }
  }

  /**
   * Sync all pending complaints
   */
  async syncPendingComplaints() {
    if (!this.isOnline) {
      console.log('[SyncManager] Cannot sync complaints: offline');
      return { success: false, reason: 'offline' };
    }

    if (this.isSyncing) {
      console.log('[SyncManager] Sync already in progress');
      return { success: false, reason: 'already_syncing' };
    }

    this.isSyncing = true;
    console.log('[SyncManager] Starting complaint sync...');

    try {
      const pendingComplaints = await this.db.complaints
        .find({
          selector: {
            syncStatus: { $in: ['pending', 'failed'] }
          },
          sort: [{ createdAt: 'asc' }]
        })
        .exec();

      console.log(`[SyncManager] Found ${pendingComplaints.length} pending complaints`);

      if (pendingComplaints.length === 0) {
        this.isSyncing = false;
        return { success: true, synced: 0 };
      }

      const results = await this.syncComplaintBatch(pendingComplaints);
      this.isSyncing = false;

      console.log('[SyncManager] Complaint sync complete:', results);
      return results;

    } catch (error) {
      console.error('[SyncManager] Complaint sync error:', error);
      this.isSyncing = false;
      return { success: false, error: error.message };
    }
  }

  /**
   * Sync complaints in batch
   */
  async syncComplaintBatch(complaints) {
    let synced = 0;
    let failed = 0;

    for (const complaint of complaints) {
      try {
        const result = await this.syncComplaint(complaint);
        if (result.success) {
          synced++;
        } else {
          failed++;
        }
        await this.delay(1000);
      } catch (error) {
        console.error('[SyncManager] Complaint batch sync error:', error);
        failed++;
      }

      if (!this.isOnline) {
        console.log('[SyncManager] Went offline during complaint sync');
        break;
      }
    }

    return { success: true, synced, failed, total: complaints.length };
  }

  /**
   * Sync a single complaint
   */
  async syncComplaint(complaint) {
    const complaintData = complaint.toJSON();
    console.log(`[SyncManager] Syncing complaint ${complaintData.id}...`);

    try {
      await complaint.update({
        $set: {
          syncStatus: 'syncing',
          lastSyncAttempt: Date.now()
        }
      });
    } catch (error) {
      console.error('[SyncManager] Failed to update complaint status:', error);
    }

    try {
      const response = await fetch('http://192.168.0.163:3000/api/complaints', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(complaintData)
      });

      if (response.ok) {
        await complaint.update({
          $set: {
            syncStatus: 'synced',
            retryCount: 0,
            lastError: null,
            lastSyncAttempt: Date.now()
          }
        });

        console.log(`[SyncManager] ✓ Complaint ${complaintData.id} synced`);
        return { success: true };
      } else {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch (error) {
      console.error(`[SyncManager] Sync failed for complaint ${complaintData.id}:`, error);

      const newRetryCount = complaintData.retryCount + 1;
      const maxRetries = 3;

      if (newRetryCount >= maxRetries) {
        await complaint.update({
          $set: {
            syncStatus: 'failed',
            retryCount: newRetryCount,
            lastError: error.message,
            lastSyncAttempt: Date.now()
          }
        });
        console.log(`[SyncManager] Complaint ${complaintData.id} marked as FAILED`);
      } else {
        await complaint.update({
          $set: {
            syncStatus: 'pending',
            retryCount: newRetryCount,
            lastError: error.message,
            lastSyncAttempt: Date.now()
          }
        });
        console.log(`[SyncManager] Complaint ${complaintData.id} will retry (${newRetryCount}/${maxRetries})`);
      }

      return { success: false, error: error.message };
    }
  }

  /**
   * Manual sync trigger for all types
   */
  async forceSyncNow() {
    console.log('[SyncManager] Manual sync triggered for all types');
    await this.syncPendingTransactions();
    await this.syncPendingWaterChecks();
    await this.syncPendingComplaints();
  }

  /**
   * Get sync status for all types
   */
  async getSyncStatus() {
    try {
      // Transactions
      const txPending = await this.db.transactions.find({ selector: { syncStatus: 'pending' } }).exec();
      const txSyncing = await this.db.transactions.find({ selector: { syncStatus: 'syncing' } }).exec();
      const txFailed = await this.db.transactions.find({ selector: { syncStatus: 'failed' } }).exec();
      const txSynced = await this.db.transactions.find({ selector: { syncStatus: 'synced' } }).exec();

      // Water checks
      const wcPending = await this.db.waterchecks.find({ selector: { syncStatus: 'pending' } }).exec();
      const wcSyncing = await this.db.waterchecks.find({ selector: { syncStatus: 'syncing' } }).exec();
      const wcFailed = await this.db.waterchecks.find({ selector: { syncStatus: 'failed' } }).exec();
      const wcSynced = await this.db.waterchecks.find({ selector: { syncStatus: 'synced' } }).exec();

      // Complaints
      const coPending = await this.db.complaints.find({ selector: { syncStatus: 'pending' } }).exec();
      const coSyncing = await this.db.complaints.find({ selector: { syncStatus: 'syncing' } }).exec();
      const coFailed = await this.db.complaints.find({ selector: { syncStatus: 'failed' } }).exec();
      const coSynced = await this.db.complaints.find({ selector: { syncStatus: 'synced' } }).exec();

      return {
        transactions: {
          pending: txPending.length,
          syncing: txSyncing.length,
          failed: txFailed.length,
          synced: txSynced.length,
          total: txPending.length + txSyncing.length + txFailed.length + txSynced.length
        },
        waterChecks: {
          pending: wcPending.length,
          syncing: wcSyncing.length,
          failed: wcFailed.length,
          synced: wcSynced.length,
          total: wcPending.length + wcSyncing.length + wcFailed.length + wcSynced.length
        },
        complaints: {
          pending: coPending.length,
          syncing: coSyncing.length,
          failed: coFailed.length,
          synced: coSynced.length,
          total: coPending.length + coSyncing.length + coFailed.length + coSynced.length
        },
        overall: {
          pending: txPending.length + wcPending.length + coPending.length,
          syncing: txSyncing.length + wcSyncing.length + coSyncing.length,
          failed: txFailed.length + wcFailed.length + coFailed.length,
          synced: txSynced.length + wcSynced.length + coSynced.length
        },
        isOnline: this.isOnline,
        isSyncing: this.isSyncing
      };

    } catch (error) {
      console.error('[SyncManager] Failed to get sync status:', error);
      return null;
    }
  }

  /**
   * Delay helper
   */
  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Clean up listeners
   */
  destroy() {
    window.removeEventListener('online', this.handleOnline);
    window.removeEventListener('offline', this.handleOffline);
    window.onConnectivityChange = null;
    this.syncListeners = [];
    console.log('[SyncManager] Destroyed');
  }
}

/**
 * RxDB Bundle for Warehouse Module
 *
 * This file bundles RxDB initialization and SyncManager
 * to be used in index.html without ES module imports
 */

// Import RxDB (assuming it's loaded from CDN in index.html)
// Add this to index.html <head>:
// <script src="https://cdn.jsdelivr.net/npm/rxdb@15.0.0/dist/rxdb.min.js"></script>

const RxDBBundle = (function() {
    'use strict';

    // ============================================
    // SCHEMAS
    // ============================================

    const transactionSchema = {
        title: 'Receiving Transaction Schema',
        version: 0,
        description: 'Schema for offline receiving transactions',
        primaryKey: 'transactionId',
        type: 'object',
        properties: {
            transactionId: { type: 'string', maxLength: 100 },
            poNumber: { type: 'string', maxLength: 50 },
            vendor: { type: 'string', maxLength: 100 },
            lineItems: {
                type: 'array',
                items: {
                    type: 'object',
                    properties: {
                        sku: { type: 'string' },
                        description: { type: 'string' },
                        quantity: { type: ['string', 'number'] },
                        location: { type: 'string' },
                        photos: {
                            type: 'array',
                            items: {
                                type: 'object',
                                properties: {
                                    path: { type: 'string' },
                                    thumbnailPath: { type: 'string' },
                                    timestamp: { type: 'number' }
                                }
                            }
                        }
                    }
                }
            },
            createdAt: { type: 'number', minimum: 0 },
            syncStatus: {
                type: 'string',
                enum: ['pending', 'syncing', 'synced', 'failed'],
                default: 'pending'
            },
            retryCount: { type: 'number', minimum: 0, maximum: 10, default: 0 },
            lastError: { type: ['string', 'null'], default: null },
            lastSyncAttempt: { type: ['number', 'null'], default: null }
        },
        required: ['transactionId', 'poNumber', 'vendor', 'lineItems', 'createdAt', 'syncStatus'],
        indexes: ['syncStatus', 'createdAt']
    };

    const waterCheckSchema = {
        title: 'Water Check Schema',
        version: 0,
        primaryKey: 'id',
        type: 'object',
        properties: {
            id: { type: 'string', maxLength: 100 },
            product: { type: 'string', maxLength: 100 },
            tempF: { type: 'number' },
            tempC: { type: 'number' },
            timestamp: { type: 'number', minimum: 0 },
            photo: { type: ['string', 'null'], default: null },
            createdAt: { type: 'number', minimum: 0 },
            syncStatus: {
                type: 'string',
                enum: ['pending', 'syncing', 'synced', 'failed'],
                default: 'pending'
            },
            retryCount: { type: 'number', minimum: 0, maximum: 10, default: 0 },
            lastError: { type: ['string', 'null'], default: null },
            lastSyncAttempt: { type: ['number', 'null'], default: null }
        },
        required: ['id', 'product', 'tempF', 'tempC', 'timestamp', 'createdAt', 'syncStatus'],
        indexes: ['syncStatus', 'createdAt', 'product']
    };

    const complaintSchema = {
        title: 'Complaint Schema',
        version: 0,
        primaryKey: 'id',
        type: 'object',
        properties: {
            id: { type: 'string', maxLength: 100 },
            product: { type: 'string', maxLength: 100 },
            issue: { type: 'string', maxLength: 50 },
            description: { type: 'string' },
            timestamp: { type: 'number', minimum: 0 },
            photo: { type: ['string', 'null'], default: null },
            createdAt: { type: 'number', minimum: 0 },
            syncStatus: {
                type: 'string',
                enum: ['pending', 'syncing', 'synced', 'failed'],
                default: 'pending'
            },
            retryCount: { type: 'number', minimum: 0, maximum: 10, default: 0 },
            lastError: { type: ['string', 'null'], default: null },
            lastSyncAttempt: { type: ['number', 'null'], default: null }
        },
        required: ['id', 'product', 'issue', 'description', 'timestamp', 'createdAt', 'syncStatus'],
        indexes: ['syncStatus', 'createdAt', 'product', 'issue']
    };

    // ============================================
    // DATABASE INITIALIZATION
    // ============================================

    let dbInstance = null;

    async function initRxDatabase() {
        if (dbInstance) {
            console.log('[RxDB] Using existing database instance');
            return dbInstance;
        }

        console.log('[RxDB] Initializing RxDB database...');

        try {
            // Request persistent storage
            if (navigator.storage && navigator.storage.persist) {
                const isPersisted = await navigator.storage.persisted();
                console.log('[RxDB] Storage persisted:', isPersisted);
                if (!isPersisted) {
                    const granted = await navigator.storage.persist();
                    console.log('[RxDB] Persistence granted:', granted);
                }
            }

            // Create RxDB database using Dexie storage
            const db = await RxDB.createRxDatabase({
                name: 'warehouse_offline_db',
                storage: RxDB.getRxStorageDexie(),
                multiInstance: false,
                eventReduce: true,
                ignoreDuplicate: true
            });

            console.log('[RxDB] Database created');

            // Add collections
            await db.addCollections({
                transactions: { schema: transactionSchema },
                waterchecks: { schema: waterCheckSchema },
                complaints: { schema: complaintSchema }
            });

            console.log('[RxDB] ✅ Collections added (transactions, waterchecks, complaints)');

            dbInstance = db;
            return db;

        } catch (error) {
            console.error('[RxDB] Initialization failed:', error);
            throw error;
        }
    }

    // ============================================
    // SYNC MANAGER
    // ============================================

    class SimpleSyncManager {
        constructor(database) {
            this.db = database;
            this.isOnline = navigator.onLine;
            this.isSyncing = false;
            this.listeners = [];

            // Bind methods
            this.handleOnline = this.handleOnline.bind(this);
            this.handleOffline = this.handleOffline.bind(this);

            // Setup event listeners
            window.addEventListener('online', this.handleOnline);
            window.addEventListener('offline', this.handleOffline);

            console.log('[SyncManager] Initialized with RxDB. Online:', this.isOnline);
        }

        handleOnline() {
            console.log('[SyncManager] Network ONLINE - triggering sync for all types');
            this.isOnline = true;
            this.notifyListeners({ online: true });

            // Sync all types
            this.syncPendingTransactions();
            this.syncPendingWaterChecks();
            this.syncPendingComplaints();
        }

        handleOffline() {
            console.log('[SyncManager] Network OFFLINE');
            this.isOnline = false;
            this.notifyListeners({ online: false });
        }

        addListener(callback) {
            this.listeners.push(callback);
        }

        notifyListeners(event) {
            this.listeners.forEach(cb => cb(event));
        }

        // ============================================
        // TRANSACTION SYNC
        // ============================================

        async syncPendingTransactions() {
            if (!this.isOnline || this.isSyncing) return;

            this.isSyncing = true;
            console.log('[SyncManager] Starting transaction sync...');

            try {
                const pendingDocs = await this.db.transactions
                    .find({ selector: { syncStatus: { $in: ['pending', 'failed'] } } })
                    .exec();

                console.log(`[SyncManager] Found ${pendingDocs.length} pending transactions`);

                for (const doc of pendingDocs) {
                    await this.syncTransaction(doc);
                    await this.delay(1000);
                    if (!this.isOnline) break;
                }
            } catch (error) {
                console.error('[SyncManager] Transaction sync error:', error);
            } finally {
                this.isSyncing = false;
            }
        }

        async syncTransaction(doc) {
            const data = doc.toJSON();
            console.log(`[SyncManager] Syncing TXN-${data.transactionId}...`);

            try {
                await doc.update({ $set: { syncStatus: 'syncing', lastSyncAttempt: Date.now() } });

                const response = await fetch('http://192.168.0.163:3000/api/transactions', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });

                if (response.ok) {
                    await doc.update({
                        $set: {
                            syncStatus: 'synced',
                            retryCount: 0,
                            lastError: null,
                            lastSyncAttempt: Date.now()
                        }
                    });
                    console.log(`[SyncManager] ✓ TXN-${data.transactionId} synced`);
                } else {
                    throw new Error(`HTTP ${response.status}`);
                }
            } catch (error) {
                console.error(`[SyncManager] ✗ TXN-${data.transactionId} failed:`, error);
                const newRetryCount = data.retryCount + 1;
                const newStatus = newRetryCount >= 3 ? 'failed' : 'pending';
                await doc.update({
                    $set: {
                        syncStatus: newStatus,
                        retryCount: newRetryCount,
                        lastError: error.message,
                        lastSyncAttempt: Date.now()
                    }
                });
            }
        }

        // ============================================
        // WATER CHECK SYNC
        // ============================================

        async syncPendingWaterChecks() {
            if (!this.isOnline || this.isSyncing) return;

            this.isSyncing = true;
            console.log('[SyncManager] Starting water check sync...');

            try {
                const pendingDocs = await this.db.waterchecks
                    .find({ selector: { syncStatus: { $in: ['pending', 'failed'] } } })
                    .exec();

                console.log(`[SyncManager] Found ${pendingDocs.length} pending water checks`);

                for (const doc of pendingDocs) {
                    await this.syncWaterCheck(doc);
                    await this.delay(1000);
                    if (!this.isOnline) break;
                }
            } catch (error) {
                console.error('[SyncManager] Water check sync error:', error);
            } finally {
                this.isSyncing = false;
            }
        }

        async syncWaterCheck(doc) {
            const data = doc.toJSON();
            console.log(`[SyncManager] Syncing water check ${data.id}...`);

            try {
                await doc.update({ $set: { syncStatus: 'syncing', lastSyncAttempt: Date.now() } });

                const response = await fetch('http://192.168.0.163:3000/api/water-temp', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });

                if (response.ok) {
                    await doc.update({
                        $set: {
                            syncStatus: 'synced',
                            retryCount: 0,
                            lastError: null,
                            lastSyncAttempt: Date.now()
                        }
                    });
                    console.log(`[SyncManager] ✓ Water check ${data.id} synced`);
                } else {
                    throw new Error(`HTTP ${response.status}`);
                }
            } catch (error) {
                console.error(`[SyncManager] ✗ Water check ${data.id} failed:`, error);
                const newRetryCount = data.retryCount + 1;
                const newStatus = newRetryCount >= 3 ? 'failed' : 'pending';
                await doc.update({
                    $set: {
                        syncStatus: newStatus,
                        retryCount: newRetryCount,
                        lastError: error.message,
                        lastSyncAttempt: Date.now()
                    }
                });
            }
        }

        // ============================================
        // COMPLAINT SYNC
        // ============================================

        async syncPendingComplaints() {
            if (!this.isOnline || this.isSyncing) return;

            this.isSyncing = true;
            console.log('[SyncManager] Starting complaint sync...');

            try {
                const pendingDocs = await this.db.complaints
                    .find({ selector: { syncStatus: { $in: ['pending', 'failed'] } } })
                    .exec();

                console.log(`[SyncManager] Found ${pendingDocs.length} pending complaints`);

                for (const doc of pendingDocs) {
                    await this.syncComplaint(doc);
                    await this.delay(1000);
                    if (!this.isOnline) break;
                }
            } catch (error) {
                console.error('[SyncManager] Complaint sync error:', error);
            } finally {
                this.isSyncing = false;
            }
        }

        async syncComplaint(doc) {
            const data = doc.toJSON();
            console.log(`[SyncManager] Syncing complaint ${data.id}...`);

            try {
                await doc.update({ $set: { syncStatus: 'syncing', lastSyncAttempt: Date.now() } });

                const response = await fetch('http://192.168.0.163:3000/api/complaints', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });

                if (response.ok) {
                    await doc.update({
                        $set: {
                            syncStatus: 'synced',
                            retryCount: 0,
                            lastError: null,
                            lastSyncAttempt: Date.now()
                        }
                    });
                    console.log(`[SyncManager] ✓ Complaint ${data.id} synced`);
                } else {
                    throw new Error(`HTTP ${response.status}`);
                }
            } catch (error) {
                console.error(`[SyncManager] ✗ Complaint ${data.id} failed:`, error);
                const newRetryCount = data.retryCount + 1;
                const newStatus = newRetryCount >= 3 ? 'failed' : 'pending';
                await doc.update({
                    $set: {
                        syncStatus: newStatus,
                        retryCount: newRetryCount,
                        lastError: error.message,
                        lastSyncAttempt: Date.now()
                    }
                });
            }
        }

        // ============================================
        // HELPERS
        // ============================================

        delay(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }

        destroy() {
            window.removeEventListener('online', this.handleOnline);
            window.removeEventListener('offline', this.handleOffline);
            this.listeners = [];
        }
    }

    // ============================================
    // PUBLIC API
    // ============================================

    return {
        initRxDatabase,
        SimpleSyncManager
    };

})();

// Make it globally available
window.RxDBBundle = RxDBBundle;

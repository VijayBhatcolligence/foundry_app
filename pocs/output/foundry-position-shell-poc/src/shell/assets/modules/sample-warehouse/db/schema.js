/**
 * RxDB Database Schema for Offline Transactions
 *
 * This schema defines the structure for storing receiving transactions
 * in IndexedDB with offline-first capabilities and automatic sync.
 */

import { createRxDatabase } from 'rxdb';
import { getRxStorageDexie } from 'rxdb/plugins/storage-dexie';

// Transaction schema definition
export const transactionSchema = {
  title: 'Receiving Transaction Schema',
  version: 0,
  description: 'Schema for offline receiving transactions',
  primaryKey: 'transactionId',
  type: 'object',
  properties: {
    transactionId: {
      type: 'string',
      maxLength: 100
    },
    poNumber: {
      type: 'string',
      maxLength: 50
    },
    vendor: {
      type: 'string',
      maxLength: 100
    },
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
    createdAt: {
      type: 'number',
      minimum: 0
    },
    syncStatus: {
      type: 'string',
      enum: ['pending', 'syncing', 'synced', 'failed'],
      default: 'pending'
    },
    retryCount: {
      type: 'number',
      minimum: 0,
      maximum: 10,
      default: 0
    },
    lastError: {
      type: ['string', 'null'],
      default: null
    },
    lastSyncAttempt: {
      type: ['number', 'null'],
      default: null
    }
  },
  required: ['transactionId', 'poNumber', 'vendor', 'lineItems', 'createdAt', 'syncStatus'],
  indexes: ['syncStatus', 'createdAt']
};

// Water Check schema definition
export const waterCheckSchema = {
  title: 'Water Check Schema',
  version: 0,
  description: 'Schema for offline water temperature checks',
  primaryKey: 'id',
  type: 'object',
  properties: {
    id: {
      type: 'string',
      maxLength: 100
    },
    product: {
      type: 'string',
      maxLength: 100
    },
    tempF: {
      type: 'number'
    },
    tempC: {
      type: 'number'
    },
    timestamp: {
      type: 'number',
      minimum: 0
    },
    photo: {
      type: ['string', 'null'],
      default: null
    },
    createdAt: {
      type: 'number',
      minimum: 0
    },
    syncStatus: {
      type: 'string',
      enum: ['pending', 'syncing', 'synced', 'failed'],
      default: 'pending'
    },
    retryCount: {
      type: 'number',
      minimum: 0,
      maximum: 10,
      default: 0
    },
    lastError: {
      type: ['string', 'null'],
      default: null
    },
    lastSyncAttempt: {
      type: ['number', 'null'],
      default: null
    }
  },
  required: ['id', 'product', 'tempF', 'tempC', 'timestamp', 'createdAt', 'syncStatus'],
  indexes: ['syncStatus', 'createdAt', 'product']
};

// Complaint schema definition
export const complaintSchema = {
  title: 'Complaint Schema',
  version: 0,
  description: 'Schema for offline quality complaints',
  primaryKey: 'id',
  type: 'object',
  properties: {
    id: {
      type: 'string',
      maxLength: 100
    },
    product: {
      type: 'string',
      maxLength: 100
    },
    issue: {
      type: 'string',
      maxLength: 50
    },
    description: {
      type: 'string'
    },
    timestamp: {
      type: 'number',
      minimum: 0
    },
    photo: {
      type: ['string', 'null'],
      default: null
    },
    createdAt: {
      type: 'number',
      minimum: 0
    },
    syncStatus: {
      type: 'string',
      enum: ['pending', 'syncing', 'synced', 'failed'],
      default: 'pending'
    },
    retryCount: {
      type: 'number',
      minimum: 0,
      maximum: 10,
      default: 0
    },
    lastError: {
      type: ['string', 'null'],
      default: null
    },
    lastSyncAttempt: {
      type: ['number', 'null'],
      default: null
    }
  },
  required: ['id', 'product', 'issue', 'description', 'timestamp', 'createdAt', 'syncStatus'],
  indexes: ['syncStatus', 'createdAt', 'product', 'issue']
};

// Database instance singleton
let dbInstance = null;
let dbPromise = null;

/**
 * Request persistent storage to prevent data eviction
 */
async function requestPersistentStorage() {
  if (navigator.storage && navigator.storage.persist) {
    try {
      const isPersisted = await navigator.storage.persisted();
      console.log('[Storage] Already persisted:', isPersisted);

      if (!isPersisted) {
        const result = await navigator.storage.persist();
        console.log('[Storage] Persistence request result:', result);
        return result;
      }
      return true;
    } catch (error) {
      console.error('[Storage] Persistence request failed:', error);
      return false;
    }
  } else {
    console.warn('[Storage] Persistent storage API not available');
    return false;
  }
}

/**
 * Get storage quota information
 */
export async function getStorageQuota() {
  if (navigator.storage && navigator.storage.estimate) {
    try {
      const estimate = await navigator.storage.estimate();
      const usage = estimate.usage || 0;
      const quota = estimate.quota || 0;
      const percentUsed = quota > 0 ? (usage / quota) * 100 : 0;

      return {
        usage,
        quota,
        percentUsed,
        usageMB: (usage / (1024 * 1024)).toFixed(2),
        quotaMB: (quota / (1024 * 1024)).toFixed(2)
      };
    } catch (error) {
      console.error('[Storage] Quota estimate failed:', error);
      return null;
    }
  }
  return null;
}

/**
 * Monitor storage quota and warn if approaching limit
 */
export async function monitorStorageQuota() {
  const quota = await getStorageQuota();
  if (!quota) return;

  console.log(`[Storage] Using ${quota.usageMB}MB of ${quota.quotaMB}MB (${quota.percentUsed.toFixed(1)}%)`);

  if (quota.percentUsed > 80) {
    console.warn('[Storage] WARNING: Storage usage above 80%!');
    return { warning: true, quota };
  }

  return { warning: false, quota };
}

/**
 * Initialize RxDB database
 */
export async function initDatabase() {
  // Return existing instance if already initialized
  if (dbInstance) {
    console.log('[Database] Using existing database instance');
    return dbInstance;
  }

  // Return existing promise if initialization is in progress
  if (dbPromise) {
    console.log('[Database] Waiting for database initialization...');
    return dbPromise;
  }

  console.log('[Database] Initializing RxDB database...');

  dbPromise = (async () => {
    try {
      // Request persistent storage
      await requestPersistentStorage();

      // Monitor storage quota
      await monitorStorageQuota();

      // Create RxDB database
      const db = await createRxDatabase({
        name: 'warehouse_offline_db',
        storage: getRxStorageDexie(),
        multiInstance: false, // Single instance per browser tab
        eventReduce: true, // Enable event reduce for better performance
        ignoreDuplicate: true
      });

      console.log('[Database] RxDB database created');

      // Add collections
      await db.addCollections({
        transactions: {
          schema: transactionSchema
        },
        waterchecks: {
          schema: waterCheckSchema
        },
        complaints: {
          schema: complaintSchema
        }
      });

      console.log('[Database] Collections added (transactions, waterchecks, complaints)');

      // Set up indexes for query performance
      console.log('[Database] Database initialized successfully');

      dbInstance = db;
      return db;

    } catch (error) {
      console.error('[Database] Initialization failed:', error);
      dbPromise = null; // Reset promise so retry is possible
      throw error;
    }
  })();

  return dbPromise;
}

/**
 * Get database instance (must be initialized first)
 */
export function getDatabase() {
  if (!dbInstance) {
    throw new Error('Database not initialized. Call initDatabase() first.');
  }
  return dbInstance;
}

/**
 * Close database connection
 */
export async function closeDatabase() {
  if (dbInstance) {
    await dbInstance.destroy();
    dbInstance = null;
    dbPromise = null;
    console.log('[Database] Database closed');
  }
}

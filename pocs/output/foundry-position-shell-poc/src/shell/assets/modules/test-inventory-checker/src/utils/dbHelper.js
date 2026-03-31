import { openDB } from './indexedDBHelper';

const DB_NAME = 'inventory_checker_db';
const DB_VERSION = 1;

/**
 * Initialize the inventory checker database with all required object stores
 * Call this once when the module loads to ensure all stores are created
 */
export async function initDatabase() {
  console.log('[DBHelper] Initializing inventory_checker_db...');

  const db = await openDB(DB_NAME, DB_VERSION, {
    upgrade(db, oldVersion, newVersion, transaction) {
      console.log(`[DBHelper] Upgrading database from v${oldVersion} to v${newVersion}`);

      // Create stock_counts store
      if (!db.objectStoreNames.contains('stock_counts')) {
        const stockCountsStore = db.createObjectStore('stock_counts', {
          keyPath: 'id',
          autoIncrement: true
        });
        stockCountsStore.createIndex('product_id', 'product_id');
        stockCountsStore.createIndex('timestamp', 'timestamp');
        stockCountsStore.createIndex('synced', 'synced');
        console.log('[DBHelper] Created stock_counts object store');
      }

      // Create audit_trails store
      if (!db.objectStoreNames.contains('audit_trails')) {
        const auditTrailsStore = db.createObjectStore('audit_trails', {
          keyPath: 'id',
          autoIncrement: true
        });
        auditTrailsStore.createIndex('timestamp', 'timestamp');
        auditTrailsStore.createIndex('action', 'action');
        console.log('[DBHelper] Created audit_trails object store');
      }
    }
  });

  console.log('[DBHelper] Database initialized successfully');
  return db;
}

/**
 * Get the database instance (assumes already initialized)
 */
export async function getDatabase() {
  return await openDB(DB_NAME, DB_VERSION);
}

export { DB_NAME, DB_VERSION };

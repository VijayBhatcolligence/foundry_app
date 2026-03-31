/**
 * IndexedDB Helper
 * Simplified wrapper for IndexedDB operations
 */

/**
 * Open an IndexedDB database
 * @param {string} dbName - Database name
 * @param {number} version - Database version
 * @param {object} options - Options including upgrade callback
 * @returns {Promise<IDBDatabase>} Database instance
 */
export function openDB(dbName, version = 1, options = {}) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(dbName, version);

    request.onerror = () => {
      reject(new Error(`Failed to open database: ${request.error}`));
    };

    request.onsuccess = () => {
      resolve(request.result);
    };

    request.onupgradeneeded = (event) => {
      const db = event.target.result;

      if (options.upgrade) {
        try {
          options.upgrade(db, event.oldVersion, event.newVersion);
        } catch (error) {
          console.error('[IndexedDB] Upgrade error:', error);
          reject(error);
        }
      }
    };
  });
}

/**
 * Delete a database
 * @param {string} dbName - Database name
 * @returns {Promise<void>}
 */
export function deleteDB(dbName) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.deleteDatabase(dbName);

    request.onerror = () => {
      reject(new Error(`Failed to delete database: ${request.error}`));
    };

    request.onsuccess = () => {
      resolve();
    };
  });
}

/**
 * Get all records from a store
 * @param {IDBDatabase} db - Database instance
 * @param {string} storeName - Object store name
 * @returns {Promise<Array>} All records
 */
export function getAll(db, storeName) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readonly');
    const store = tx.objectStore(storeName);
    const request = store.getAll();

    request.onerror = () => {
      reject(new Error(`Failed to get all: ${request.error}`));
    };

    request.onsuccess = () => {
      resolve(request.result);
    };
  });
}

/**
 * Get a single record by key
 * @param {IDBDatabase} db - Database instance
 * @param {string} storeName - Object store name
 * @param {any} key - Record key
 * @returns {Promise<any>} Record or undefined
 */
export function get(db, storeName, key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readonly');
    const store = tx.objectStore(storeName);
    const request = store.get(key);

    request.onerror = () => {
      reject(new Error(`Failed to get: ${request.error}`));
    };

    request.onsuccess = () => {
      resolve(request.result);
    };
  });
}

/**
 * Add a record to a store
 * @param {IDBDatabase} db - Database instance
 * @param {string} storeName - Object store name
 * @param {any} value - Record to add
 * @returns {Promise<any>} Generated key
 */
export function add(db, storeName, value) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    const store = tx.objectStore(storeName);
    const request = store.add(value);

    request.onerror = () => {
      reject(new Error(`Failed to add: ${request.error}`));
    };

    request.onsuccess = () => {
      resolve(request.result);
    };
  });
}

/**
 * Put a record to a store (add or update)
 * @param {IDBDatabase} db - Database instance
 * @param {string} storeName - Object store name
 * @param {any} value - Record to put
 * @returns {Promise<any>} Key
 */
export function put(db, storeName, value) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    const store = tx.objectStore(storeName);
    const request = store.put(value);

    request.onerror = () => {
      reject(new Error(`Failed to put: ${request.error}`));
    };

    request.onsuccess = () => {
      resolve(request.result);
    };
  });
}

/**
 * Delete a record from a store
 * @param {IDBDatabase} db - Database instance
 * @param {string} storeName - Object store name
 * @param {any} key - Record key
 * @returns {Promise<void>}
 */
export function deleteRecord(db, storeName, key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    const store = tx.objectStore(storeName);
    const request = store.delete(key);

    request.onerror = () => {
      reject(new Error(`Failed to delete: ${request.error}`));
    };

    request.onsuccess = () => {
      resolve();
    };
  });
}

/**
 * Clear all records from a store
 * @param {IDBDatabase} db - Database instance
 * @param {string} storeName - Object store name
 * @returns {Promise<void>}
 */
export function clear(db, storeName) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    const store = tx.objectStore(storeName);
    const request = store.clear();

    request.onerror = () => {
      reject(new Error(`Failed to clear: ${request.error}`));
    };

    request.onsuccess = () => {
      resolve();
    };
  });
}

console.log('[IndexedDBHelper] Helper loaded and ready');

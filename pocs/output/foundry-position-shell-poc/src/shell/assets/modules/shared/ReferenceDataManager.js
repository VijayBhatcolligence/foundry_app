/**
 * ReferenceDataManager
 *
 * Reusable component for managing reference data across modules.
 * Fetches data from backend, caches in IndexedDB, and handles staleness checks.
 *
 * Features:
 * - Automatic caching with expiration
 * - Offline support (uses cached data)
 * - Manual refresh capability
 * - Module-specific data isolation
 * - Efficient fetch strategy (avoids duplicate requests)
 */

const DEFAULT_TTL = 10 * 60 * 1000; // 10 minutes in milliseconds (auto-refresh friendly)
const AUTO_REFRESH_INTERVAL = 10 * 60 * 1000; // Auto-refresh every 10 minutes
const API_BASE_URL = 'http://localhost:3000/api';

class ReferenceDataManager {
  /**
   * Create a new ReferenceDataManager
   * @param {string} moduleId - Unique module identifier
   * @param {object} options - Configuration options
   */
  constructor(moduleId, options = {}) {
    this.moduleId = moduleId;
    this.dbName = `${moduleId}_reference_data`;
    this.storeName = 'reference_data';
    this.db = null;
    this.apiBaseUrl = options.apiBaseUrl || API_BASE_URL;
    this.defaultTTL = options.defaultTTL || DEFAULT_TTL;
    this.ongoingFetches = new Map(); // Track in-flight requests to prevent duplicates

    // Auto-refresh configuration
    this.autoRefresh = options.autoRefresh !== false; // Enabled by default
    this.autoRefreshInterval = options.autoRefreshInterval || AUTO_REFRESH_INTERVAL;
    this.autoRefreshTimer = null;
    this.trackedKeys = new Set(); // Track which keys to auto-refresh

    console.log(`[ReferenceDataManager] Created for module: ${moduleId}`);
    console.log(`[ReferenceDataManager] Auto-refresh: ${this.autoRefresh ? 'enabled' : 'disabled'} (${this.autoRefreshInterval / 1000}s interval)`);
  }

  /**
   * Initialize the manager (setup IndexedDB)
   * Call this when module loads
   */
  async initialize() {
    if (this.db) {
      console.log('[ReferenceDataManager] Already initialized');
      return;
    }

    try {
      console.log('[ReferenceDataManager] Initializing IndexedDB...');

      this.db = await this._openDatabase();

      console.log('[ReferenceDataManager] ✅ Initialized successfully');
      console.log(`[ReferenceDataManager] Database: ${this.dbName}`);
      console.log(`[ReferenceDataManager] Store: ${this.storeName}`);

      // Start auto-refresh if enabled
      if (this.autoRefresh) {
        this._startAutoRefresh();
      }
    } catch (error) {
      console.error('[ReferenceDataManager] ❌ Initialization failed:', error);
      throw error;
    }
  }

  /**
   * Open IndexedDB database
   * @private
   */
  async _openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, 1);

      request.onerror = () => {
        reject(new Error(`Failed to open database: ${request.error}`));
      };

      request.onsuccess = () => {
        resolve(request.result);
      };

      request.onupgradeneeded = (event) => {
        const db = event.target.result;

        if (!db.objectStoreNames.contains(this.storeName)) {
          const store = db.createObjectStore(this.storeName, { keyPath: 'key' });
          store.createIndex('updated_at', 'updated_at', { unique: false });
          store.createIndex('expires_at', 'expires_at', { unique: false });
          console.log('[ReferenceDataManager] Object store created');
        }
      };
    });
  }

  /**
   * Get reference data (from cache or fetch from API)
   * @param {string} dataType - Type of data ('products', 'customers', etc.)
   * @param {object} options - Options { forceRefresh: boolean }
   * @returns {Promise<Array>} Data array
   */
  async get(dataType, options = {}) {
    if (!this.db) {
      throw new Error('Manager not initialized. Call initialize() first.');
    }

    // Track this key for auto-refresh
    if (!this.trackedKeys.has(dataType)) {
      this.trackedKeys.add(dataType);
      console.log(`[ReferenceDataManager] Now tracking '${dataType}' for auto-refresh (${this.trackedKeys.size} keys tracked)`);
    }

    try {
      // Check if we should force refresh
      if (options.forceRefresh) {
        console.log(`[ReferenceDataManager] Force refresh requested for: ${dataType}`);
        return await this.refresh(dataType);
      }

      // Try to get from cache
      const cached = await this._getFromCache(dataType);

      if (cached) {
        // Check if stale
        if (this._isStale(cached)) {
          console.log(`[ReferenceDataManager] Cache is stale for: ${dataType}`);
          // Attempt to refresh, but return cached data if offline
          try {
            return await this.refresh(dataType);
          } catch (error) {
            console.warn(`[ReferenceDataManager] Refresh failed, using stale cache:`, error);
            return cached.value;
          }
        } else {
          console.log(`[ReferenceDataManager] ✅ Using fresh cache for: ${dataType}`);
          return cached.value;
        }
      }

      // No cache, fetch from API
      console.log(`[ReferenceDataManager] No cache found, fetching: ${dataType}`);
      return await this.fetch(dataType);
    } catch (error) {
      console.error(`[ReferenceDataManager] Failed to get ${dataType}:`, error);
      throw error;
    }
  }

  /**
   * Fetch reference data from backend API
   * @param {string} dataType - Type of data to fetch
   * @returns {Promise<Array>} Data array
   */
  async fetch(dataType) {
    if (!this.db) {
      throw new Error('Manager not initialized. Call initialize() first.');
    }

    // Check if there's already an ongoing fetch for this dataType
    if (this.ongoingFetches.has(dataType)) {
      console.log(`[ReferenceDataManager] Fetch already in progress for ${dataType}, waiting...`);
      return await this.ongoingFetches.get(dataType);
    }

    // Create new fetch promise
    const fetchPromise = this._doFetch(dataType);
    this.ongoingFetches.set(dataType, fetchPromise);

    try {
      const result = await fetchPromise;
      return result;
    } finally {
      this.ongoingFetches.delete(dataType);
    }
  }

  /**
   * Internal fetch implementation
   * @private
   */
  async _doFetch(dataType) {
    try {
      console.log(`[ReferenceDataManager] Fetching from API: ${dataType}`);

      const endpoint = this._getEndpoint(dataType);
      const response = await fetch(endpoint);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();

      // Extract array from response (handle different response formats)
      const dataArray = Array.isArray(data) ? data :
                        data.data ? data.data :
                        data.results ? data.results :
                        [];

      console.log(`[ReferenceDataManager] ✅ Fetched ${dataArray.length} items for: ${dataType}`);

      // Store in cache
      await this._saveToCache(dataType, dataArray);

      return dataArray;
    } catch (error) {
      console.error(`[ReferenceDataManager] ❌ Fetch failed for ${dataType}:`, error);
      throw error;
    }
  }

  /**
   * Force refresh data from API (ignores cache)
   * @param {string} dataType - Type of data to refresh
   * @returns {Promise<Array>} Fresh data array
   */
  async refresh(dataType) {
    console.log(`[ReferenceDataManager] Refreshing: ${dataType}`);
    return await this.fetch(dataType);
  }

  /**
   * Check if cached data is stale
   * @param {string} dataType - Type of data to check
   * @returns {boolean} True if stale or not found
   */
  async isStale(dataType) {
    if (!this.db) {
      return true;
    }

    try {
      const cached = await this._getFromCache(dataType);
      if (!cached) {
        return true;
      }
      return this._isStale(cached);
    } catch (error) {
      console.error(`[ReferenceDataManager] Error checking staleness:`, error);
      return true;
    }
  }

  /**
   * Clear cached data
   * @param {string} dataType - Type of data to clear (or null to clear all)
   */
  async clear(dataType = null) {
    if (!this.db) {
      throw new Error('Manager not initialized');
    }

    try {
      if (dataType) {
        console.log(`[ReferenceDataManager] Clearing cache for: ${dataType}`);
        await this._deleteFromCache(dataType);
      } else {
        console.log(`[ReferenceDataManager] Clearing all cache`);
        await this._clearAllCache();
      }
      console.log('[ReferenceDataManager] ✅ Cache cleared');
    } catch (error) {
      console.error('[ReferenceDataManager] ❌ Failed to clear cache:', error);
      throw error;
    }
  }

  /**
   * Get all cached data types with their metadata
   * @returns {Promise<Array>} Array of cache entries
   */
  async getAllCached() {
    if (!this.db) {
      throw new Error('Manager not initialized');
    }

    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(this.storeName, 'readonly');
      const store = tx.objectStore(this.storeName);
      const request = store.getAll();

      request.onerror = () => reject(new Error(`Failed to get all cached: ${request.error}`));
      request.onsuccess = () => resolve(request.result || []);
    });
  }

  /**
   * Get endpoint URL for data type
   * @private
   */
  _getEndpoint(dataType) {
    // Map data types to API endpoints
    const endpoints = {
      'products': '/products',
      'customers': '/customers',
      'vendors': '/vendors',
      'locations': '/locations',
      'defects': '/defects',
      'categories': '/categories'
    };

    const path = endpoints[dataType];
    if (!path) {
      throw new Error(`Unknown data type: ${dataType}`);
    }

    return `${this.apiBaseUrl}${path}`;
  }

  /**
   * Get data from IndexedDB cache
   * @private
   */
  async _getFromCache(dataType) {
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(this.storeName, 'readonly');
      const store = tx.objectStore(this.storeName);
      const request = store.get(dataType);

      request.onerror = () => reject(new Error(`Failed to get from cache: ${request.error}`));
      request.onsuccess = () => resolve(request.result);
    });
  }

  /**
   * Save data to IndexedDB cache
   * @private
   */
  async _saveToCache(dataType, dataArray) {
    const now = Date.now();
    const expiresAt = now + this.defaultTTL;

    const cacheEntry = {
      key: dataType,
      value: dataArray,
      version: '1.0',
      updated_at: now,
      expires_at: expiresAt,
      count: dataArray.length
    };

    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(this.storeName, 'readwrite');
      const store = tx.objectStore(this.storeName);
      const request = store.put(cacheEntry);

      request.onerror = () => reject(new Error(`Failed to save to cache: ${request.error}`));
      request.onsuccess = () => {
        console.log(`[ReferenceDataManager] Saved ${dataArray.length} items to cache: ${dataType}`);
        console.log(`[ReferenceDataManager] Expires at: ${new Date(expiresAt).toISOString()}`);
        resolve();
      };
    });
  }

  /**
   * Delete data from cache
   * @private
   */
  async _deleteFromCache(dataType) {
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(this.storeName, 'readwrite');
      const store = tx.objectStore(this.storeName);
      const request = store.delete(dataType);

      request.onerror = () => reject(new Error(`Failed to delete from cache: ${request.error}`));
      request.onsuccess = () => resolve();
    });
  }

  /**
   * Clear all cached data
   * @private
   */
  async _clearAllCache() {
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(this.storeName, 'readwrite');
      const store = tx.objectStore(this.storeName);
      const request = store.clear();

      request.onerror = () => reject(new Error(`Failed to clear cache: ${request.error}`));
      request.onsuccess = () => resolve();
    });
  }

  /**
   * Check if cache entry is stale
   * @private
   */
  _isStale(cacheEntry) {
    if (!cacheEntry || !cacheEntry.expires_at) {
      return true;
    }
    const now = Date.now();
    return now >= cacheEntry.expires_at;
  }

  /**
   * Manually refresh a specific key (force fetch from backend)
   * @param {string} key - The key to refresh
   * @returns {Promise<any>} Fresh data from backend
   */
  async refresh(key) {
    console.log(`[ReferenceDataManager] Manual refresh requested for: ${key}`);

    // Clear the cached entry
    try {
      const tx = this.db.transaction([this.storeName], 'readwrite');
      const store = tx.objectStore(this.storeName);
      await store.delete(key);
      console.log(`[ReferenceDataManager] Cleared cached data for: ${key}`);
    } catch (error) {
      console.warn(`[ReferenceDataManager] Could not clear cache for ${key}:`, error);
    }

    // Fetch fresh data
    return await this.get(key);
  }

  /**
   * Start auto-refresh timer
   * @private
   */
  _startAutoRefresh() {
    if (this.autoRefreshTimer) {
      console.log('[ReferenceDataManager] Auto-refresh already running');
      return;
    }

    console.log(`[ReferenceDataManager] 🔄 Starting auto-refresh (every ${this.autoRefreshInterval / 1000}s)`);

    this.autoRefreshTimer = setInterval(async () => {
      if (this.trackedKeys.size === 0) {
        console.log('[ReferenceDataManager] Auto-refresh: No keys tracked, skipping');
        return;
      }

      console.log(`[ReferenceDataManager] 🔄 Auto-refresh triggered for ${this.trackedKeys.size} keys`);

      for (const key of this.trackedKeys) {
        try {
          await this.refresh(key);
          console.log(`[ReferenceDataManager] ✅ Auto-refreshed: ${key}`);
        } catch (error) {
          console.error(`[ReferenceDataManager] ❌ Auto-refresh failed for ${key}:`, error);
        }
      }
    }, this.autoRefreshInterval);
  }

  /**
   * Stop auto-refresh timer
   */
  stopAutoRefresh() {
    if (this.autoRefreshTimer) {
      clearInterval(this.autoRefreshTimer);
      this.autoRefreshTimer = null;
      console.log('[ReferenceDataManager] Auto-refresh stopped');
    }
  }

  /**
   * Close the database connection
   */
  async close() {
    // Stop auto-refresh first
    this.stopAutoRefresh();

    if (this.db) {
      this.db.close();
      this.db = null;
      console.log('[ReferenceDataManager] Database connection closed');
    }
  }
}

// Export for use in modules
if (typeof window !== 'undefined') {
  window.ReferenceDataManager = ReferenceDataManager;
}

// Also support ES6 module export
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ReferenceDataManager;
}

console.log('[ReferenceDataManager] Component loaded and ready');

import { useState, useEffect } from 'react';
import { initDatabase, getDatabase, DB_NAME } from '../utils/dbHelper';
import { getAll as getAllFromDB, add as addToDB, put as putToDB, clear as clearDB } from '../utils/indexedDBHelper';

/**
 * Feature 2: Stock Count with Product Cache
 *
 * 🎯 WHAT THIS PROVES:
 * ✅ IndexedDB pulls data from backend and caches locally
 * ✅ Periodic auto-refresh (every 10 minutes)
 * ✅ Offline data entry using cached products
 * ✅ Local storage of count updates
 * ✅ Auto-sync immediately when online
 * ✅ Manual batch sync also available
 *
 * SCENARIO:
 * 1. On load: Pull all products from backend → Cache in IndexedDB
 * 2. Auto-sync pending counts on startup (if any)
 * 3. User selects product from dropdown (cached list)
 * 4. User enters new count → Saved to IndexedDB
 * 5. Auto-syncs immediately if online (within 0.5s)
 * 6. If offline, count stays pending until online
 * 7. Manual "Send to Backend" button also available
 * 8. Auto-refresh products every 10 minutes (proves periodic pull)
 *
 * CONCEPT:
 * - IndexedDB = Expendable cache for reference data (products)
 * - IndexedDB = Local storage for count updates (not critical)
 * - Backend sync = Manual trigger (batch operation)
 */

const STORE_NAME = 'stock_counts';
const MODULE_ID = 'test-inventory-checker';

function Feature2_StockCount({ onCountSaved }) {
  const [products, setProducts] = useState([]);
  const [selectedProductId, setSelectedProductId] = useState('');
  const [newQuantity, setNewQuantity] = useState('');
  const [stockCounts, setStockCounts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [loadingProducts, setLoadingProducts] = useState(true);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [refDataManager, setRefDataManager] = useState(null);

  useEffect(() => {
    // Initialize everything in the correct order
    const initialize = async () => {
      try {
        // 1. Initialize database FIRST
        await initializeDatabase();

        // 2. Load products and counts in parallel
        await Promise.all([
          initializeReferenceData(),
          loadStockCounts()
        ]);

        // 3. Auto-sync on startup if there are pending counts
        setTimeout(() => {
          console.log('[StockCount] Checking for pending counts on startup...');
          autoSyncPendingCounts();
        }, 3000);
      } catch (err) {
        console.error('[StockCount] Initialization error:', err);
        setError('Failed to initialize: ' + err.message);
      }
    };

    initialize();
  }, []);

  const initializeDatabase = async () => {
    try {
      await initDatabase();
      console.log('[StockCount] Database initialized');
    } catch (err) {
      console.error('[StockCount] Database initialization error:', err);
      setError('Failed to initialize database: ' + err.message);
    }
  };

  const initializeReferenceData = async () => {
    try {
      console.log('[StockCount] Initializing ReferenceDataManager...');
      setLoadingProducts(true);

      // Create ReferenceDataManager instance
      const manager = new window.ReferenceDataManager(MODULE_ID, {
        defaultTTL: 10 * 60 * 1000, // 10 minutes
        autoRefresh: true, // Auto-refresh every 10 minutes
        autoRefreshInterval: 10 * 60 * 1000
      });

      await manager.initialize();
      setRefDataManager(manager);

      // Pull products from backend (will cache in IndexedDB)
      console.log('[StockCount] Pulling products from backend...');
      const productsData = await manager.get('products');

      console.log(`[StockCount] ✅ Loaded ${productsData.length} products from backend/cache`);
      setProducts(productsData);
      setLoadingProducts(false);
    } catch (err) {
      console.error('[StockCount] Error loading products:', err);
      setError('Failed to load products: ' + err.message);
      setLoadingProducts(false);
    }
  };

  const handleRefreshProducts = async () => {
    if (!refDataManager) return;

    try {
      console.log('[StockCount] Manually refreshing products from backend...');
      setLoadingProducts(true);

      // Force refresh (bypass cache)
      const productsData = await refDataManager.get('products', { forceRefresh: true });

      console.log(`[StockCount] ✅ Refreshed ${productsData.length} products`);
      setProducts(productsData);
      setSuccess('Products refreshed from backend');
      setLoadingProducts(false);
    } catch (err) {
      console.error('[StockCount] Error refreshing products:', err);
      setError('Failed to refresh products: ' + err.message);
      setLoadingProducts(false);
    }
  };

  const loadStockCounts = async () => {
    try {
      console.log('[StockCount] Loading counts from IndexedDB...');
      const db = await getDatabase();

      const allCounts = await getAllFromDB(db, STORE_NAME);

      // Sort by timestamp descending
      allCounts.sort((a, b) => b.timestamp - a.timestamp);

      console.log('[StockCount] ✅ Loaded counts from IndexedDB:', allCounts.length);
      if (allCounts.length > 0) {
        console.log('[StockCount] First count:', allCounts[0]);
      }

      setStockCounts(allCounts);
    } catch (err) {
      console.error('[StockCount] ❌ Error loading counts:', err);
      setError('Failed to load stock counts from IndexedDB: ' + err.message);
    }
  };

  const handleSaveCount = async () => {
    setError(null);
    setSuccess(null);

    // Validation
    if (!selectedProductId) {
      setError('Please select a product');
      return;
    }
    if (!newQuantity || isNaN(newQuantity) || parseInt(newQuantity) < 0) {
      setError('Quantity must be a non-negative number');
      return;
    }

    setLoading(true);

    try {
      const selectedProduct = products.find(p => p.id === parseInt(selectedProductId));
      if (!selectedProduct) {
        throw new Error('Product not found');
      }

      const count = {
        product_id: selectedProduct.id,
        product_name: selectedProduct.name,
        sku: selectedProduct.sku,
        old_quantity: selectedProduct.quantity,
        new_quantity: parseInt(newQuantity),
        timestamp: Date.now(),
        synced: false, // Not yet sent to backend
      };

      console.log('[StockCount] Saving count to IndexedDB:', count);

      const db = await getDatabase();
      const addedId = await addToDB(db, STORE_NAME, count);

      console.log('[StockCount] ✅ Count saved to IndexedDB with ID:', addedId);

      setSuccess(`Count saved for ${selectedProduct.name}! Auto-syncing...`);

      // Clear form
      setSelectedProductId('');
      setNewQuantity('');

      // Reload list
      await loadStockCounts();

      if (onCountSaved) {
        onCountSaved();
      }

      // Auto-sync immediately if online
      console.log('[StockCount] Triggering auto-sync after save...');
      setTimeout(() => {
        autoSyncPendingCounts();
      }, 500);
    } catch (err) {
      console.error('[StockCount] Error saving count:', err);
      setError('Failed to save count: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const autoSyncPendingCounts = async () => {
    try {
      // Query IndexedDB directly for pending counts (don't rely on state)
      const db = await getDatabase();
      const allCounts = await getAllFromDB(db, STORE_NAME);

      // Filter for pending (not synced)
      const pendingCounts = allCounts.filter(c => !c.synced);

      if (pendingCounts.length === 0) {
        console.log('[StockCount] No pending counts to auto-sync');
        return;
      }

      console.log(`[StockCount] Auto-syncing ${pendingCounts.length} pending count(s)...`);

      let successCount = 0;

      for (const count of pendingCounts) {
        try {
          console.log(`[StockCount] Syncing count ID ${count.id} for product ${count.product_id}...`);

          // Send to backend
          const response = await fetch('http://localhost:3000/api/stock-counts', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              product_id: count.product_id,
              new_quantity: count.new_quantity,
              timestamp: count.timestamp
            })
          });

          if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`HTTP ${response.status}: ${errorText}`);
          }

          const result = await response.json();
          console.log(`[StockCount] Backend response:`, result);

          // Mark as synced in IndexedDB
          const updatedCount = { ...count, synced: true, synced_at: Date.now() };
          await putToDB(db, STORE_NAME, updatedCount);

          successCount++;
          console.log(`[StockCount] ✅ Auto-synced count for product ${count.product_id}`);
        } catch (err) {
          console.error(`[StockCount] ❌ Auto-sync failed for product ${count.product_id}:`, err);
          // Continue with next count
        }
      }

      console.log(`[StockCount] Auto-sync complete: ${successCount}/${pendingCounts.length} successful`);

      if (successCount > 0) {
        setSuccess(`✅ ${successCount} count(s) synced to backend!`);
      } else if (successCount === 0 && pendingCounts.length > 0) {
        setError(`Failed to sync ${pendingCounts.length} count(s). Will retry later.`);
      }

      // Reload list to show updated sync status
      await loadStockCounts();

      // Refresh products to get updated quantities from backend
      if (refDataManager && successCount > 0) {
        const refreshedProducts = await refDataManager.get('products', { forceRefresh: true });
        setProducts(refreshedProducts);
      }
    } catch (err) {
      console.error('[StockCount] Auto-sync error:', err);
      // Silent fail for auto-sync (don't show error to user)
    }
  };

  const handleSyncToBackend = async () => {
    setError(null);
    setSuccess(null);

    // Get pending counts (not synced)
    const pendingCounts = stockCounts.filter(c => !c.synced);

    if (pendingCounts.length === 0) {
      setError('No pending counts to sync');
      return;
    }

    if (!confirm(`Send ${pendingCounts.length} count(s) to backend?`)) {
      return;
    }

    setSyncing(true);

    try {
      console.log(`[StockCount] Syncing ${pendingCounts.length} counts to backend...`);

      let successCount = 0;
      const db = await getDatabase();

      for (const count of pendingCounts) {
        try {
          // Send to backend
          const response = await fetch('http://localhost:3000/api/stock-counts', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              product_id: count.product_id,
              new_quantity: count.new_quantity,
              timestamp: count.timestamp
            })
          });

          if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
          }

          // Mark as synced in IndexedDB
          const updatedCount = { ...count, synced: true, synced_at: Date.now() };
          await putToDB(db, STORE_NAME, updatedCount);

          successCount++;
          console.log(`[StockCount] ✅ Synced count for product ${count.product_id}`);
        } catch (err) {
          console.error(`[StockCount] ❌ Failed to sync count for product ${count.product_id}:`, err);
        }
      }

      console.log(`[StockCount] Sync complete: ${successCount}/${pendingCounts.length} successful`);

      setSuccess(`✅ Synced ${successCount}/${pendingCounts.length} count(s) to backend`);

      // Reload list
      await loadStockCounts();

      // Refresh products to get updated quantities from backend
      if (refDataManager) {
        await refDataManager.get('products', { forceRefresh: true });
        const refreshedProducts = await refDataManager.get('products');
        setProducts(refreshedProducts);
      }
    } catch (err) {
      console.error('[StockCount] Error syncing:', err);
      setError('Failed to sync counts: ' + err.message);
    } finally {
      setSyncing(false);
    }
  };

  const handleClear = async () => {
    if (!confirm('Are you sure you want to clear all stock counts? This will delete all data from IndexedDB.')) {
      return;
    }

    try {
      console.log('[StockCount] Clearing all counts from IndexedDB...');

      const db = await getDatabase();
      await clearDB(db, STORE_NAME);

      console.log('[StockCount] ✅ All counts cleared');

      setStockCounts([]);
      setSuccess('All stock counts cleared from IndexedDB');
    } catch (err) {
      console.error('[StockCount] Error clearing:', err);
      setError('Failed to clear stock counts: ' + err.message);
    }
  };

  const formatDate = (timestamp) => {
    return new Date(timestamp).toLocaleString();
  };

  const pendingCount = stockCounts.filter(c => !c.synced).length;

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.cardHeader}>
          <h2 style={styles.cardTitle}>📦 Stock Count Entry</h2>
          <span style={styles.badge}>IndexedDB - Pull & Cache</span>
        </div>

        <div style={styles.cardBody}>
          <p style={styles.description}>
            This feature demonstrates <strong>IndexedDB periodic data pull</strong> from backend.
            Products are cached locally (auto-refresh every 10 min) and stock counts are saved locally until synced.
          </p>

          {/* Product Cache Status */}
          <div style={styles.cacheStatus}>
            <div style={styles.cacheInfo}>
              <span>📋 Products Cached: <strong>{products.length}</strong></span>
              <span>🔄 Auto-refresh: <strong>Every 10 minutes</strong></span>
            </div>
            <button
              onClick={handleRefreshProducts}
              style={styles.refreshButton}
              disabled={loadingProducts}
            >
              {loadingProducts ? '⏳ Loading...' : '🔄 Refresh Now'}
            </button>
          </div>

          {/* Form */}
          <div style={styles.form}>
            <div style={styles.formGroup}>
              <label style={styles.label}>Select Product *</label>
              {loadingProducts ? (
                <div style={styles.loadingBox}>⏳ Loading products from backend...</div>
              ) : products.length === 0 ? (
                <div style={styles.errorBox}>No products available. Check backend connection.</div>
              ) : (
                <select
                  value={selectedProductId}
                  onChange={(e) => setSelectedProductId(e.target.value)}
                  style={styles.select}
                  disabled={loading}
                >
                  <option value="">-- Choose a product --</option>
                  {products.map(product => (
                    <option key={product.id} value={product.id}>
                      {product.name} (SKU: {product.sku}) - Current: {product.quantity} units
                    </option>
                  ))}
                </select>
              )}
            </div>

            <div style={styles.formGroup}>
              <label style={styles.label}>New Quantity Count *</label>
              <input
                type="number"
                placeholder="Enter counted quantity"
                value={newQuantity}
                onChange={(e) => setNewQuantity(e.target.value)}
                style={styles.input}
                disabled={loading || !selectedProductId}
                min="0"
              />
              {selectedProductId && products.find(p => p.id === parseInt(selectedProductId)) && (
                <div style={styles.hint}>
                  Current quantity in system: <strong>{products.find(p => p.id === parseInt(selectedProductId)).quantity}</strong> units
                </div>
              )}
            </div>

            <button
              onClick={handleSaveCount}
              style={styles.saveButton}
              disabled={loading || !selectedProductId}
            >
              {loading ? '⏳ Saving...' : '💾 Save Count (Auto-Sync if Online)'}
            </button>
          </div>

          {/* Messages */}
          {error && (
            <div style={styles.errorBox}>
              <strong>❌ Error:</strong> {error}
            </div>
          )}

          {success && (
            <div style={styles.successBox}>
              <strong>✅ Success:</strong> {success}
            </div>
          )}

          {/* Stock Counts List */}
          <div style={styles.listSection}>
            <div style={styles.listHeader}>
              <div>
                <strong>📋 Saved Stock Counts ({stockCounts.length})</strong>
                {pendingCount > 0 && (
                  <span style={styles.pendingBadge}>{pendingCount} pending</span>
                )}
              </div>
              <div style={styles.headerActions}>
                {pendingCount > 0 && (
                  <button
                    onClick={handleSyncToBackend}
                    style={styles.syncButton}
                    disabled={syncing}
                  >
                    {syncing ? '⏳ Syncing...' : `📤 Send to Backend (${pendingCount})`}
                  </button>
                )}
                {stockCounts.length > 0 && (
                  <button onClick={handleClear} style={styles.clearButton}>
                    🗑️ Clear All
                  </button>
                )}
              </div>
            </div>

            {stockCounts.length === 0 ? (
              <div style={styles.emptyState}>
                <p>No stock counts saved yet.</p>
                <p style={styles.hint}>Select a product and enter count above.</p>
              </div>
            ) : (
              <div style={styles.countList}>
                {stockCounts.map((count) => (
                  <div key={count.id} style={styles.countCard}>
                    <div style={styles.countHeader}>
                      <div>
                        <div style={styles.countProduct}>{count.product_name}</div>
                        <div style={styles.countSku}>SKU: {count.sku}</div>
                      </div>
                      {count.synced ? (
                        <span style={styles.syncedBadge}>✅ Synced</span>
                      ) : (
                        <span style={styles.pendingSyncBadge}>⏳ Pending</span>
                      )}
                    </div>

                    <div style={styles.countDetails}>
                      <div>
                        <span style={styles.countLabel}>Old:</span>
                        <span style={styles.countValue}>{count.old_quantity}</span>
                      </div>
                      <div style={styles.countArrow}>→</div>
                      <div>
                        <span style={styles.countLabel}>New:</span>
                        <span style={styles.countValueNew}>{count.new_quantity}</span>
                      </div>
                      <div>
                        <span style={styles.countLabel}>Diff:</span>
                        <span style={{
                          ...styles.countDiff,
                          color: count.new_quantity - count.old_quantity >= 0 ? '#4CAF50' : '#F44336'
                        }}>
                          {count.new_quantity - count.old_quantity > 0 ? '+' : ''}{count.new_quantity - count.old_quantity}
                        </span>
                      </div>
                    </div>

                    <div style={styles.countTime}>
                      🕐 {formatDate(count.timestamp)}
                      {count.synced_at && (
                        <span style={styles.syncTime}> (Synced: {formatDate(count.synced_at)})</span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Info Box */}
          <div style={styles.infoBox}>
            <strong>ℹ️ What this proves:</strong>
            <ul style={styles.infoList}>
              <li>🔄 <strong>Periodic Pull:</strong> Products auto-refresh from backend every 10 minutes</li>
              <li>📦 <strong>Cache in IndexedDB:</strong> Products stored locally for offline access</li>
              <li>📝 <strong>Local Counts:</strong> Stock counts saved to IndexedDB first</li>
              <li>⚡ <strong>Auto-Sync:</strong> Syncs to backend immediately when online (0.5s delay)</li>
              <li>📤 <strong>Manual Sync:</strong> "Send to Backend" button available for retry</li>
              <li>🔌 <strong>Offline Capable:</strong> Counts stay pending until connection restored</li>
              <li>🔁 <strong>Auto-Sync on Startup:</strong> Syncs pending counts when app opens</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
  },
  card: {
    background: 'white',
    borderRadius: '8px',
    boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
    overflow: 'hidden',
  },
  cardHeader: {
    padding: '20px',
    background: '#f8f9ff',
    borderBottom: '1px solid #e0e0e0',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardTitle: {
    fontSize: '20px',
    fontWeight: 'bold',
    color: '#333',
    margin: 0,
  },
  badge: {
    background: '#2196F3',
    color: 'white',
    padding: '4px 12px',
    borderRadius: '12px',
    fontSize: '12px',
    fontWeight: '500',
  },
  cardBody: {
    padding: '20px',
  },
  description: {
    color: '#666',
    lineHeight: '1.6',
    marginBottom: '20px',
  },
  cacheStatus: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    background: '#e3f2fd',
    padding: '12px 16px',
    borderRadius: '8px',
    marginBottom: '20px',
    border: '1px solid #2196F3',
  },
  cacheInfo: {
    display: 'flex',
    gap: '20px',
    fontSize: '14px',
    color: '#1976D2',
  },
  refreshButton: {
    padding: '6px 14px',
    background: '#2196F3',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    fontSize: '13px',
    cursor: 'pointer',
    fontWeight: '500',
  },
  form: {
    marginBottom: '20px',
  },
  formGroup: {
    marginBottom: '15px',
  },
  label: {
    display: 'block',
    marginBottom: '6px',
    fontSize: '14px',
    fontWeight: '500',
    color: '#333',
  },
  select: {
    width: '100%',
    padding: '10px 12px',
    fontSize: '15px',
    border: '2px solid #e0e0e0',
    borderRadius: '6px',
    outline: 'none',
    background: 'white',
    cursor: 'pointer',
  },
  input: {
    width: '100%',
    padding: '10px 12px',
    fontSize: '15px',
    border: '2px solid #e0e0e0',
    borderRadius: '6px',
    outline: 'none',
    transition: 'border-color 0.2s',
  },
  hint: {
    fontSize: '12px',
    color: '#666',
    marginTop: '6px',
  },
  loadingBox: {
    padding: '12px',
    background: '#fff3e0',
    border: '1px solid #FF9800',
    borderRadius: '6px',
    color: '#e65100',
    textAlign: 'center',
  },
  saveButton: {
    width: '100%',
    padding: '12px',
    background: '#667eea',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    fontSize: '15px',
    fontWeight: '500',
    cursor: 'pointer',
    transition: 'background 0.2s',
  },
  errorBox: {
    background: '#ffebee',
    border: '1px solid #ef5350',
    borderRadius: '8px',
    padding: '12px 16px',
    color: '#c62828',
    marginBottom: '15px',
  },
  successBox: {
    background: '#e8f5e9',
    border: '1px solid #4caf50',
    borderRadius: '8px',
    padding: '12px 16px',
    color: '#2e7d32',
    marginBottom: '15px',
  },
  listSection: {
    marginTop: '30px',
  },
  listHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '15px',
    paddingBottom: '10px',
    borderBottom: '2px solid #e0e0e0',
  },
  headerActions: {
    display: 'flex',
    gap: '10px',
  },
  pendingBadge: {
    marginLeft: '10px',
    background: '#FFC107',
    color: 'white',
    padding: '3px 10px',
    borderRadius: '10px',
    fontSize: '12px',
    fontWeight: '500',
  },
  syncButton: {
    padding: '6px 12px',
    background: '#4CAF50',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    fontSize: '13px',
    cursor: 'pointer',
    fontWeight: '500',
  },
  clearButton: {
    padding: '6px 12px',
    background: '#ef5350',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    fontSize: '13px',
    cursor: 'pointer',
  },
  emptyState: {
    textAlign: 'center',
    padding: '40px 20px',
    color: '#999',
  },
  countList: {
    display: 'grid',
    gap: '10px',
  },
  countCard: {
    background: '#fafafa',
    border: '1px solid #e0e0e0',
    borderRadius: '8px',
    padding: '15px',
  },
  countHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: '10px',
  },
  countProduct: {
    fontWeight: 'bold',
    color: '#333',
    fontSize: '15px',
  },
  countSku: {
    fontSize: '12px',
    color: '#999',
    marginTop: '2px',
  },
  syncedBadge: {
    background: '#4CAF50',
    color: 'white',
    padding: '3px 8px',
    borderRadius: '10px',
    fontSize: '11px',
    fontWeight: '500',
  },
  pendingSyncBadge: {
    background: '#FFC107',
    color: 'white',
    padding: '3px 8px',
    borderRadius: '10px',
    fontSize: '11px',
    fontWeight: '500',
  },
  countDetails: {
    display: 'flex',
    alignItems: 'center',
    gap: '15px',
    marginBottom: '10px',
    padding: '10px',
    background: 'white',
    borderRadius: '6px',
  },
  countLabel: {
    fontSize: '12px',
    color: '#999',
    marginRight: '6px',
  },
  countValue: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#666',
  },
  countValueNew: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#2196F3',
  },
  countArrow: {
    fontSize: '18px',
    color: '#999',
  },
  countDiff: {
    fontSize: '16px',
    fontWeight: 'bold',
  },
  countTime: {
    fontSize: '12px',
    color: '#999',
  },
  syncTime: {
    color: '#4CAF50',
    fontStyle: 'italic',
  },
  infoBox: {
    background: '#e3f2fd',
    border: '1px solid #2196F3',
    borderRadius: '8px',
    padding: '15px',
    fontSize: '14px',
    color: '#1565C0',
    marginTop: '20px',
  },
  infoList: {
    marginTop: '10px',
    marginLeft: '20px',
    lineHeight: '1.8',
  },
};

export default Feature2_StockCount;

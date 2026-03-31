import { useState } from 'react';

/**
 * Feature 1: Product Search (Online Only)
 *
 * 🎯 WHAT THIS PROVES:
 * ✅ Direct backend API calls from React
 * ✅ No local storage (no caching)
 * ✅ Fresh data on every search
 * ✅ Requires active internet connection
 *
 * SCENARIO:
 * 1. User searches for product (e.g., "hammer")
 * 2. React calls backend: GET /api/products?q=hammer
 * 3. Backend returns matching products
 * 4. No caching - same search = new API call
 * 5. Offline = Error (demonstrates online-only strategy)
 */

const BACKEND_URL = 'http://localhost:3000';

function Feature1_ProductSearch() {
  const [searchQuery, setSearchQuery] = useState('');
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [searched, setSearched] = useState(false);

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      setError('Please enter a search term');
      return;
    }

    setLoading(true);
    setError(null);
    setSearched(true);

    try {
      console.log('[ProductSearch] Searching for:', searchQuery);

      const response = await fetch(`${BACKEND_URL}/api/products?q=${encodeURIComponent(searchQuery)}`);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();

      if (data.success) {
        console.log('[ProductSearch] Found products:', data.data.length);
        setProducts(data.data);
      } else {
        throw new Error(data.error || 'Search failed');
      }
    } catch (err) {
      console.error('[ProductSearch] Search error:', err);
      setError(err.message);
      setProducts([]);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      handleSearch();
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.cardHeader}>
          <h2 style={styles.cardTitle}>🔍 Product Search</h2>
          <span style={styles.badge}>Online Only</span>
        </div>

        <div style={styles.cardBody}>
          <p style={styles.description}>
            This feature demonstrates <strong>online-only functionality</strong> with no local storage.
            Data is fetched directly from the backend API.
          </p>

          {/* Search Input */}
          <div style={styles.searchBox}>
            <input
              type="text"
              placeholder="Search products by name or SKU..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={handleKeyPress}
              style={styles.input}
              disabled={loading}
            />
            <button
              onClick={handleSearch}
              style={styles.searchButton}
              disabled={loading}
            >
              {loading ? '⏳ Searching...' : '🔍 Search'}
            </button>
          </div>

          {/* Error Message */}
          {error && (
            <div style={styles.errorBox}>
              <strong>❌ Error:</strong> {error}
            </div>
          )}

          {/* Results */}
          {searched && !loading && (
            <div style={styles.results}>
              <div style={styles.resultsHeader}>
                <strong>{products.length} products found</strong>
                {products.length > 0 && (
                  <span style={styles.hint}>
                    (No local storage - data not cached)
                  </span>
                )}
              </div>

              {products.length === 0 ? (
                <div style={styles.emptyState}>
                  <p>No products match your search criteria.</p>
                  <p style={styles.hint}>Try a different search term.</p>
                </div>
              ) : (
                <div style={styles.productList}>
                  {products.map((product, index) => (
                    <div key={product.id || index} style={styles.productCard}>
                      <div style={styles.productHeader}>
                        <span style={styles.productSku}>{product.sku}</span>
                        <span style={styles.productBarcode}>{product.barcode}</span>
                      </div>
                      <div style={styles.productName}>{product.name}</div>
                      {product.description && (
                        <div style={styles.productDesc}>{product.description}</div>
                      )}
                      <div style={styles.productLocation}>
                        📍 {product.default_location}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Info Box */}
          <div style={styles.infoBox}>
            <strong>ℹ️ About this feature:</strong>
            <ul style={styles.infoList}>
              <li>Fetches data from: <code>GET /api/products?q=search</code></li>
              <li>No local storage (IndexedDB or SQLite)</li>
              <li>Requires active internet connection</li>
              <li>Data is not cached - fresh on every search</li>
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
  searchBox: {
    display: 'flex',
    gap: '10px',
    marginBottom: '20px',
  },
  input: {
    flex: 1,
    padding: '12px 16px',
    fontSize: '15px',
    border: '2px solid #e0e0e0',
    borderRadius: '8px',
    outline: 'none',
    transition: 'border-color 0.2s',
  },
  searchButton: {
    padding: '12px 24px',
    background: '#667eea',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    fontSize: '15px',
    fontWeight: '500',
    cursor: 'pointer',
    transition: 'background 0.2s',
    whiteSpace: 'nowrap',
  },
  errorBox: {
    background: '#ffebee',
    border: '1px solid #ef5350',
    borderRadius: '8px',
    padding: '12px 16px',
    color: '#c62828',
    marginBottom: '20px',
  },
  results: {
    marginBottom: '20px',
  },
  resultsHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '15px',
    paddingBottom: '10px',
    borderBottom: '2px solid #e0e0e0',
  },
  hint: {
    fontSize: '13px',
    color: '#999',
  },
  emptyState: {
    textAlign: 'center',
    padding: '40px 20px',
    color: '#999',
  },
  productList: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
    gap: '15px',
  },
  productCard: {
    background: '#fafafa',
    border: '1px solid #e0e0e0',
    borderRadius: '8px',
    padding: '15px',
    transition: 'box-shadow 0.2s',
  },
  productHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    marginBottom: '8px',
  },
  productSku: {
    fontWeight: 'bold',
    color: '#667eea',
    fontSize: '14px',
  },
  productBarcode: {
    fontSize: '13px',
    color: '#999',
    fontFamily: 'monospace',
  },
  productName: {
    fontWeight: '600',
    color: '#333',
    marginBottom: '5px',
    fontSize: '15px',
  },
  productDesc: {
    fontSize: '13px',
    color: '#666',
    marginBottom: '8px',
  },
  productLocation: {
    fontSize: '13px',
    color: '#666',
    marginTop: '8px',
    paddingTop: '8px',
    borderTop: '1px solid #e0e0e0',
  },
  infoBox: {
    background: '#e3f2fd',
    border: '1px solid #2196F3',
    borderRadius: '8px',
    padding: '15px',
    fontSize: '14px',
    color: '#1565c0',
  },
  infoList: {
    marginTop: '10px',
    marginLeft: '20px',
    lineHeight: '1.8',
  },
};

export default Feature1_ProductSearch;

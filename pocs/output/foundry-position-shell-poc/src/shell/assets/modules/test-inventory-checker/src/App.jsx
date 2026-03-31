import { useState, useEffect } from 'react';
import Feature1_ProductSearch from './components/Feature1_ProductSearch';
import Feature2_StockCount from './components/Feature2_StockCount';
import Feature3_AuditTrail from './components/Feature3_AuditTrail';

const MODULE_ID = 'test-inventory-checker';

function App() {
  const [activeTab, setActiveTab] = useState('product-search');
  const [pendingCount, setPendingCount] = useState(0);
  const [bridgeReady, setBridgeReady] = useState(false);

  useEffect(() => {
    // Check if bridge is available
    if (window.ActionQueue && window.ActionQueue.isAvailable()) {
      console.log('[App] Bridge is ready');
      setBridgeReady(true);
      updatePendingCount();
    } else {
      console.warn('[App] Bridge not available yet, retrying...');
      const timer = setTimeout(() => {
        if (window.ActionQueue && window.ActionQueue.isAvailable()) {
          setBridgeReady(true);
          updatePendingCount();
        }
      }, 1000);
      return () => clearTimeout(timer);
    }
  }, []);

  const updatePendingCount = async () => {
    if (!window.ActionQueue) return;

    try {
      const count = await window.ActionQueue.getPendingCount(MODULE_ID);
      setPendingCount(count);
    } catch (error) {
      console.error('[App] Error getting pending count:', error);
    }
  };

  const tabs = [
    { id: 'product-search', label: 'Product Search', icon: '🔍' },
    { id: 'stock-count', label: 'Stock Count', icon: '📦' },
    { id: 'audit-trail', label: 'Audit Trail', icon: '📋' },
  ];

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <div style={styles.headerContent}>
          <h1 style={styles.title}>📊 Inventory Checker</h1>
          <p style={styles.subtitle}>Test Module - Hybrid Architecture Demo</p>
        </div>

        {/* Bridge Status */}
        <div style={styles.statusBar}>
          <span style={bridgeReady ? styles.statusReady : styles.statusNotReady}>
            {bridgeReady ? '✅ Bridge Ready' : '⏳ Bridge Loading...'}
          </span>
          {bridgeReady && pendingCount > 0 && (
            <span style={styles.pendingBadge}>
              🔄 {pendingCount} pending
            </span>
          )}
        </div>
      </div>

      {/* Tabs */}
      <div style={styles.tabs}>
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            style={{
              ...styles.tab,
              ...(activeTab === tab.id ? styles.tabActive : {})
            }}
          >
            <span style={styles.tabIcon}>{tab.icon}</span>
            <span>{tab.label}</span>
          </button>
        ))}
      </div>

      {/* Content */}
      <div style={styles.content}>
        {!bridgeReady ? (
          <div style={styles.loading}>
            <p>⏳ Waiting for bridge to initialize...</p>
            <p style={styles.loadingHint}>
              Make sure the Flutter shell has initialized the bridge properly
            </p>
          </div>
        ) : (
          <>
            {activeTab === 'product-search' && (
              <Feature1_ProductSearch />
            )}
            {activeTab === 'stock-count' && (
              <Feature2_StockCount onCountSaved={updatePendingCount} />
            )}
            {activeTab === 'audit-trail' && (
              <Feature3_AuditTrail
                moduleId={MODULE_ID}
                onAuditSaved={updatePendingCount}
              />
            )}
          </>
        )}
      </div>

      {/* Footer */}
      <div style={styles.footer}>
        <div style={styles.footerContent}>
          <div style={styles.footerSection}>
            <strong>Origin:</strong> {window.location.origin}
          </div>
          <div style={styles.footerSection}>
            <strong>Module:</strong> {MODULE_ID}
          </div>
          <div style={styles.footerSection}>
            <strong>Architecture:</strong> Hybrid (SQLite + IndexedDB)
          </div>
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: {
    minHeight: '100vh',
    display: 'flex',
    flexDirection: 'column',
    background: '#f5f5f5',
  },
  header: {
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    color: 'white',
    padding: '20px',
    boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
  },
  headerContent: {
    maxWidth: '1200px',
    margin: '0 auto',
  },
  title: {
    fontSize: '28px',
    fontWeight: 'bold',
    margin: '0 0 5px 0',
  },
  subtitle: {
    fontSize: '14px',
    opacity: 0.9,
    margin: 0,
  },
  statusBar: {
    display: 'flex',
    gap: '10px',
    marginTop: '15px',
    flexWrap: 'wrap',
  },
  statusReady: {
    background: 'rgba(76, 175, 80, 0.2)',
    color: 'white',
    padding: '6px 12px',
    borderRadius: '20px',
    fontSize: '13px',
    fontWeight: '500',
  },
  statusNotReady: {
    background: 'rgba(255, 255, 255, 0.2)',
    color: 'white',
    padding: '6px 12px',
    borderRadius: '20px',
    fontSize: '13px',
    fontWeight: '500',
  },
  pendingBadge: {
    background: 'rgba(255, 193, 7, 0.3)',
    color: 'white',
    padding: '6px 12px',
    borderRadius: '20px',
    fontSize: '13px',
    fontWeight: '500',
  },
  tabs: {
    display: 'flex',
    background: 'white',
    borderBottom: '2px solid #e0e0e0',
    gap: '0',
    overflowX: 'auto',
  },
  tab: {
    flex: '1',
    padding: '15px 20px',
    background: 'transparent',
    border: 'none',
    borderBottom: '3px solid transparent',
    cursor: 'pointer',
    fontSize: '15px',
    fontWeight: '500',
    color: '#666',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '8px',
    transition: 'all 0.2s',
    minWidth: '140px',
  },
  tabActive: {
    color: '#667eea',
    borderBottomColor: '#667eea',
    background: '#f8f9ff',
  },
  tabIcon: {
    fontSize: '18px',
  },
  content: {
    flex: 1,
    padding: '20px',
    maxWidth: '1200px',
    width: '100%',
    margin: '0 auto',
    overflowY: 'auto',
  },
  loading: {
    textAlign: 'center',
    padding: '60px 20px',
    color: '#666',
  },
  loadingHint: {
    fontSize: '14px',
    color: '#999',
    marginTop: '10px',
  },
  footer: {
    background: 'white',
    borderTop: '1px solid #e0e0e0',
    padding: '12px 20px',
    fontSize: '12px',
    color: '#666',
  },
  footerContent: {
    maxWidth: '1200px',
    margin: '0 auto',
    display: 'flex',
    gap: '20px',
    flexWrap: 'wrap',
  },
  footerSection: {
    display: 'flex',
    gap: '5px',
  },
};

export default App;

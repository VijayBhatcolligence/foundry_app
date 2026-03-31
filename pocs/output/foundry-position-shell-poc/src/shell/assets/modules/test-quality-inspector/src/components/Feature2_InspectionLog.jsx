import React, { useState, useEffect } from 'react';
import { openDB, getAll, add, deleteRecord, clear } from '../utils/indexedDBHelper';

/**
 * Feature 2: Inspection Log (IndexedDB Cache)
 *
 * 🎯 WHAT THIS PROVES:
 * ✅ IndexedDB local storage (expendable cache)
 * ✅ Data persists across page reloads
 * ✅ Can be cleared without data loss
 * ✅ Offline data entry capability
 *
 * SCENARIO:
 * 1. User adds inspection log (online or offline)
 * 2. Saved to IndexedDB (browser storage)
 * 3. Data visible on reload (proves persistence)
 * 4. Can clear all logs (proves expendable nature)
 * 5. No sync to backend (local-only demo)
 */

const DB_NAME = 'quality_inspector_db';
const STORE_NAME = 'inspection_logs';

function Feature2_InspectionLog({ onUpdate }) {
  const [logs, setLogs] = useState([]);
  const [productId, setProductId] = useState('');
  const [inspectorName, setInspectorName] = useState('');
  const [result, setResult] = useState('pass');
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [db, setDb] = useState(null);

  useEffect(() => {
    initializeDB();
  }, []);

  const initializeDB = async () => {
    try {
      console.log('[Inspection Log] Initializing IndexedDB...');
      const database = await openDB(DB_NAME, 1, {
        upgrade(db) {
          if (!db.objectStoreNames.contains(STORE_NAME)) {
            const store = db.createObjectStore(STORE_NAME, { keyPath: 'id', autoIncrement: true });
            store.createIndex('productId', 'productId', { unique: false });
            store.createIndex('timestamp', 'timestamp', { unique: false });
            console.log('[Inspection Log] Object store created');
          }
        }
      });
      setDb(database);
      await loadLogs(database);
      console.log('[Inspection Log] IndexedDB initialized successfully');
    } catch (err) {
      console.error('[Inspection Log] Failed to initialize IndexedDB:', err);
      setError('Failed to initialize local database');
    }
  };

  const loadLogs = async (database = db) => {
    if (!database) return;

    try {
      const allLogs = await getAll(database, STORE_NAME);
      setLogs(allLogs.sort((a, b) => b.timestamp - a.timestamp));
    } catch (err) {
      console.error('[Inspection Log] Failed to load logs:', err);
      setError('Failed to load inspection logs');
    }
  };

  const handleSubmit = async () => {
    if (!productId.trim() || !inspectorName.trim()) {
      setError('Product ID and Inspector Name are required');
      return;
    }

    if (!db) {
      setError('Database not initialized');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const logEntry = {
        productId: productId.trim(),
        inspectorName: inspectorName.trim(),
        result,
        notes: notes.trim(),
        timestamp: Date.now(),
        createdAt: new Date().toISOString()
      };

      await add(db, STORE_NAME, logEntry);
      console.log('[Inspection Log] Log saved to IndexedDB:', logEntry);

      // Clear form
      setProductId('');
      setInspectorName('');
      setResult('pass');
      setNotes('');

      // Reload logs
      await loadLogs();

      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('[Inspection Log] Failed to save log:', err);
      setError('Failed to save inspection log');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id) => {
    if (!db) return;

    try {
      await deleteRecord(db, STORE_NAME, id);
      console.log('[Inspection Log] Log deleted:', id);
      await loadLogs();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('[Inspection Log] Failed to delete log:', err);
      setError('Failed to delete log');
    }
  };

  const handleClearAll = async () => {
    if (!db) return;
    if (!window.confirm('Clear all inspection logs? This action cannot be undone.')) return;

    try {
      await clear(db, STORE_NAME);
      console.log('[Inspection Log] All logs cleared');
      await loadLogs();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('[Inspection Log] Failed to clear logs:', err);
      setError('Failed to clear logs');
    }
  };

  return (
    <div>
      <h2 style={{ color: '#1976d2', marginTop: 0 }}>Inspection Log</h2>
      <p style={{ color: '#666', fontSize: '14px' }}>
        IndexedDB storage (expendable cache) - {logs.length} log(s) stored locally
      </p>

      {error && (
        <div style={{
          padding: '12px',
          background: '#ffebee',
          border: '1px solid #ef5350',
          borderRadius: '4px',
          color: '#c62828',
          marginBottom: '15px',
          fontSize: '14px'
        }}>
          <strong>Error:</strong> {error}
        </div>
      )}

      {/* Input Form */}
      <div style={{
        padding: '20px',
        background: '#f5f5f5',
        borderRadius: '4px',
        marginBottom: '20px'
      }}>
        <h3 style={{ margin: '0 0 15px 0', fontSize: '16px' }}>New Inspection Log</h3>

        <div style={{ marginBottom: '12px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold' }}>
            Product ID *
          </label>
          <input
            type="text"
            value={productId}
            onChange={(e) => setProductId(e.target.value)}
            placeholder="e.g., PRD-12345"
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '14px',
              boxSizing: 'border-box'
            }}
            disabled={loading}
          />
        </div>

        <div style={{ marginBottom: '12px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold' }}>
            Inspector Name *
          </label>
          <input
            type="text"
            value={inspectorName}
            onChange={(e) => setInspectorName(e.target.value)}
            placeholder="Your name"
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '14px',
              boxSizing: 'border-box'
            }}
            disabled={loading}
          />
        </div>

        <div style={{ marginBottom: '12px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold' }}>
            Result
          </label>
          <select
            value={result}
            onChange={(e) => setResult(e.target.value)}
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '14px',
              boxSizing: 'border-box'
            }}
            disabled={loading}
          >
            <option value="pass">Pass</option>
            <option value="fail">Fail</option>
            <option value="conditional">Conditional</option>
          </select>
        </div>

        <div style={{ marginBottom: '12px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold' }}>
            Notes
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Additional notes or observations"
            rows="3"
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '14px',
              boxSizing: 'border-box',
              resize: 'vertical'
            }}
            disabled={loading}
          />
        </div>

        <button
          onClick={handleSubmit}
          disabled={loading}
          style={{
            padding: '10px 20px',
            background: loading ? '#ccc' : '#4caf50',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: loading ? 'not-allowed' : 'pointer',
            fontSize: '14px',
            fontWeight: 'bold',
            width: '100%'
          }}
        >
          {loading ? 'Saving...' : 'Save to IndexedDB'}
        </button>
      </div>

      {/* Logs List */}
      <div style={{ marginBottom: '15px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h3 style={{ margin: 0, fontSize: '16px' }}>Saved Logs ({logs.length})</h3>
        {logs.length > 0 && (
          <button
            onClick={handleClearAll}
            style={{
              padding: '6px 12px',
              background: '#ef5350',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '12px'
            }}
          >
            Clear All
          </button>
        )}
      </div>

      {logs.length === 0 ? (
        <div style={{
          padding: '20px',
          textAlign: 'center',
          color: '#999',
          border: '2px dashed #ddd',
          borderRadius: '4px'
        }}>
          No inspection logs yet. Add one above!
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          {logs.map((log) => (
            <div
              key={log.id}
              style={{
                padding: '15px',
                background: 'white',
                border: '1px solid #e0e0e0',
                borderRadius: '4px'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px' }}>
                <div>
                  <strong style={{ fontSize: '16px' }}>{log.productId}</strong>
                  <span style={{
                    marginLeft: '10px',
                    padding: '2px 8px',
                    borderRadius: '3px',
                    fontSize: '12px',
                    fontWeight: 'bold',
                    background: log.result === 'pass' ? '#4caf50' :
                               log.result === 'fail' ? '#ef5350' : '#ff9800',
                    color: 'white'
                  }}>
                    {log.result.toUpperCase()}
                  </span>
                </div>
                <button
                  onClick={() => handleDelete(log.id)}
                  style={{
                    padding: '4px 8px',
                    background: '#ef5350',
                    color: 'white',
                    border: 'none',
                    borderRadius: '3px',
                    cursor: 'pointer',
                    fontSize: '12px'
                  }}
                >
                  Delete
                </button>
              </div>
              <div style={{ fontSize: '14px', color: '#666', marginBottom: '5px' }}>
                Inspector: <strong>{log.inspectorName}</strong>
              </div>
              {log.notes && (
                <div style={{ fontSize: '14px', color: '#666', marginBottom: '5px' }}>
                  Notes: {log.notes}
                </div>
              )}
              <div style={{ fontSize: '12px', color: '#999' }}>
                {new Date(log.timestamp).toLocaleString()}
              </div>
            </div>
          ))}
        </div>
      )}

      <div style={{
        marginTop: '20px',
        padding: '12px',
        background: '#e3f2fd',
        borderLeft: '4px solid #2196f3',
        fontSize: '13px',
        color: '#0d47a1'
      }}>
        <strong>Storage Info:</strong> Using IndexedDB database "{DB_NAME}" with store "{STORE_NAME}".
        This is expendable cache data that can be cleared without data loss.
      </div>
    </div>
  );
}

export default Feature2_InspectionLog;

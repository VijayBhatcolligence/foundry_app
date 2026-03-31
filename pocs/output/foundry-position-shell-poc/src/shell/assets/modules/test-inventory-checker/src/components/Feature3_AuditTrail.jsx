import { useState, useEffect } from 'react';
import { initDatabase, getDatabase, DB_NAME } from '../utils/dbHelper';
import { getAll as getAllFromDB, add as addToDB, deleteRecord, clear as clearDB } from '../utils/indexedDBHelper';

/**
 * Feature 3: Audit Trail (IndexedDB Storage)
 *
 * 🎯 WHAT THIS PROVES:
 * ✅ IndexedDB for regular data storage (not SQLite)
 * ✅ Data persists across app restarts
 * ✅ Offline data entry capability
 * ✅ Can be cleared without data loss
 *
 * SCENARIO:
 * 1. User adds audit trail entry (online or offline)
 * 2. Saved to IndexedDB (browser storage)
 * 3. Data persists through page reload
 * 4. Can clear all entries (proves expendable nature)
 * 5. No backend sync (local-only demo)
 *
 * CONCEPT CLARIFICATION:
 * ❌ SQLite (Flutter) = ONLY for large files (photos, documents)
 * ✅ IndexedDB = For all regular data (audit trails, logs, etc.)
 *
 * This feature used to write to SQLite, but now correctly uses IndexedDB
 * because audit trails are NOT large files.
 */

const STORE_NAME = 'audit_trails';

function Feature3_AuditTrail({ onAuditSaved }) {
  const [action, setAction] = useState('');
  const [notes, setNotes] = useState('');
  const [auditTrails, setAuditTrails] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);

  useEffect(() => {
    initializeDatabase();
    loadAuditTrails();
  }, []);

  const initializeDatabase = async () => {
    try {
      await initDatabase();
      console.log('[AuditTrail] Database initialized');
    } catch (err) {
      console.error('[AuditTrail] Database initialization error:', err);
      setError('Failed to initialize database: ' + err.message);
    }
  };

  const loadAuditTrails = async () => {
    try {
      console.log('[AuditTrail] Loading from IndexedDB...');

      const db = await getDatabase();
      const allTrails = await getAllFromDB(db, STORE_NAME);

      // Sort by timestamp descending
      allTrails.sort((a, b) => b.timestamp - a.timestamp);

      setAuditTrails(allTrails);
      console.log('[AuditTrail] ✅ Loaded audit trails from IndexedDB:', allTrails.length);
    } catch (err) {
      console.error('[AuditTrail] Error loading:', err);
      setError('Failed to load audit trails from IndexedDB: ' + err.message);
    }
  };

  const handleSave = async () => {
    setError(null);
    setSuccess(null);

    // Validation
    if (!action.trim()) {
      setError('Action is required');
      return;
    }

    setLoading(true);

    try {
      const trail = {
        action: action.trim(),
        notes: notes.trim() || null,
        timestamp: Date.now(),
      };

      console.log('[AuditTrail] Saving to IndexedDB:', trail);

      const db = await getDatabase();
      const id = await addToDB(db, STORE_NAME, trail);

      console.log('[AuditTrail] ✅ Saved to IndexedDB successfully, ID:', id);

      setSuccess(`Audit trail saved to IndexedDB! (ID: ${id})`);

      // Clear form
      setAction('');
      setNotes('');

      // Reload list
      await loadAuditTrails();

      if (onAuditSaved) {
        onAuditSaved();
      }
    } catch (err) {
      console.error('[AuditTrail] Error saving:', err);
      setError('Failed to save audit trail: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Are you sure you want to delete this audit trail entry?')) {
      return;
    }

    try {
      console.log('[AuditTrail] Deleting audit trail:', id);

      const db = await getDatabase();
      await deleteRecord(db, STORE_NAME, id);

      console.log('[AuditTrail] ✅ Deleted successfully');
      setSuccess('Audit trail deleted from IndexedDB');
      await loadAuditTrails();
    } catch (err) {
      console.error('[AuditTrail] Error deleting:', err);
      setError('Failed to delete audit trail: ' + err.message);
    }
  };

  const handleClearAll = async () => {
    if (!confirm('Are you sure you want to clear all audit trails? This will delete all data from IndexedDB.')) {
      return;
    }

    try {
      console.log('[AuditTrail] Clearing all trails from IndexedDB...');

      const db = await getDatabase();
      await clearDB(db, STORE_NAME);

      console.log('[AuditTrail] ✅ All trails cleared');

      setAuditTrails([]);
      setSuccess('All audit trails cleared from IndexedDB');
    } catch (err) {
      console.error('[AuditTrail] Error clearing:', err);
      setError('Failed to clear audit trails: ' + err.message);
    }
  };

  const formatDate = (timestamp) => {
    return new Date(timestamp).toLocaleString();
  };

  const actionPresets = [
    'Count Cycle',
    'Spot Check',
    'Bin Transfer',
    'Location Audit',
    'Inventory Adjustment',
  ];

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.cardHeader}>
          <h2 style={styles.cardTitle}>📋 Audit Trail</h2>
          <span style={styles.badge}>IndexedDB - Expendable</span>
        </div>

        <div style={styles.cardBody}>
          <p style={styles.description}>
            This feature demonstrates <strong>IndexedDB storage</strong> for regular data.
            Data is stored in the browser's IndexedDB and <strong>CAN be lost</strong> if cache is cleared.
            For large files (photos, documents), use SQLite/Flutter storage instead.
          </p>

          {/* Form */}
          <div style={styles.form}>
            <div style={styles.formGroup}>
              <label style={styles.label}>Action *</label>
              <input
                type="text"
                placeholder="Enter action or select preset below"
                value={action}
                onChange={(e) => setAction(e.target.value)}
                style={styles.input}
                disabled={loading}
              />

              {/* Preset Buttons */}
              <div style={styles.presets}>
                {actionPresets.map(preset => (
                  <button
                    key={preset}
                    onClick={() => setAction(preset)}
                    style={styles.presetButton}
                    disabled={loading}
                  >
                    {preset}
                  </button>
                ))}
              </div>
            </div>

            <div style={styles.formGroup}>
              <label style={styles.label}>Notes (Optional)</label>
              <textarea
                placeholder="Additional notes or comments..."
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                style={styles.textarea}
                disabled={loading}
                rows="3"
              />
            </div>

            <button
              onClick={handleSave}
              style={styles.saveButton}
              disabled={loading}
            >
              {loading ? '⏳ Saving...' : '💾 Save to IndexedDB (Expendable Cache)'}
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

          {/* Audit Trails List */}
          <div style={styles.listSection}>
            <div style={styles.listHeader}>
              <strong>📋 Saved Audit Trails ({auditTrails.length})</strong>
              {auditTrails.length > 0 && (
                <button onClick={handleClearAll} style={styles.clearButton}>
                  🗑️ Clear All
                </button>
              )}
            </div>

            {auditTrails.length === 0 ? (
              <div style={styles.emptyState}>
                <p>No audit trails saved yet.</p>
                <p style={styles.hint}>Add audit trail entries using the form above.</p>
              </div>
            ) : (
              <div style={styles.auditList}>
                {auditTrails.map((audit) => (
                  <div key={audit.id} style={styles.auditCard}>
                    <div style={styles.auditHeader}>
                      <div>
                        <div style={styles.auditAction}>{audit.action}</div>
                        <div style={styles.auditId}>ID: {audit.id}</div>
                      </div>
                      <button
                        onClick={() => handleDelete(audit.id)}
                        style={styles.deleteButton}
                        title="Delete"
                      >
                        🗑️
                      </button>
                    </div>

                    {audit.notes && (
                      <div style={styles.auditNotes}>
                        <strong>Notes:</strong> {audit.notes}
                      </div>
                    )}

                    <div style={styles.auditMeta}>
                      <span>🕐 {formatDate(audit.timestamp)}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Info Box */}
          <div style={styles.infoBox}>
            <strong>ℹ️ Storage Strategy Clarification:</strong>
            <ul style={styles.infoList}>
              <li>✅ <strong>IndexedDB:</strong> For all regular data (audit trails, logs, counts, etc.)</li>
              <li>✅ <strong>SQLite (Flutter):</strong> ONLY for large files (photos, documents)</li>
              <li>📦 Data stored in: <code>IndexedDB (inventory_checker_db / audit_trails)</code></li>
              <li>💾 Data persists across app restarts</li>
              <li>⚠️ Data can be lost if browser cache is cleared</li>
              <li>🔌 Works offline (local storage only)</li>
              <li>🚫 No sync to backend (local-only demo)</li>
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
    background: '#FF9800',
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
  input: {
    width: '100%',
    padding: '10px 12px',
    fontSize: '15px',
    border: '2px solid #e0e0e0',
    borderRadius: '6px',
    outline: 'none',
    transition: 'border-color 0.2s',
  },
  textarea: {
    width: '100%',
    padding: '10px 12px',
    fontSize: '15px',
    border: '2px solid #e0e0e0',
    borderRadius: '6px',
    outline: 'none',
    resize: 'vertical',
    fontFamily: 'inherit',
  },
  presets: {
    display: 'flex',
    gap: '8px',
    marginTop: '8px',
    flexWrap: 'wrap',
  },
  presetButton: {
    padding: '6px 12px',
    background: '#f5f5f5',
    border: '1px solid #e0e0e0',
    borderRadius: '6px',
    fontSize: '13px',
    cursor: 'pointer',
    transition: 'background 0.2s',
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
  hint: {
    fontSize: '13px',
    color: '#bbb',
    marginTop: '5px',
  },
  auditList: {
    display: 'grid',
    gap: '10px',
  },
  auditCard: {
    background: '#fafafa',
    border: '1px solid #e0e0e0',
    borderRadius: '8px',
    padding: '15px',
  },
  auditHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: '8px',
  },
  auditAction: {
    fontWeight: 'bold',
    color: '#333',
    fontSize: '15px',
  },
  auditId: {
    fontSize: '11px',
    color: '#999',
    fontFamily: 'monospace',
    marginTop: '2px',
  },
  deleteButton: {
    padding: '4px 8px',
    background: 'transparent',
    border: '1px solid #e0e0e0',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
  },
  auditNotes: {
    fontSize: '13px',
    color: '#666',
    marginBottom: '8px',
    paddingLeft: '10px',
    borderLeft: '3px solid #e0e0e0',
  },
  auditMeta: {
    display: 'flex',
    justifyContent: 'space-between',
    fontSize: '12px',
    color: '#999',
    marginTop: '8px',
    paddingTop: '8px',
    borderTop: '1px solid #e0e0e0',
  },
  infoBox: {
    background: '#fff3e0',
    border: '1px solid #FF9800',
    borderRadius: '8px',
    padding: '15px',
    fontSize: '14px',
    color: '#e65100',
    marginTop: '20px',
  },
  infoList: {
    marginTop: '10px',
    marginLeft: '20px',
    lineHeight: '1.8',
  },
};

export default Feature3_AuditTrail;

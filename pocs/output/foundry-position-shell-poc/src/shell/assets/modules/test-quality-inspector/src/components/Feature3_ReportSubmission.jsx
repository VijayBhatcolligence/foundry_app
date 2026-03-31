import React, { useState, useEffect } from 'react';
import { ActionQueue } from '../../../shared/utils/actionQueue.js';
import { SyncManager } from '../../../shared/utils/syncManager.js';

/**
 * Feature 3: Report Submission with Auto-Sync (NEW ARCHITECTURE)
 *
 * 🎯 WHAT THIS PROVES:
 * ✅ IndexedDB-first action queue (all actions in browser)
 * ✅ Flutter file system for photos only
 * ✅ Auto-sync when network available
 * ✅ Photo saved separately, path stored in IndexedDB
 * ✅ Retry logic for failed syncs
 *
 * ARCHITECTURE:
 * 1. Photo → Flutter file system via bridge → returns path
 * 2. Action (with photo_path) → IndexedDB
 * 3. SyncManager reads IndexedDB → attaches photo → syncs to backend
 * 4. Delete file after successful sync
 */

const MODULE_ID = 'test-quality-inspector';

function Feature3_ReportSubmission({ onUpdate }) {
  const [reportType, setReportType] = useState('daily');
  const [summary, setSummary] = useState('');
  const [details, setDetails] = useState('');
  const [priority, setPriority] = useState('normal');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [actions, setActions] = useState([]);
  const [bridgeReady, setBridgeReady] = useState(false);
  const [capturedPhoto, setCapturedPhoto] = useState(null); // {photoPath: 'file://...', thumbnailPath: 'data:...'}
  const [capturingPhoto, setCapturingPhoto] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);

  // NEW: Initialize IndexedDB ActionQueue and SyncManager
  const [actionQueue] = useState(() => new ActionQueue(MODULE_ID));
  const [syncManager] = useState(() => new SyncManager(MODULE_ID, {
    maxRetries: 3,
    deleteFilesAfterSync: true,
    onProgress: (current, total, action) => {
      console.log(`[Report Submission] Syncing ${current}/${total}:`, action.action_type);
    },
    endpoints: {
      submit_report: '/api/reports',
    }
  }));

  useEffect(() => {
    const initializeAll = async () => {
      try {
        // Wait for bridge to be ready
        await waitForBridge();
        setBridgeReady(true);

        // Initialize ActionQueue and SyncManager
        await actionQueue.initialize();
        await syncManager.initialize();

        console.log('[Report Submission] ✅ Initialized (IndexedDB mode)');

        // Load actions
        await loadActions();

        // Auto-sync on startup (after 2 seconds)
        setTimeout(() => {
          triggerSync();
        }, 2000);

      } catch (err) {
        console.error('[Report Submission] Initialization error:', err);
        setError('Failed to initialize: ' + err.message);
      }
    };

    initializeAll();
  }, []);

  const waitForBridge = () => {
    return new Promise((resolve) => {
      const check = () => {
        if (window.shellBridge) {
          resolve();
        } else {
          setTimeout(check, 100);
        }
      };
      check();
    });
  };

  const loadActions = async () => {
    try {
      const allActions = await actionQueue.getAll();
      setActions(allActions.sort((a, b) => b.created_at - a.created_at));

      // Update pending count
      const pending = await actionQueue.getPendingCount();
      setPendingCount(pending);

      console.log('[Report Submission] Loaded actions from IndexedDB:', allActions.length);
    } catch (err) {
      console.error('[Report Submission] Failed to load actions:', err);
      setError('Failed to load actions from IndexedDB');
    }
  };

  const triggerSync = async () => {
    if (syncing) {
      console.log('[Report Submission] Sync already in progress');
      return;
    }

    try {
      setSyncing(true);
      console.log('[Report Submission] Triggering auto-sync...');

      const result = await syncManager.syncAll();

      console.log(`[Report Submission] Sync complete: ${result.synced} synced, ${result.failed} failed`);

      // Reload actions to update UI
      await loadActions();

      // Notify parent of update (pass pending count)
      const newPendingCount = await actionQueue.getPendingCount();
      if (onUpdate) onUpdate(newPendingCount);

    } catch (err) {
      console.error('[Report Submission] Sync failed:', err);
    } finally {
      setSyncing(false);
    }
  };

  const handleCapturePhoto = async () => {
    if (!window.shellBridge || !window.shellBridge.capturePhoto) {
      setError('Photo capture not available');
      return;
    }

    setCapturingPhoto(true);
    setError(null);

    try {
      console.log('[Report Submission] Capturing photo...');
      const result = await window.shellBridge.capturePhoto('report-photo');

      if (result.success) {
        // Bridge wraps result in 'data' object
        const photoData = result.data || result;

        console.log('[Report Submission] Photo captured');
        console.log('[Report Submission] File path (for upload):', photoData.filePath);

        setCapturedPhoto({
          filePath: photoData.filePath,        // file:// path for storage
          photoPath: photoData.photoPath,      // base64 data URL for display
          thumbnailPath: photoData.thumbnailPath, // base64 thumbnail for preview
          timestamp: photoData.timestamp
        });
      } else {
        setError(result.error || 'Photo capture failed');
      }
    } catch (err) {
      console.error('[Report Submission] Photo capture error:', err);
      setError('Failed to capture photo: ' + err.message);
    } finally {
      setCapturingPhoto(false);
    }
  };

  const handleRemovePhoto = () => {
    setCapturedPhoto(null);
  };

  const handleSubmit = async () => {
    if (!summary.trim()) {
      setError('Summary is required');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Build payload
      const payload = {
        report_type: reportType,
        summary: summary.trim(),
        details: details.trim(),
        priority,
        submitted_at: new Date().toISOString()
      };

      // NEW ARCHITECTURE: Photo already captured and saved to Flutter
      // Just store the file path in IndexedDB payload
      if (capturedPhoto && capturedPhoto.filePath) {
        payload.photo_path = capturedPhoto.filePath; // File path only!
        payload.hasPhoto = true;
        console.log('[Report Submission] Including photo_path in payload:', capturedPhoto.filePath);
      }

      // Save action to IndexedDB
      const actionId = await actionQueue.save('submit_report', payload);

      console.log('[Report Submission] ✅ Action saved to IndexedDB:', actionId);

      // Clear form
      setSummary('');
      setDetails('');
      setReportType('daily');
      setPriority('normal');
      setCapturedPhoto(null);

      // Reload actions
      await loadActions();

      // Notify parent of update (pass pending count)
      const newPendingCount = await actionQueue.getPendingCount();
      if (onUpdate) onUpdate(newPendingCount);

      // Trigger auto-sync after saving (500ms delay)
      console.log('[Report Submission] Action saved, triggering auto-sync...');
      setTimeout(() => {
        triggerSync();
      }, 500);

    } catch (err) {
      console.error('[Report Submission] Failed to save action:', err);
      setError('Failed to save report to IndexedDB');
    } finally {
      setLoading(false);
    }
  };

  const handleMarkSynced = async (actionId) => {
    try {
      await actionQueue.markSynced(actionId);
      console.log('[Report Submission] Action marked as synced:', actionId);
      await loadActions();
      const newPendingCount = await actionQueue.getPendingCount();
      if (onUpdate) onUpdate(newPendingCount);
    } catch (err) {
      console.error('[Report Submission] Failed to mark synced:', err);
      setError('Failed to mark action as synced');
    }
  };

  const handleMarkError = async (actionId) => {
    try {
      await actionQueue.markFailed(actionId, 'Simulated network error');
      console.log('[Report Submission] Action marked as failed:', actionId);
      await loadActions();
      const newPendingCount = await actionQueue.getPendingCount();
      if (onUpdate) onUpdate(newPendingCount);
    } catch (err) {
      console.error('[Report Submission] Failed to mark error:', err);
      setError('Failed to mark action as failed');
    }
  };

  const handleDelete = async (actionId) => {
    if (!window.confirm('Delete this action? This cannot be undone.')) return;

    try {
      await actionQueue.delete(actionId);
      console.log('[Report Submission] Action deleted:', actionId);
      await loadActions();
      const newPendingCount = await actionQueue.getPendingCount();
      if (onUpdate) onUpdate(newPendingCount);
    } catch (err) {
      console.error('[Report Submission] Failed to delete action:', err);
      setError('Failed to delete action');
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'pending': return '#ff9800';
      case 'syncing': return '#2196f3';
      case 'synced': return '#4caf50';
      case 'failed': return '#ef5350';
      default: return '#999';
    }
  };

  if (!bridgeReady) {
    return (
      <div style={{ padding: '20px', textAlign: 'center', color: '#999' }}>
        Initializing IndexedDB ActionQueue...
      </div>
    );
  }

  return (
    <div>
      <h2 style={{ color: '#1976d2', marginTop: 0 }}>
        Report Submission
        {syncing && <span style={{ marginLeft: '10px', fontSize: '14px', color: '#ff9800' }}>🔄 Syncing...</span>}
      </h2>
      <p style={{ color: '#666', fontSize: '14px' }}>
        IndexedDB ActionQueue - {actions.length} action(s) total | {pendingCount} pending
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

      {/* Submit Form */}
      <div style={{
        padding: '20px',
        background: '#f5f5f5',
        borderRadius: '4px',
        marginBottom: '20px'
      }}>
        <h3 style={{ margin: '0 0 15px 0', fontSize: '16px' }}>New Report</h3>

        <div style={{ marginBottom: '12px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold' }}>
            Report Type
          </label>
          <select
            value={reportType}
            onChange={(e) => setReportType(e.target.value)}
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
            <option value="daily">Daily Report</option>
            <option value="weekly">Weekly Report</option>
            <option value="incident">Incident Report</option>
            <option value="audit">Audit Report</option>
          </select>
        </div>

        <div style={{ marginBottom: '12px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold' }}>
            Summary *
          </label>
          <input
            type="text"
            value={summary}
            onChange={(e) => setSummary(e.target.value)}
            placeholder="Brief summary of the report"
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
            Details
          </label>
          <textarea
            value={details}
            onChange={(e) => setDetails(e.target.value)}
            placeholder="Detailed information about the report"
            rows="4"
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

        <div style={{ marginBottom: '12px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold' }}>
            Priority
          </label>
          <select
            value={priority}
            onChange={(e) => setPriority(e.target.value)}
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
            <option value="low">Low</option>
            <option value="normal">Normal</option>
            <option value="high">High</option>
            <option value="critical">Critical</option>
          </select>
        </div>

        {/* Photo Capture */}
        <div style={{ marginBottom: '12px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold' }}>
            📸 Photo Evidence (Optional)
          </label>
          {!capturedPhoto ? (
            <button
              onClick={handleCapturePhoto}
              disabled={capturingPhoto || loading}
              style={{
                padding: '10px 20px',
                background: capturingPhoto ? '#ccc' : '#4caf50',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: capturingPhoto || loading ? 'not-allowed' : 'pointer',
                fontSize: '14px',
                fontWeight: 'bold',
                width: '100%'
              }}
            >
              {capturingPhoto ? '📸 Opening Camera...' : '📸 Capture Photo'}
            </button>
          ) : (
            <div style={{
              border: '2px solid #4caf50',
              borderRadius: '4px',
              padding: '10px',
              background: '#f1f8f4'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                {capturedPhoto.thumbnailPath && (
                  <img
                    src={capturedPhoto.thumbnailPath}
                    alt="Captured photo"
                    style={{
                      width: '80px',
                      height: '80px',
                      objectFit: 'cover',
                      borderRadius: '4px',
                      border: '1px solid #ddd'
                    }}
                  />
                )}
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: '13px', color: '#2e7d32', fontWeight: 'bold' }}>
                    ✅ Photo Captured
                  </div>
                  <div style={{ fontSize: '11px', color: '#666', marginTop: '4px' }}>
                    Saved to Flutter → Path stored in IndexedDB
                  </div>
                </div>
                <button
                  onClick={handleRemovePhoto}
                  disabled={loading}
                  style={{
                    padding: '6px 12px',
                    background: '#ef5350',
                    color: 'white',
                    border: 'none',
                    borderRadius: '4px',
                    cursor: loading ? 'not-allowed' : 'pointer',
                    fontSize: '12px'
                  }}
                >
                  Remove
                </button>
              </div>
            </div>
          )}
        </div>

        <button
          onClick={handleSubmit}
          disabled={loading}
          style={{
            padding: '10px 20px',
            background: loading ? '#ccc' : '#1976d2',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: loading ? 'not-allowed' : 'pointer',
            fontSize: '14px',
            fontWeight: 'bold',
            width: '100%'
          }}
        >
          {loading ? 'Saving...' : (capturedPhoto ? '💾 Save Report with Photo' : '💾 Save Report')}
        </button>
      </div>

      {/* Actions Queue */}
      <div style={{ marginBottom: '15px' }}>
        <h3 style={{ margin: 0, fontSize: '16px' }}>
          Action Queue ({actions.length})
          {pendingCount > 0 && (
            <span style={{
              marginLeft: '10px',
              padding: '2px 8px',
              background: '#ff9800',
              color: 'white',
              borderRadius: '12px',
              fontSize: '12px'
            }}>
              🔄 {pendingCount} pending
            </span>
          )}
        </h3>
      </div>

      {actions.length === 0 ? (
        <div style={{
          padding: '20px',
          textAlign: 'center',
          color: '#999',
          border: '2px dashed #ddd',
          borderRadius: '4px'
        }}>
          No actions in queue. Submit a report above!
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          {actions.map((action) => {
            const payload = action.payload;

            return (
              <div
                key={action.id}
                style={{
                  padding: '15px',
                  background: 'white',
                  border: '1px solid #e0e0e0',
                  borderRadius: '4px'
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px' }}>
                  <div>
                    <strong style={{ fontSize: '14px' }}>{action.action_type}</strong>
                    <span style={{
                      marginLeft: '10px',
                      padding: '2px 8px',
                      borderRadius: '3px',
                      fontSize: '11px',
                      fontWeight: 'bold',
                      background: getStatusColor(action.status),
                      color: 'white'
                    }}>
                      {action.status.toUpperCase()}
                    </span>
                  </div>
                  <div style={{ display: 'flex', gap: '5px' }}>
                    {action.status === 'pending' && (
                      <>
                        <button
                          onClick={() => handleMarkSynced(action.id)}
                          style={{
                            padding: '4px 8px',
                            background: '#4caf50',
                            color: 'white',
                            border: 'none',
                            borderRadius: '3px',
                            cursor: 'pointer',
                            fontSize: '11px'
                          }}
                        >
                          Mark Synced
                        </button>
                        <button
                          onClick={() => handleMarkError(action.id)}
                          style={{
                            padding: '4px 8px',
                            background: '#ff9800',
                            color: 'white',
                            border: 'none',
                            borderRadius: '3px',
                            cursor: 'pointer',
                            fontSize: '11px'
                          }}
                        >
                          Mark Error
                        </button>
                      </>
                    )}
                    <button
                      onClick={() => handleDelete(action.id)}
                      style={{
                        padding: '4px 8px',
                        background: '#ef5350',
                        color: 'white',
                        border: 'none',
                        borderRadius: '3px',
                        cursor: 'pointer',
                        fontSize: '11px'
                      }}
                    >
                      Delete
                    </button>
                  </div>
                </div>

                <div style={{ fontSize: '13px', color: '#666', marginBottom: '8px' }}>
                  <div><strong>Report Type:</strong> {payload.report_type}</div>
                  <div><strong>Summary:</strong> {payload.summary}</div>
                  {payload.details && <div><strong>Details:</strong> {payload.details}</div>}
                  <div><strong>Priority:</strong> {payload.priority}</div>
                  {payload.hasPhoto && (
                    <div style={{ color: '#4caf50', marginTop: '4px' }}>
                      <strong>📸 Photo:</strong> {payload.photo_path}
                    </div>
                  )}
                </div>

                <div style={{ fontSize: '12px', color: '#999', marginTop: '8px' }}>
                  <div>ID: {action.id}</div>
                  <div>Created: {new Date(action.created_at).toLocaleString()}</div>
                  {action.error && (
                    <div style={{ color: '#ef5350' }}>Error: {action.error}</div>
                  )}
                  {action.retry_count > 0 && (
                    <div style={{ color: '#ff9800' }}>Retries: {action.retry_count}</div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      <div style={{
        marginTop: '20px',
        padding: '12px',
        background: '#e3f2fd',
        borderLeft: '4px solid #2196f3',
        fontSize: '13px',
        color: '#1565c0'
      }}>
        <strong>✨ NEW Architecture:</strong> All actions stored in IndexedDB.
        Photos saved to Flutter file system. SyncManager reads from IndexedDB, attaches photos, and syncs to backend.
      </div>
    </div>
  );
}

export default Feature3_ReportSubmission;

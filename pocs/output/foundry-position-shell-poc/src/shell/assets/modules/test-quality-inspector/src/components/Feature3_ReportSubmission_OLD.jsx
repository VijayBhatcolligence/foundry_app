import React, { useState, useEffect } from 'react';

/**
 * Feature 3: Report Submission with Auto-Sync
 *
 * 🎯 WHAT THIS PROVES:
 * ✅ Offline-first action queue (SQLite source of truth)
 * ✅ Auto-sync when network available
 * ✅ Photo upload with actions
 * ✅ Data survives app restarts
 * ✅ Retry logic for failed syncs
 *
 * SCENARIO:
 * 1. User submits report offline → Saved to SQLite
 * 2. Network connects → Auto-syncs to backend
 * 3. Photo uploaded first, then report synced
 * 4. Status updated: pending → syncing → synced
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
  const [syncManager, setSyncManager] = useState(null);
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    const checkBridge = () => {
      if (window.ActionQueue && window.SyncManager) {
        setBridgeReady(true);
        initializeSyncManager();
        loadActions();
      } else {
        setTimeout(checkBridge, 100);
      }
    };
    checkBridge();
  }, []);

  const initializeSyncManager = async () => {
    try {
      const manager = new window.SyncManager(MODULE_ID, {
        maxRetries: 3,
        retryDelay: 1000,
        onProgress: (progress) => {
          console.log('[Report Submission] Sync progress:', progress);
        },
        onComplete: (results) => {
          console.log('[Report Submission] Sync complete:', results);
          setSyncing(false);
          loadActions();
          if (onUpdate) onUpdate();
        },
        onError: (error) => {
          console.error('[Report Submission] Sync error:', error);
          setSyncing(false);
        }
      });

      await manager.initialize();
      setSyncManager(manager);
      console.log('[Report Submission] SyncManager initialized');

      // Auto-sync on startup if there are pending actions
      setTimeout(() => {
        triggerSync(manager);
      }, 2000);
    } catch (err) {
      console.error('[Report Submission] Failed to initialize SyncManager:', err);
    }
  };

  const triggerSync = async (manager = syncManager) => {
    if (!manager || syncing) return;

    try {
      setSyncing(true);
      console.log('[Report Submission] Triggering auto-sync...');
      await manager.syncAll();
    } catch (err) {
      console.error('[Report Submission] Sync failed:', err);
      setSyncing(false);
    }
  };

  const loadActions = async () => {
    if (!window.ActionQueue) return;

    try {
      const allActions = await window.ActionQueue.getAll(MODULE_ID);
      setActions(allActions.sort((a, b) => b.created_at - a.created_at));
      console.log('[Report Submission] Loaded actions from SQLite:', allActions.length);
    } catch (err) {
      console.error('[Report Submission] Failed to load actions:', err);
      setError('Failed to load actions from ActionQueue');
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
        console.log('[Report Submission] Base64 preview length:', photoData.thumbnailPath?.length || 0);

        setCapturedPhoto({
          filePath: photoData.filePath,        // file:// path for upload
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

    if (!window.ActionQueue) {
      setError('ActionQueue bridge not available');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const payload = {
        report_type: reportType,
        summary: summary.trim(),
        details: details.trim(),
        priority,
        submitted_at: new Date().toISOString()
      };

      // Include photo if captured
      if (capturedPhoto && capturedPhoto.filePath) {
        payload.photoPath = capturedPhoto.filePath; // file:// path - will be uploaded when synced
        payload.hasPhoto = true;
        console.log('[Report Submission] Including photo in payload:', capturedPhoto.filePath);
      }

      const actionId = await window.ActionQueue.save(
        MODULE_ID,
        'submit_report',
        payload,
        { immediate: false }
      );

      console.log('[Report Submission] Action saved to SQLite:', actionId);

      // Clear form
      setSummary('');
      setDetails('');
      setReportType('daily');
      setPriority('normal');
      setCapturedPhoto(null); // Clear photo

      // Reload actions
      await loadActions();

      if (onUpdate) onUpdate();

      // Trigger auto-sync after saving (if online)
      console.log('[Report Submission] Action saved, triggering auto-sync...');
      setTimeout(() => {
        triggerSync();
      }, 500);
    } catch (err) {
      console.error('[Report Submission] Failed to save action:', err);
      setError('Failed to save report to ActionQueue');
    } finally {
      setLoading(false);
    }
  };

  const handleMarkSynced = async (actionId) => {
    try {
      await window.ActionQueue.markSynced(actionId);
      console.log('[Report Submission] Action marked as synced:', actionId);
      await loadActions();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('[Report Submission] Failed to mark synced:', err);
      setError('Failed to mark action as synced');
    }
  };

  const handleMarkError = async (actionId) => {
    try {
      await window.ActionQueue.markError(actionId, 'Simulated network error');
      console.log('[Report Submission] Action marked as error:', actionId);
      await loadActions();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('[Report Submission] Failed to mark error:', err);
      setError('Failed to mark action as error');
    }
  };

  const handleDelete = async (actionId) => {
    if (!window.confirm('Delete this action? This cannot be undone.')) return;

    try {
      await window.ActionQueue.delete(actionId);
      console.log('[Report Submission] Action deleted:', actionId);
      await loadActions();
      if (onUpdate) onUpdate();
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
      case 'error': return '#ef5350';
      default: return '#999';
    }
  };

  if (!bridgeReady) {
    return (
      <div style={{ padding: '20px', textAlign: 'center', color: '#999' }}>
        Waiting for ActionQueue bridge...
      </div>
    );
  }

  return (
    <div>
      <h2 style={{ color: '#1976d2', marginTop: 0 }}>Report Submission</h2>
      <p style={{ color: '#666', fontSize: '14px' }}>
        SQLite ActionQueue (source of truth) - {actions.length} action(s) queued
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
                    Will be uploaded when report is synced
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
        <h3 style={{ margin: 0, fontSize: '16px' }}>Action Queue ({actions.length})</h3>
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
            const payload = typeof action.payload === 'string'
              ? JSON.parse(action.payload)
              : action.payload;

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
                      <strong>📸 Photo:</strong> {payload.photoPath?.startsWith('http') ? 'Uploaded ✅' : 'Pending upload'}
                    </div>
                  )}
                </div>

                <div style={{ fontSize: '12px', color: '#999', marginTop: '8px' }}>
                  <div>ID: {action.id}</div>
                  <div>Created: {new Date(action.created_at).toLocaleString()}</div>
                  {action.error_message && (
                    <div style={{ color: '#ef5350' }}>Error: {action.error_message}</div>
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
        background: '#fff3e0',
        borderLeft: '4px solid #ff9800',
        fontSize: '13px',
        color: '#e65100'
      }}>
        <strong>Critical Data:</strong> All reports are saved to SQLite ActionQueue.
        This data survives app restarts and is the source of truth for sync operations.
      </div>
    </div>
  );
}

export default Feature3_ReportSubmission;

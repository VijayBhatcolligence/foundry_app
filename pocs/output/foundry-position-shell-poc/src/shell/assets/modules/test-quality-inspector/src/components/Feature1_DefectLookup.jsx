import React, { useState } from 'react';

/**
 * Feature 1: Defect Lookup (Online Only)
 *
 * 🎯 WHAT THIS PROVES:
 * ✅ Direct backend API calls from React
 * ✅ No local storage (IndexedDB or SQLite)
 * ✅ Fresh data on every request
 * ✅ Requires active internet connection
 *
 * SCENARIO:
 * 1. User searches for defect code (e.g., "D001")
 * 2. React calls backend directly: GET /api/defects/:code
 * 3. Backend returns defect details
 * 4. No caching - same search = new API call
 * 5. Offline = Error (demonstrates online-only strategy)
 */

const API_BASE = 'http://localhost:3000/api';

function Feature1_DefectLookup() {
  const [defectCode, setDefectCode] = useState('');
  const [defectInfo, setDefectInfo] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleLookup = async () => {
    if (!defectCode.trim()) {
      setError('Please enter a defect code');
      return;
    }

    setLoading(true);
    setError(null);
    setDefectInfo(null);

    try {
      const response = await fetch(`${API_BASE}/defects/${encodeURIComponent(defectCode)}`);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();

      if (data.error) {
        setError(data.error);
      } else {
        setDefectInfo(data);
      }
    } catch (err) {
      console.error('[Defect Lookup] Error:', err);
      setError(err.message || 'Failed to lookup defect code');
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      handleLookup();
    }
  };

  return (
    <div>
      <h2 style={{ color: '#1976d2', marginTop: 0 }}>Defect Code Lookup</h2>
      <p style={{ color: '#666', fontSize: '14px' }}>
        Online-only feature - requires network connection. No local storage.
      </p>

      <div style={{ marginTop: '20px' }}>
        <div style={{ display: 'flex', gap: '10px', marginBottom: '15px' }}>
          <input
            type="text"
            value={defectCode}
            onChange={(e) => setDefectCode(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Enter defect code (e.g., D001, D002)"
            style={{
              flex: 1,
              padding: '10px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '14px'
            }}
            disabled={loading}
          />
          <button
            onClick={handleLookup}
            disabled={loading}
            style={{
              padding: '10px 20px',
              background: loading ? '#ccc' : '#1976d2',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: loading ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: 'bold'
            }}
          >
            {loading ? 'Looking up...' : 'Lookup'}
          </button>
        </div>

        {error && (
          <div style={{
            padding: '15px',
            background: '#ffebee',
            border: '1px solid #ef5350',
            borderRadius: '4px',
            color: '#c62828',
            marginBottom: '15px'
          }}>
            <strong>Error:</strong> {error}
          </div>
        )}

        {defectInfo && (
          <div style={{
            padding: '20px',
            background: '#e3f2fd',
            border: '1px solid #2196f3',
            borderRadius: '4px',
            marginBottom: '15px'
          }}>
            <h3 style={{ margin: '0 0 15px 0', color: '#1565c0' }}>Defect Information</h3>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <tbody>
                <tr>
                  <td style={{ padding: '8px', fontWeight: 'bold', width: '150px' }}>Code:</td>
                  <td style={{ padding: '8px' }}>{defectInfo.code}</td>
                </tr>
                <tr>
                  <td style={{ padding: '8px', fontWeight: 'bold' }}>Description:</td>
                  <td style={{ padding: '8px' }}>{defectInfo.description}</td>
                </tr>
                <tr>
                  <td style={{ padding: '8px', fontWeight: 'bold' }}>Severity:</td>
                  <td style={{ padding: '8px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: defectInfo.severity === 'critical' ? '#ef5350' :
                                 defectInfo.severity === 'major' ? '#ff9800' :
                                 defectInfo.severity === 'minor' ? '#ffc107' : '#4caf50',
                      color: 'white',
                      fontSize: '12px',
                      fontWeight: 'bold'
                    }}>
                      {defectInfo.severity?.toUpperCase()}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td style={{ padding: '8px', fontWeight: 'bold' }}>Category:</td>
                  <td style={{ padding: '8px' }}>{defectInfo.category}</td>
                </tr>
              </tbody>
            </table>
          </div>
        )}

        <div style={{
          marginTop: '20px',
          padding: '15px',
          background: '#fff3e0',
          borderLeft: '4px solid #ff9800',
          fontSize: '13px',
          color: '#e65100'
        }}>
          <strong>Note:</strong> This feature requires an active network connection.
          Try looking up codes: D001, D002, D003, or D004
        </div>
      </div>
    </div>
  );
}

export default Feature1_DefectLookup;

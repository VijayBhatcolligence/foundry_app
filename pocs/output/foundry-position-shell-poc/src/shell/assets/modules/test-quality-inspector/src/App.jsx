import React, { useState, useEffect } from 'react';

// Import feature components
import Feature1_DefectLookup from './components/Feature1_DefectLookup';
import Feature2_InspectionLog from './components/Feature2_InspectionLog';
import Feature3_ReportSubmission from './components/Feature3_ReportSubmission';

const MODULE_ID = 'test-quality-inspector';

function App() {
  const [activeTab, setActiveTab] = useState('feature1');
  const [bridgeReady, setBridgeReady] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);

  useEffect(() => {
    // Check if bridge is available (NEW: check for shellBridge instead of ActionQueue)
    const checkBridge = () => {
      if (window.shellBridge) {
        console.log('[Quality Inspector] ✅ Bridge ready (NEW IndexedDB architecture)');
        setBridgeReady(true);
      } else {
        console.warn('[Quality Inspector] Bridge not available yet');
        setTimeout(checkBridge, 100);
      }
    };

    checkBridge();

    // NOTE: Pending count is now managed by Feature3_ReportSubmission component itself
    // No need to poll from here - component tracks its own IndexedDB state
  }, []);

  // Callback from Feature3 when actions update
  const handleActionsUpdate = (count) => {
    setPendingCount(count);
  };

  const renderActiveFeature = () => {
    switch (activeTab) {
      case 'feature1':
        return <Feature1_DefectLookup />;
      case 'feature2':
        return <Feature2_InspectionLog />;
      case 'feature3':
        return <Feature3_ReportSubmission onUpdate={handleActionsUpdate} />;
      default:
        return null;
    }
  };

  return (
    <div style={{ padding: '20px', maxWidth: '800px', margin: '0 auto' }}>
      <div style={{ marginBottom: '20px', borderBottom: '2px solid #e0e0e0', paddingBottom: '10px' }}>
        <h1 style={{ margin: '0 0 10px 0', color: '#1976d2' }}>Quality Inspector Module</h1>
        <p style={{ margin: '0', color: '#666', fontSize: '14px' }}>
          Module ID: {MODULE_ID} | Bridge: {bridgeReady ? '✓ Ready' : '✗ Not Ready'} | Pending Actions: {pendingCount}
        </p>
      </div>

      {/* Tab Navigation */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px', borderBottom: '1px solid #e0e0e0' }}>
        <button
          onClick={() => setActiveTab('feature1')}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'feature1' ? '#1976d2' : 'transparent',
            color: activeTab === 'feature1' ? 'white' : '#666',
            cursor: 'pointer',
            borderRadius: '4px 4px 0 0',
            fontWeight: activeTab === 'feature1' ? 'bold' : 'normal'
          }}
        >
          Feature 1: Defect Lookup
        </button>
        <button
          onClick={() => setActiveTab('feature2')}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'feature2' ? '#1976d2' : 'transparent',
            color: activeTab === 'feature2' ? 'white' : '#666',
            cursor: 'pointer',
            borderRadius: '4px 4px 0 0',
            fontWeight: activeTab === 'feature2' ? 'bold' : 'normal'
          }}
        >
          Feature 2: Inspection Log
        </button>
        <button
          onClick={() => setActiveTab('feature3')}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'feature3' ? '#1976d2' : 'transparent',
            color: activeTab === 'feature3' ? 'white' : '#666',
            cursor: 'pointer',
            borderRadius: '4px 4px 0 0',
            fontWeight: activeTab === 'feature3' ? 'bold' : 'normal'
          }}
        >
          Feature 3: Report Submission
        </button>
      </div>

      {/* Active Feature Content */}
      <div style={{ minHeight: '400px' }}>
        {renderActiveFeature()}
      </div>

      {/* Module Info Footer */}
      <div style={{ marginTop: '30px', padding: '15px', background: '#e3f2fd', borderRadius: '4px', fontSize: '12px' }}>
        <strong>✨ NEW Architecture - Module Testing Notes:</strong>
        <ul style={{ margin: '10px 0', paddingLeft: '20px' }}>
          <li>Feature 1 (Defect Lookup): Online-only, no local storage</li>
          <li>Feature 2 (Inspection Log): IndexedDB cache (quality_inspector_db)</li>
          <li>Feature 3 (Report Submission): <strong>IndexedDB ActionQueue</strong> (actions) + <strong>Flutter file system</strong> (photos)</li>
        </ul>
      </div>
    </div>
  );
}

export default App;

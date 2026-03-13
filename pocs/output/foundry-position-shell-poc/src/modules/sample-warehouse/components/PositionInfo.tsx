import React from 'react';

interface RoleContext {
  department: string;
  location: string;
  permissions: string[];
  warehouseZone?: string;
  shiftSchedule?: string;
  supervisor?: string;
  [key: string]: any;
}

interface PositionContext {
  orgId: string;
  positionId: string;
  positionName: string;
  roleContext: RoleContext;
}

interface ScopedSession {
  sessionId: string;
  positionId: string;
  orgId: string;
  roleContext: RoleContext;
  expiresAt: string;
}

interface PositionInfoProps {
  positionContext: PositionContext;
  scopedSession: ScopedSession;
}

/**
 * PositionInfo Component
 *
 * Displays position context and demonstrates that the module
 * has access to scoped session (but NOT shell token)
 */
const PositionInfo: React.FC<PositionInfoProps> = ({
  positionContext,
  scopedSession,
}) => {
  const { roleContext } = positionContext;

  return (
    <div style={{ display: 'grid', gap: '24px', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))' }}>
      {/* Position Details Card */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '24px',
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
      }}>
        <h2 style={{ margin: '0 0 16px 0', fontSize: '18px', color: '#1976d2' }}>
          Position Details
        </h2>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <InfoRow label="Organization" value={positionContext.orgId} />
          <InfoRow label="Position ID" value={positionContext.positionId} />
          <InfoRow label="Department" value={roleContext.department} />
          <InfoRow label="Location" value={roleContext.location} />
          {roleContext.warehouseZone && (
            <InfoRow label="Warehouse Zone" value={roleContext.warehouseZone} />
          )}
          {roleContext.shiftSchedule && (
            <InfoRow label="Shift" value={roleContext.shiftSchedule} />
          )}
          {roleContext.supervisor && (
            <InfoRow label="Supervisor" value={roleContext.supervisor} />
          )}
        </div>
      </div>

      {/* Permissions Card */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '24px',
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
      }}>
        <h2 style={{ margin: '0 0 16px 0', fontSize: '18px', color: '#1976d2' }}>
          Permissions
        </h2>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {roleContext.permissions.map((permission, index) => (
            <div
              key={index}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '8px 12px',
                background: '#f5f5f5',
                borderRadius: '4px',
              }}
            >
              <span style={{ color: '#4caf50', fontWeight: 'bold' }}>✓</span>
              <code style={{ fontSize: '13px', fontFamily: 'monospace' }}>
                {permission}
              </code>
            </div>
          ))}
        </div>
      </div>

      {/* Session Information Card */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '24px',
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
      }}>
        <h2 style={{ margin: '0 0 16px 0', fontSize: '18px', color: '#1976d2' }}>
          Scoped Session
        </h2>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <InfoRow
            label="Session ID"
            value={scopedSession.sessionId.substring(0, 24) + '...'}
            monospace
          />
          <InfoRow
            label="Session Scope"
            value={`Position: ${scopedSession.positionId}`}
          />
          <InfoRow
            label="Expires"
            value={new Date(scopedSession.expiresAt).toLocaleString()}
          />
        </div>

        <div style={{
          marginTop: '16px',
          padding: '12px',
          background: '#e8f5e9',
          borderRadius: '4px',
          border: '1px solid #4caf50',
        }}>
          <div style={{ fontSize: '12px', color: '#2e7d32', fontWeight: 500 }}>
            Scoped Session Active
          </div>
          <div style={{ fontSize: '11px', color: '#666', marginTop: '4px' }}>
            This module has access to position-scoped session only.
            Shell token is not accessible from web layer.
          </div>
        </div>
      </div>

      {/* Role Context Raw Data (Developer View) */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '24px',
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        gridColumn: '1 / -1',
      }}>
        <h2 style={{ margin: '0 0 16px 0', fontSize: '18px', color: '#1976d2' }}>
          Role Context (Developer View)
        </h2>

        <pre style={{
          background: '#f5f5f5',
          padding: '16px',
          borderRadius: '4px',
          overflow: 'auto',
          fontSize: '12px',
          lineHeight: '1.5',
          margin: 0,
        }}>
          {JSON.stringify(roleContext, null, 2)}
        </pre>
      </div>
    </div>
  );
};

/**
 * Info row component for key-value display
 */
const InfoRow: React.FC<{
  label: string;
  value: string;
  monospace?: boolean;
}> = ({ label, value, monospace = false }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
    <div style={{ fontSize: '12px', fontWeight: 600, color: '#666', textTransform: 'uppercase' }}>
      {label}
    </div>
    <div style={{
      fontSize: '14px',
      color: '#333',
      fontFamily: monospace ? 'monospace' : 'inherit',
      wordBreak: 'break-word',
    }}>
      {value}
    </div>
  </div>
);

export default PositionInfo;

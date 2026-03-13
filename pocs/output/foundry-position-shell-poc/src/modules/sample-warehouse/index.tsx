import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import PositionInfo from './components/PositionInfo';

/**
 * Sample Warehouse Module
 *
 * Demonstrates position module integration with runtime host:
 * 1. Receives position context and scoped session
 * 2. Accesses runtime API for session validation
 * 3. Renders position-specific UI
 * 4. Cleans up on unmount
 *
 * SECURITY: Module has access to scoped session only (never shell token)
 */

interface PositionContext {
  orgId: string;
  positionId: string;
  positionName: string;
  roleContext: Record<string, any>;
}

interface ScopedSession {
  sessionId: string;
  positionId: string;
  orgId: string;
  roleContext: Record<string, any>;
  expiresAt: string;
}

interface RuntimeAPI {
  getSession: () => ScopedSession;
  getPositionContext: () => PositionContext;
  validateSession: () => Promise<boolean>;
  log: (level: 'info' | 'warn' | 'error', message: string, data?: any) => void;
  requestUnmount: () => Promise<void>;
}

interface ModuleInitParams {
  positionContext: PositionContext;
  scopedSession: ScopedSession;
  runtimeAPI: RuntimeAPI;
}

// Module state
let moduleRoot: any = null;
let moduleAPI: RuntimeAPI | null = null;

/**
 * Main module component
 */
const WarehouseModule: React.FC<{
  positionContext: PositionContext;
  scopedSession: ScopedSession;
  runtimeAPI: RuntimeAPI;
}> = ({ positionContext, scopedSession, runtimeAPI }) => {
  const [sessionValid, setSessionValid] = useState<boolean>(true);
  const [lastValidation, setLastValidation] = useState<Date>(new Date());

  useEffect(() => {
    runtimeAPI.log('info', 'Warehouse module mounted');

    // Periodic session validation (every 30 seconds)
    const validationInterval = setInterval(async () => {
      const isValid = await runtimeAPI.validateSession();
      setSessionValid(isValid);
      setLastValidation(new Date());

      if (!isValid) {
        runtimeAPI.log('warn', 'Session validation failed - session may be expired');
      }
    }, 30000);

    return () => {
      clearInterval(validationInterval);
      runtimeAPI.log('info', 'Warehouse module unmounting');
    };
  }, [runtimeAPI]);

  const handleUnmount = async () => {
    await runtimeAPI.requestUnmount();
  };

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <header style={{
        background: 'linear-gradient(135deg, #1976d2 0%, #1565c0 100%)',
        color: 'white',
        padding: '24px',
        borderRadius: '8px',
        marginBottom: '24px',
      }}>
        <h1 style={{ margin: 0, fontSize: '28px', fontWeight: 600 }}>
          {positionContext.positionName}
        </h1>
        <p style={{ margin: '8px 0 0 0', opacity: 0.9, fontSize: '14px' }}>
          {positionContext.roleContext.department} • {positionContext.roleContext.location}
        </p>
      </header>

      {/* Session Status */}
      <div style={{
        background: sessionValid ? '#e8f5e9' : '#ffebee',
        padding: '16px',
        borderRadius: '8px',
        marginBottom: '24px',
        border: `1px solid ${sessionValid ? '#4caf50' : '#f44336'}`,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <span style={{ fontSize: '20px' }}>
            {sessionValid ? '✓' : '✗'}
          </span>
          <div style={{ flex: 1 }}>
            <strong style={{ color: sessionValid ? '#2e7d32' : '#c62828' }}>
              {sessionValid ? 'Session Active' : 'Session Invalid'}
            </strong>
            <div style={{ fontSize: '12px', marginTop: '4px', opacity: 0.8 }}>
              Last validated: {lastValidation.toLocaleTimeString()}
            </div>
          </div>
        </div>
      </div>

      {/* Position Information */}
      <PositionInfo
        positionContext={positionContext}
        scopedSession={scopedSession}
      />

      {/* Module Actions */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '24px',
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        marginTop: '24px',
      }}>
        <h2 style={{ marginTop: 0, fontSize: '18px', marginBottom: '16px' }}>
          Module Actions
        </h2>

        <div style={{ display: 'flex', gap: '12px' }}>
          <button
            onClick={handleUnmount}
            style={{
              padding: '12px 24px',
              background: '#f44336',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontWeight: 500,
            }}
          >
            Unmount Module
          </button>

          <button
            onClick={async () => {
              const isValid = await runtimeAPI.validateSession();
              setSessionValid(isValid);
              setLastValidation(new Date());
            }}
            style={{
              padding: '12px 24px',
              background: '#1976d2',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontWeight: 500,
            }}
          >
            Validate Session Now
          </button>
        </div>
      </div>

      {/* Security Notice */}
      <div style={{
        background: '#fff3e0',
        border: '1px solid #ff9800',
        borderRadius: '8px',
        padding: '16px',
        marginTop: '24px',
      }}>
        <strong style={{ color: '#e65100' }}>Security Boundary Active</strong>
        <p style={{ margin: '8px 0 0 0', fontSize: '14px', color: '#666' }}>
          This module operates with a scoped session. Shell token is not accessible.
          All operations are limited to position permissions: {positionContext.roleContext.permissions?.join(', ')}
        </p>
      </div>
    </div>
  );
};

/**
 * Module initialization function
 * Called by runtime host when module is mounted
 */
export async function init(params: ModuleInitParams): Promise<void> {
  const { positionContext, scopedSession, runtimeAPI } = params;

  runtimeAPI.log('info', 'Initializing warehouse module', {
    positionId: positionContext.positionId,
    sessionId: scopedSession.sessionId,
  });

  moduleAPI = runtimeAPI;

  // Validate we have scoped session (not shell token)
  if (!scopedSession.sessionId || scopedSession.sessionId.includes('shell')) {
    throw new Error('Security violation: Invalid session type');
  }

  // Module-specific initialization logic would go here
  await new Promise(resolve => setTimeout(resolve, 100));

  runtimeAPI.log('info', 'Warehouse module initialized successfully');
}

/**
 * Module cleanup function
 * Called before module unmount
 */
export async function cleanup(): Promise<void> {
  if (moduleAPI) {
    moduleAPI.log('info', 'Cleaning up warehouse module');
  }

  // Cleanup module-specific resources
  if (moduleRoot) {
    moduleRoot.unmount();
    moduleRoot = null;
  }

  moduleAPI = null;
}

/**
 * Render module into container
 */
export function render(
  container: HTMLElement,
  positionContext: PositionContext,
  scopedSession: ScopedSession,
  runtimeAPI: RuntimeAPI
): void {
  if (!container) {
    throw new Error('Container element required');
  }

  moduleRoot = createRoot(container);
  moduleRoot.render(
    <WarehouseModule
      positionContext={positionContext}
      scopedSession={scopedSession}
      runtimeAPI={runtimeAPI}
    />
  );
}

// Export module interface
export default {
  init,
  cleanup,
  render,
};

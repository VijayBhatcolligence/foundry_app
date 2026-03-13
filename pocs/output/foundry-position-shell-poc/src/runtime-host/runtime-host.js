/**
 * Foundry Runtime Host
 *
 * CRITICAL RESPONSIBILITIES:
 * 1. Bootstrap redemption (convert one-time code to scoped session)
 * 2. Module lifecycle management (mount/unmount)
 * 3. Bridge adapter (JavaScript <-> Flutter channel)
 * 4. Security boundary enforcement (no shell token access)
 *
 * SECURITY BOUNDARIES:
 * - Never attempts to access shell token
 * - Only handles scoped sessions
 * - Validates all bridge responses
 * - Enforces CSP via HTML meta tag
 */

class RuntimeHost {
  constructor() {
    this.bridge = null;
    this.session = null;
    this.positionContext = null;
    this.moduleStatus = 'unloaded';
    this.currentModule = null;
    this.eventHandlers = [];

    this._initializeBridge();
  }

  /**
   * Initializes Flutter bridge adapter
   * SECURITY: Bridge methods never expose shell token
   */
  _initializeBridge() {
    // Check if running in Flutter WebView (has method channel)
    if (window.shellBridge) {
      this.bridge = window.shellBridge;
      this._log('info', 'Flutter bridge detected');
    } else {
      // Mock bridge for browser testing
      this.bridge = this._createMockBridge();
      this._log('warn', 'Using mock bridge (not in Flutter WebView)');
    }
  }

  /**
   * Creates mock bridge for browser development/testing
   */
  _createMockBridge() {
    return {
      postMessage: async (method, args) => {
        this._log('info', `Mock bridge call: ${method}`, args);

        // Simulate bridge responses for testing
        switch (method) {
          case 'getBootstrapCode':
            return {
              success: true,
              data: {
                bootstrapCode: 'mock_bootstrap_' + Date.now(),
                expiresAt: new Date(Date.now() + 60000).toISOString(),
                positionId: 'WAREHOUSE-CLERK-01',
              },
            };

          case 'redeemBootstrap':
            return {
              success: true,
              data: {
                sessionId: 'mock_session_' + Date.now(),
                positionId: 'WAREHOUSE-CLERK-01',
                orgId: 'ORG001',
                roleContext: {
                  department: 'Warehouse Operations',
                  location: 'Building A - Zone 3',
                  permissions: ['inventory.view', 'inventory.count'],
                  warehouseZone: 'ZONE-A3',
                },
                expiresAt: new Date(Date.now() + 8 * 3600000).toISOString(),
              },
            };

          case 'validateSession':
            return {
              success: true,
              data: {
                valid: true,
                session: this.session,
              },
            };

          case 'getPositionContext':
            return {
              success: true,
              data: {
                position: {
                  orgId: 'ORG001',
                  positionId: 'WAREHOUSE-CLERK-01',
                  positionName: 'Warehouse Clerk',
                  roleContext: {
                    department: 'Warehouse Operations',
                    location: 'Building A - Zone 3',
                    permissions: ['inventory.view', 'inventory.count'],
                  },
                },
              },
            };

          default:
            return { success: true, data: {} };
        }
      },
    };
  }

  /**
   * Initializes runtime host with bootstrap redemption
   * CRITICAL: This is where bootstrap code becomes scoped session
   */
  async initialize() {
    try {
      this._updateStatus('Runtime Host: Bootstrapping...');
      this._log('info', 'Starting runtime initialization');

      // Step 1: Get bootstrap code from shell
      const bootstrapResult = await this._callBridge('getBootstrapCode', {});
      if (!bootstrapResult.success) {
        throw new Error('Failed to get bootstrap code: ' + bootstrapResult.error);
      }

      const { bootstrapCode, positionId } = bootstrapResult.data;
      this._log('info', 'Bootstrap code received', { positionId });

      // Step 2: Redeem bootstrap for scoped session
      // SECURITY: Bootstrap is one-time-use, creates position-scoped session
      const sessionResult = await this._callBridge('redeemBootstrap', {
        bootstrapCode,
      });

      if (!sessionResult.success) {
        throw new Error('Bootstrap redemption failed: ' + sessionResult.error);
      }

      this.session = sessionResult.data;
      this._log('info', 'Scoped session created', {
        sessionId: this.session.sessionId,
        positionId: this.session.positionId,
      });

      this._emitEvent({ type: 'bootstrap_redeemed', session: this.session });

      // Step 3: Get position context
      const contextResult = await this._callBridge('getPositionContext', {});
      if (contextResult.success) {
        this.positionContext = contextResult.data.position;
      }

      // Step 4: Mark runtime as ready
      this._updateStatus(`Runtime Host: Ready (Position: ${this.session.positionId})`);
      this._emitEvent({ type: 'runtime_ready' });

      this._log('info', 'Runtime host initialized successfully');

      // Hide loading overlay
      const loadingOverlay = document.getElementById('loading-overlay');
      if (loadingOverlay) {
        loadingOverlay.style.display = 'none';
      }

      return true;
    } catch (error) {
      this._log('error', 'Runtime initialization failed', error);
      this._showError('Failed to initialize runtime: ' + error.message);
      return false;
    }
  }

  /**
   * Mounts position module
   * @param {Object} moduleConfig - Module configuration
   */
  async mountModule(moduleConfig) {
    try {
      this.moduleStatus = 'loading';
      this._emitEvent({ type: 'module_loading', moduleId: moduleConfig.moduleId });
      this._log('info', 'Mounting module', moduleConfig);

      // In production, this would dynamically load module JavaScript
      // For Phase 1, we'll directly mount the sample module
      const container = document.getElementById('module-container');
      if (!container) {
        throw new Error('Module container not found');
      }

      // Clear container
      container.innerHTML = '';

      // Create runtime API for module
      const runtimeAPI = this._createRuntimeAPI();

      // Import and initialize module (in production this would be dynamic)
      // For Phase 1, we simulate module mounting
      this.moduleStatus = 'initializing';

      // Simulate module initialization
      await new Promise(resolve => setTimeout(resolve, 500));

      // Render module placeholder (actual React component would render here)
      this._renderModulePlaceholder(container);

      this.moduleStatus = 'mounted';
      this.currentModule = moduleConfig;
      this._emitEvent({ type: 'module_mounted', moduleId: moduleConfig.moduleId });

      this._log('info', 'Module mounted successfully', { moduleId: moduleConfig.moduleId });

      return true;
    } catch (error) {
      this.moduleStatus = 'error';
      this._emitEvent({
        type: 'module_error',
        moduleId: moduleConfig.moduleId,
        error: error.message,
      });
      this._log('error', 'Module mount failed', error);
      throw error;
    }
  }

  /**
   * Unmounts current module
   */
  async unmountModule() {
    if (!this.currentModule) {
      this._log('warn', 'No module to unmount');
      return;
    }

    try {
      this.moduleStatus = 'unmounting';
      this._log('info', 'Unmounting module', { moduleId: this.currentModule.moduleId });

      // Call bridge to revoke session
      await this._callBridge('unmountModule', {
        sessionId: this.session?.sessionId,
      });

      // Clear module container
      const container = document.getElementById('module-container');
      if (container) {
        container.innerHTML = '';
      }

      const moduleId = this.currentModule.moduleId;
      this.currentModule = null;
      this.moduleStatus = 'unloaded';

      this._emitEvent({ type: 'module_unmounted', moduleId });
      this._log('info', 'Module unmounted successfully');
    } catch (error) {
      this._log('error', 'Module unmount failed', error);
      throw error;
    }
  }

  /**
   * Creates Runtime API exposed to modules
   * SECURITY: Only exposes scoped session, never shell token
   */
  _createRuntimeAPI() {
    return {
      getSession: () => {
        return this.session;
      },

      getPositionContext: () => {
        return this.positionContext;
      },

      validateSession: async () => {
        const result = await this._callBridge('validateSession', {
          sessionId: this.session?.sessionId,
        });
        return result.success && result.data.valid;
      },

      log: (level, message, data) => {
        this._log(level, `[Module] ${message}`, data);
      },

      requestUnmount: async () => {
        await this.unmountModule();
      },
    };
  }

  /**
   * Renders module placeholder (for Phase 1 demonstration)
   * In production, actual React module would render here
   */
  _renderModulePlaceholder(container) {
    container.innerHTML = `
      <div style="padding: 24px;">
        <div style="background: white; border-radius: 8px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
          <h2 style="margin-bottom: 16px; color: #1976d2;">
            ${this.positionContext?.positionName || 'Position Module'}
          </h2>

          <div style="margin-bottom: 24px;">
            <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 8px; color: #666;">
              Position Context
            </h3>
            <div style="background: #f5f5f5; padding: 12px; border-radius: 4px; font-family: monospace; font-size: 12px;">
              <div><strong>Org ID:</strong> ${this.positionContext?.orgId}</div>
              <div><strong>Position ID:</strong> ${this.positionContext?.positionId}</div>
              <div><strong>Department:</strong> ${this.positionContext?.roleContext?.department}</div>
              <div><strong>Location:</strong> ${this.positionContext?.roleContext?.location}</div>
            </div>
          </div>

          <div style="margin-bottom: 24px;">
            <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 8px; color: #666;">
              Scoped Session (Active)
            </h3>
            <div style="background: #e8f5e9; padding: 12px; border-radius: 4px; font-family: monospace; font-size: 12px;">
              <div><strong>Session ID:</strong> ${this.session?.sessionId?.substring(0, 16)}...</div>
              <div><strong>Expires:</strong> ${new Date(this.session?.expiresAt).toLocaleString()}</div>
              <div style="color: #2e7d32; margin-top: 8px;">
                ✓ Scoped session active (shell token not accessible)
              </div>
            </div>
          </div>

          <div>
            <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 8px; color: #666;">
              Permissions
            </h3>
            <div style="display: flex; flex-wrap: wrap; gap: 8px;">
              ${this.positionContext?.roleContext?.permissions?.map(perm =>
                `<span style="background: #1976d2; color: white; padding: 4px 12px; border-radius: 12px; font-size: 12px;">${perm}</span>`
              ).join('') || ''}
            </div>
          </div>
        </div>
      </div>
    `;
  }

  /**
   * Calls Flutter bridge method
   */
  async _callBridge(method, args) {
    try {
      return await this.bridge.postMessage(method, args);
    } catch (error) {
      this._log('error', `Bridge call failed: ${method}`, error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Updates status display
   */
  _updateStatus(message) {
    const statusEl = document.getElementById('runtime-status');
    if (statusEl) {
      statusEl.textContent = message;
    }
  }

  /**
   * Shows error message
   */
  _showError(message) {
    const container = document.getElementById('module-container');
    if (container) {
      container.innerHTML = `
        <div class="error-container">
          <div class="error-message">${message}</div>
        </div>
      `;
    }
    this._updateStatus('Runtime Host: Error');
  }

  /**
   * Logging utility
   */
  _log(level, message, data) {
    const logMessage = `[RuntimeHost] ${message}`;
    if (data) {
      console[level](logMessage, data);
    } else {
      console[level](logMessage);
    }
  }

  /**
   * Event emission
   */
  _emitEvent(event) {
    this.eventHandlers.forEach(handler => handler(event));
  }

  /**
   * Subscribe to runtime events
   */
  on(handler) {
    this.eventHandlers.push(handler);
  }

  /**
   * Get current module status
   */
  getModuleStatus() {
    return {
      status: this.moduleStatus,
      module: this.currentModule,
      session: this.session ? {
        sessionId: this.session.sessionId,
        positionId: this.session.positionId,
        expiresAt: this.session.expiresAt,
      } : null,
    };
  }
}

// Initialize runtime host on load
let runtimeHost;

document.addEventListener('DOMContentLoaded', async () => {
  console.log('[RuntimeHost] Initializing...');

  runtimeHost = new RuntimeHost();

  // Initialize and bootstrap
  const initialized = await runtimeHost.initialize();

  if (initialized) {
    // Auto-mount sample module for Phase 1 demonstration
    await runtimeHost.mountModule({
      moduleId: 'sample-warehouse',
      moduleName: 'Warehouse Operations',
      moduleUrl: '/modules/sample-warehouse/index.js',
      version: '1.0.0',
    });
  }
});

// Expose runtime host globally for Flutter bridge access
window.runtimeHost = runtimeHost;

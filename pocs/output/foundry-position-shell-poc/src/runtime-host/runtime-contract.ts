/**
 * Runtime contract - TypeScript interfaces for module communication
 *
 * This defines the contract between:
 * 1. Flutter shell <-> Runtime host (bridge API)
 * 2. Runtime host <-> Position modules (module API)
 */

// ============================================================================
// Position Context Types
// ============================================================================

export interface RoleContext {
  department: string;
  location: string;
  permissions: string[];
  [key: string]: any; // Position-specific metadata
}

export interface PositionContext {
  orgId: string;
  positionId: string;
  positionName: string;
  roleContext: RoleContext;
}

// ============================================================================
// Session Types
// ============================================================================

export interface ScopedSession {
  sessionId: string;
  positionId: string;
  orgId: string;
  roleContext: RoleContext;
  createdAt: string;
  expiresAt: string;
}

export interface BootstrapData {
  bootstrapCode: string;
  expiresAt: string;
  positionId: string;
}

// ============================================================================
// Bridge API (Flutter <-> Runtime Host)
// ============================================================================

export interface ShellBridge {
  /**
   * Gets bootstrap code for session initialization
   * SECURITY: Returns bootstrap code only (NOT shell token)
   */
  getBootstrapCode(): Promise<BootstrapData>;

  /**
   * Redeems bootstrap code for scoped session
   * SECURITY: One-time-use bootstrap, returns scoped session
   */
  redeemBootstrap(bootstrapCode: string): Promise<ScopedSession>;

  /**
   * Validates scoped session
   */
  validateSession(sessionId: string): Promise<SessionValidation>;

  /**
   * Revokes session (during unmount or position switch)
   */
  revokeSession(sessionId: string): Promise<void>;

  /**
   * Gets current position context
   */
  getPositionContext(): Promise<PositionContext>;

  /**
   * Unmounts current module
   */
  unmountModule(sessionId?: string): Promise<void>;
}

export interface SessionValidation {
  valid: boolean;
  session?: ScopedSession;
}

// ============================================================================
// Module Lifecycle Types
// ============================================================================

export type ModuleStatus =
  | 'unloaded'
  | 'loading'
  | 'initializing'
  | 'mounted'
  | 'error'
  | 'unmounting';

export interface ModuleConfig {
  moduleId: string;
  moduleName: string;
  moduleUrl: string;
  version: string;
}

export interface ModuleInitParams {
  positionContext: PositionContext;
  scopedSession: ScopedSession;
  runtimeAPI: RuntimeAPI;
}

// ============================================================================
// Runtime API (Runtime Host -> Position Modules)
// ============================================================================

export interface RuntimeAPI {
  /**
   * Gets current scoped session
   * SECURITY: Returns scoped session only (never shell token)
   */
  getSession(): ScopedSession;

  /**
   * Gets position context
   */
  getPositionContext(): PositionContext;

  /**
   * Validates current session is still active
   */
  validateSession(): Promise<boolean>;

  /**
   * Logs module activity (for debugging)
   */
  log(level: 'info' | 'warn' | 'error', message: string, data?: any): void;

  /**
   * Requests module unmount
   */
  requestUnmount(): Promise<void>;
}

// ============================================================================
// Position Module Interface
// ============================================================================

export interface PositionModule {
  /**
   * Module initialization
   * Called when module is mounted with position context and session
   */
  init(params: ModuleInitParams): Promise<void>;

  /**
   * Module cleanup
   * Called before module unmount
   */
  cleanup(): Promise<void>;

  /**
   * Render module into container
   */
  render(container: HTMLElement): void;
}

// ============================================================================
// Runtime Host Events
// ============================================================================

export type RuntimeEvent =
  | { type: 'runtime_ready' }
  | { type: 'bootstrap_redeemed'; session: ScopedSession }
  | { type: 'module_loading'; moduleId: string }
  | { type: 'module_mounted'; moduleId: string }
  | { type: 'module_error'; moduleId: string; error: string }
  | { type: 'module_unmounted'; moduleId: string }
  | { type: 'session_expired'; sessionId: string };

export type RuntimeEventHandler = (event: RuntimeEvent) => void;

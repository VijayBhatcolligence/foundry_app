// Replication Setup - Initialize and manage replication

let replicationStates = {};

/**
 * Setup replication for all collections
 */
async function setupReplication(rxDB) {
    console.log('[Replication] Setting up replication for all collections...');

    try {
        // Get handlers
        const pullHandlers = window.RxDBPullHandler.createAll();
        const pushHandlers = window.RxDBPushHandler.createAll();
        const conflictHandlers = window.RxDBConflictHandler.createAll(false); // Use simple LWW

        // Setup replication for each collection
        await setupCollectionReplication(rxDB.transactions, 'transactions', pullHandlers.transactions, pushHandlers.transactions, conflictHandlers.transactions);
        await setupCollectionReplication(rxDB.waterChecks, 'waterChecks', pullHandlers.waterChecks, pushHandlers.waterChecks, conflictHandlers.waterChecks);
        await setupCollectionReplication(rxDB.complaints, 'complaints', pullHandlers.complaints, pushHandlers.complaints, conflictHandlers.complaints);

        console.log('[Replication] ✅ Replication setup complete');

        // Start periodic sync
        startPeriodicSync();

        return replicationStates;

    } catch (error) {
        console.error('[Replication] ❌ Setup failed:', error);
        throw error;
    }
}

/**
 * Setup replication for a single collection
 */
async function setupCollectionReplication(collection, name, pullHandler, pushHandler, conflictHandler) {
    console.log(`[Replication] Setting up ${name}...`);

    try {
        const replicationState = collection.syncGraphQL({
            url: `${API_CONFIG.baseURL}/graphql`, // Not used, we use custom handlers
            pull: {
                queryBuilder: pullHandler,
                batchSize: REPLICATION_CONFIG.pull.batchSize || 100,
                modifier: (doc) => doc
            },
            push: {
                queryBuilder: pushHandler,
                batchSize: REPLICATION_CONFIG.push.batchSize || 50,
                modifier: (doc) => doc
            },
            live: REPLICATION_CONFIG.live,
            retryTime: REPLICATION_CONFIG.retryTime,
            autoStart: true,
            deletedFlag: 'deleted'
        });

        // Note: RxDB's replication uses GraphQL protocol by default
        // For REST API, we need to use a custom implementation
        // Using REST replication plugin instead:

        const restReplicationState = await collection.replicateREST({
            url: {
                pull: `${API_CONFIG.baseURL}${API_CONFIG.endpoints[name]}`,
                push: `${API_CONFIG.baseURL}${API_CONFIG.endpoints[name]}`
            },
            pull: {
                handler: pullHandler,
                batchSize: 100
            },
            push: {
                handler: pushHandler,
                batchSize: 50
            },
            live: true,
            retryTime: 5000,
            autoStart: true
        });

        // Handle replication events
        restReplicationState.error$.subscribe(error => {
            console.error(`[Replication:${name}] Error:`, error);
        });

        restReplicationState.active$.subscribe(active => {
            console.log(`[Replication:${name}] Active:`, active);
        });

        restReplicationState.complete$.subscribe(complete => {
            console.log(`[Replication:${name}] Complete:`, complete);
        });

        // Store replication state
        replicationStates[name] = restReplicationState;

        console.log(`[Replication] ✅ ${name} replication started`);

    } catch (error) {
        console.error(`[Replication] ❌ Failed to setup ${name}:`, error);
        throw error;
    }
}

/**
 * Start periodic sync (fallback to manual pull/push)
 * This ensures sync happens even if live replication has issues
 */
function startPeriodicSync() {
    const interval = REPLICATION_CONFIG.syncInterval || 60000; // 1 minute default

    console.log(`[Replication] Starting periodic sync (every ${interval / 1000}s)`);

    setInterval(async () => {
        // Check if online
        if (!navigator.onLine) {
            console.log('[Replication] Offline, skipping periodic sync');
            return;
        }

        console.log('[Replication] Periodic sync triggered');

        // Trigger sync for all replication states
        for (const [name, state] of Object.entries(replicationStates)) {
            try {
                if (state && state.run) {
                    await state.run();
                    console.log(`[Replication] ✅ ${name} synced`);
                }
            } catch (error) {
                console.error(`[Replication] ❌ ${name} sync failed:`, error);
            }
        }
    }, interval);
}

/**
 * Manual sync trigger
 */
async function triggerSync() {
    console.log('[Replication] Manual sync triggered');

    const results = {};

    for (const [name, state] of Object.entries(replicationStates)) {
        try {
            if (state && state.run) {
                await state.run();
                results[name] = { success: true };
                console.log(`[Replication] ✅ ${name} synced`);
            }
        } catch (error) {
            results[name] = { success: false, error: error.message };
            console.error(`[Replication] ❌ ${name} failed:`, error);
        }
    }

    return results;
}

/**
 * Stop replication
 */
async function stopReplication() {
    console.log('[Replication] Stopping replication...');

    for (const [name, state] of Object.entries(replicationStates)) {
        try {
            if (state && state.cancel) {
                await state.cancel();
                console.log(`[Replication] ✅ ${name} stopped`);
            }
        } catch (error) {
            console.error(`[Replication] ❌ Failed to stop ${name}:`, error);
        }
    }

    replicationStates = {};
    console.log('[Replication] All replication stopped');
}

/**
 * Get replication status
 */
function getReplicationStatus() {
    const status = {};

    for (const [name, state] of Object.entries(replicationStates)) {
        status[name] = {
            active: state.active,
            canceled: state.canceled,
            subjects: {
                active: state.active$?._value,
                complete: state.complete$?._value
            }
        };
    }

    return status;
}

// Export
if (typeof window !== 'undefined') {
    window.RxDBReplication = {
        setup: setupReplication,
        trigger: triggerSync,
        stop: stopReplication,
        getStatus: getReplicationStatus
    };
}

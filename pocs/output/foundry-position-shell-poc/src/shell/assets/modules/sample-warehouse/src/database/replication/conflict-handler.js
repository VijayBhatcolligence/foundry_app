// Conflict Handler - Resolve conflicts between local and remote changes

/**
 * Conflict Resolution Strategy: Last-Write-Wins (LWW)
 *
 * When the same document is modified both locally and on the server:
 * - Compare updatedAt timestamps
 * - Newer timestamp wins
 * - If timestamps are equal, server wins (assumed to be authoritative)
 */

function createConflictHandler(collectionName) {
    return (input) => {
        console.log(`[Conflict] Resolving conflict for ${collectionName}:`, input);

        const { assumedMasterState, newDocumentState, realMasterState } = input;

        // If no real master state, new document wins
        if (!realMasterState) {
            console.log('[Conflict] No master state, using new document');
            return newDocumentState;
        }

        // Compare timestamps
        const localTime = newDocumentState.updatedAt || newDocumentState.createdAt || 0;
        const remoteTime = realMasterState.updatedAt || realMasterState.createdAt || 0;

        console.log('[Conflict] Local time:', new Date(localTime).toISOString());
        console.log('[Conflict] Remote time:', new Date(remoteTime).toISOString());

        // Last-Write-Wins strategy
        if (localTime > remoteTime) {
            console.log('[Conflict] ✅ Local wins (newer)');
            return newDocumentState;
        } else if (remoteTime > localTime) {
            console.log('[Conflict] ✅ Remote wins (newer)');
            return realMasterState;
        } else {
            // Same timestamp - server wins by default
            console.log('[Conflict] ⚖️ Same timestamp - Remote wins (tie-breaker)');
            return realMasterState;
        }
    };
}

/**
 * Advanced conflict resolution (optional)
 * Merges non-conflicting fields
 */
function createSmartConflictHandler(collectionName) {
    return (input) => {
        console.log(`[Conflict:Smart] Resolving conflict for ${collectionName}`);

        const { assumedMasterState, newDocumentState, realMasterState } = input;

        if (!realMasterState) {
            return newDocumentState;
        }

        // Get timestamps
        const localTime = newDocumentState.updatedAt || newDocumentState.createdAt || 0;
        const remoteTime = realMasterState.updatedAt || realMasterState.createdAt || 0;

        // If one is clearly newer, use it
        if (localTime > remoteTime + 60000) { // 1 minute difference
            console.log('[Conflict:Smart] Local significantly newer');
            return newDocumentState;
        }
        if (remoteTime > localTime + 60000) {
            console.log('[Conflict:Smart] Remote significantly newer');
            return realMasterState;
        }

        // Timestamps are close - try to merge
        console.log('[Conflict:Smart] Timestamps close, attempting merge...');

        try {
            const merged = mergeDocuments(
                assumedMasterState,
                newDocumentState,
                realMasterState,
                collectionName
            );
            console.log('[Conflict:Smart] ✅ Merge successful');
            return merged;
        } catch (error) {
            console.warn('[Conflict:Smart] Merge failed, using LWW fallback');
            return localTime >= remoteTime ? newDocumentState : realMasterState;
        }
    };
}

/**
 * Merge two document versions
 * Combines non-conflicting changes from both
 */
function mergeDocuments(assumedMasterState, localState, remoteState, collectionName) {
    // Start with remote state (server is authoritative)
    const merged = { ...remoteState };

    // Determine which fields can be safely merged
    const mergeableFields = getMergeableFields(collectionName);

    for (const field of mergeableFields) {
        const assumedValue = assumedMasterState?.[field];
        const localValue = localState[field];
        const remoteValue = remoteState[field];

        // If local changed from assumed but remote didn't, use local
        if (localValue !== assumedValue && remoteValue === assumedValue) {
            merged[field] = localValue;
            console.log(`[Merge] Field '${field}' from local`);
        }
        // If remote changed from assumed but local didn't, use remote
        else if (remoteValue !== assumedValue && localValue === assumedValue) {
            merged[field] = remoteValue;
            console.log(`[Merge] Field '${field}' from remote`);
        }
        // Both changed - can't merge automatically, use remote
        else if (localValue !== assumedValue && remoteValue !== assumedValue) {
            merged[field] = remoteValue;
            console.log(`[Merge] Field '${field}' conflict - using remote`);
        }
    }

    // Always use the latest updatedAt
    merged.updatedAt = Math.max(
        localState.updatedAt || 0,
        remoteState.updatedAt || 0
    );

    return merged;
}

/**
 * Get fields that can be merged for a collection
 */
function getMergeableFields(collectionName) {
    switch (collectionName) {
        case 'transactions':
            return ['vendor', 'lineItems']; // Can merge these

        case 'waterChecks':
            return ['location']; // Temperature shouldn't be merged

        case 'complaints':
            return ['description']; // Description can be merged

        default:
            return [];
    }
}

/**
 * Create conflict handlers for all collections
 */
function createAllConflictHandlers(useSmartMerge = false) {
    const createFn = useSmartMerge ? createSmartConflictHandler : createConflictHandler;

    return {
        transactions: createFn('transactions'),
        waterChecks: createFn('waterChecks'),
        complaints: createFn('complaints')
    };
}

// Export
if (typeof window !== 'undefined') {
    window.RxDBConflictHandler = {
        create: createConflictHandler,
        createSmart: createSmartConflictHandler,
        createAll: createAllConflictHandlers
    };
}

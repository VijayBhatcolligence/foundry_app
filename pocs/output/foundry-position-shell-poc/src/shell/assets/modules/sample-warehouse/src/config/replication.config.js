// Replication Configuration
const REPLICATION_CONFIG = {
    // Sync interval (ms) - 60 seconds = 1 minute
    syncInterval: 60 * 1000,

    // Batch size for syncing
    batchSize: 50,

    // Live replication (continuous sync)
    live: true,

    // Retry failed syncs
    retry: true,
    retryTime: 5000, // ms

    // Conflict resolution strategy
    conflictHandler: 'last-write-wins', // or 'custom'

    // Direction
    pull: {
        enabled: true,
        queryBuilder: (lastCheckpoint) => {
            // Query string for pulling updates
            return `?since=${lastCheckpoint || 0}&limit=100`;
        }
    },

    push: {
        enabled: true,
        batchSize: 50
    },

    // Checkpoint storage (to track last sync point)
    checkpoint: {
        storage: 'localStorage', // or 'indexeddb'
        prefix: 'rxdb_checkpoint_'
    }
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = REPLICATION_CONFIG;
}

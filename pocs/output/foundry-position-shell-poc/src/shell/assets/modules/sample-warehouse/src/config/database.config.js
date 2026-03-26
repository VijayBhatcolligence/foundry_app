// Database Configuration
const DATABASE_CONFIG = {
    name: 'warehouse_rxdb',
    version: 1,
    multiInstance: true, // Support multiple tabs/workers
    ignoreDuplicate: true,

    // Storage settings
    storage: {
        type: 'indexeddb',
        encrypted: false // Can enable for sensitive data
    },

    // Collections to create
    collections: ['transactions', 'waterChecks', 'complaints'],

    // Development mode (more logging)
    dev: true
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = DATABASE_CONFIG;
}

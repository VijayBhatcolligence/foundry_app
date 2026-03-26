// API Configuration
const API_CONFIG = {
    baseURL: 'http://192.168.0.163:3000',

    endpoints: {
        transactions: '/api/transactions',
        waterChecks: '/api/water-checks',
        complaints: '/api/complaints',

        // Batch endpoints for faster sync
        transactionsBatch: '/api/transactions/batch',
        waterChecksBatch: '/api/water-checks/batch',
        complaintsBatch: '/api/complaints/batch'
    },

    // Request timeout (ms)
    timeout: 30000,

    // Retry configuration
    retry: {
        maxAttempts: 3,
        backoff: 1000 // ms between retries
    }
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = API_CONFIG;
}

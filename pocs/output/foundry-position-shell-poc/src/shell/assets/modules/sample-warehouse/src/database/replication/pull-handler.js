// Pull Handler - Download updates from server to RxDB

/**
 * Create pull handler for a collection
 * Downloads updates from backend since last checkpoint
 */
function createPullHandler(collectionName, apiEndpoint) {
    return async (checkpointOrNull, batchSize) => {
        console.log(`[Pull] Pulling ${collectionName} updates...`);
        console.log(`[Pull] Checkpoint:`, checkpointOrNull);
        console.log(`[Pull] Batch size:`, batchSize);

        try {
            // Get checkpoint timestamp (last sync point)
            const lastCheckpoint = checkpointOrNull?.updatedAt || 0;

            // Build query URL
            const url = `${API_CONFIG.baseURL}${apiEndpoint}?since=${lastCheckpoint}&limit=${batchSize || 100}`;

            console.log(`[Pull] Fetching from: ${url}`);

            // Fetch from backend
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                },
                timeout: API_CONFIG.timeout
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const data = await response.json();

            // Extract documents array (backend might return different formats)
            let documents = [];
            if (data.transactions) documents = data.transactions;
            else if (data.waterChecks) documents = data.waterChecks;
            else if (data.checks) documents = data.checks;
            else if (data.complaints) documents = data.complaints;
            else if (Array.isArray(data)) documents = data;
            else if (data.data && Array.isArray(data.data)) documents = data.data;

            console.log(`[Pull] Downloaded ${documents.length} documents`);

            // Transform backend documents to RxDB format
            const rxDocuments = documents.map(doc => transformBackendToRxDB(doc, collectionName));

            // Find the latest updatedAt for checkpoint
            let newCheckpoint = checkpointOrNull;
            if (rxDocuments.length > 0) {
                const maxUpdatedAt = Math.max(...rxDocuments.map(d => d.updatedAt || d.createdAt || 0));
                newCheckpoint = {
                    id: `${collectionName}_${maxUpdatedAt}`,
                    updatedAt: maxUpdatedAt
                };
            }

            console.log(`[Pull] New checkpoint:`, newCheckpoint);

            return {
                documents: rxDocuments,
                checkpoint: newCheckpoint
            };

        } catch (error) {
            console.error(`[Pull] Error pulling ${collectionName}:`, error);

            // Return empty result on error (RxDB will retry)
            return {
                documents: [],
                checkpoint: checkpointOrNull
            };
        }
    };
}

/**
 * Transform backend document format to RxDB format
 */
function transformBackendToRxDB(doc, collectionName) {
    const now = Date.now();

    // Base transformation (common fields)
    const transformed = {
        ...doc,
        updatedAt: doc.updatedAt || doc.updated_at || doc.createdAt || doc.created_at || now,
        createdAt: doc.createdAt || doc.created_at || now,
        deleted: doc.deleted || false,
        syncStatus: 'synced' // Mark as synced since from server
    };

    // Collection-specific transformations
    switch (collectionName) {
        case 'transactions':
            return {
                ...transformed,
                transactionId: doc.transactionId || doc.transaction_id || doc.id,
                poNumber: doc.poNumber || doc.po_number || '',
                vendor: doc.vendor || '',
                lineItems: doc.lineItems || doc.line_items || []
            };

        case 'waterChecks':
            return {
                ...transformed,
                id: doc.id,
                temp_fahrenheit: doc.temp_fahrenheit,
                temp_celsius: doc.temp_celsius,
                location: doc.location,
                photo_path: doc.photo_path,
                timestamp: doc.timestamp || transformed.createdAt
            };

        case 'complaints':
            return {
                ...transformed,
                id: doc.id,
                barcode: doc.barcode,
                product_sku: doc.product_sku,
                product_name: doc.product_name,
                complaint_type: doc.complaint_type,
                description: doc.description,
                photo_path: doc.photo_path,
                timestamp: doc.timestamp || transformed.createdAt
            };

        default:
            return transformed;
    }
}

/**
 * Create pull streams for all collections
 */
function createAllPullHandlers() {
    return {
        transactions: createPullHandler('transactions', API_CONFIG.endpoints.transactions),
        waterChecks: createPullHandler('waterChecks', API_CONFIG.endpoints.waterChecks),
        complaints: createPullHandler('complaints', API_CONFIG.endpoints.complaints)
    };
}

// Export
if (typeof window !== 'undefined') {
    window.RxDBPullHandler = {
        create: createPullHandler,
        createAll: createAllPullHandlers
    };
}

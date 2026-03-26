// Push Handler - Upload local changes to server

/**
 * Create push handler for a collection
 * Uploads local changes to backend
 */
function createPushHandler(collectionName, apiEndpoint) {
    return async (changeRows) => {
        console.log(`[Push] Pushing ${changeRows.length} ${collectionName} changes...`);

        const results = [];

        for (const changeRow of changeRows) {
            const doc = changeRow.newDocumentState;
            const assumedMasterState = changeRow.assumedMasterState;

            console.log(`[Push] Processing document:`, doc);

            try {
                let result;

                // Handle based on operation type
                if (doc.deleted) {
                    // DELETE operation
                    result = await pushDelete(doc, collectionName, apiEndpoint);
                } else if (assumedMasterState) {
                    // UPDATE operation (document already exists on server)
                    result = await pushUpdate(doc, collectionName, apiEndpoint);
                } else {
                    // CREATE operation (new document)
                    result = await pushCreate(doc, collectionName, apiEndpoint);
                }

                results.push(result);

            } catch (error) {
                console.error(`[Push] Failed to push ${collectionName}:`, error);

                // Return error for retry
                results.push({
                    assumedMasterState,
                    newDocumentState: doc
                });
            }
        }

        console.log(`[Push] Pushed ${results.length} changes`);
        return results;
    };
}

/**
 * Push CREATE (new document)
 */
async function pushCreate(doc, collectionName, apiEndpoint) {
    console.log(`[Push] CREATE ${collectionName}:`, doc);

    const url = `${API_CONFIG.baseURL}${apiEndpoint}`;
    const payload = transformRxDBToBackend(doc, collectionName);

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
    });

    if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();

    // Return the new master state from server
    return {
        assumedMasterState: null,
        newDocumentState: {
            ...doc,
            syncStatus: 'synced',
            updatedAt: Date.now()
        }
    };
}

/**
 * Push UPDATE (existing document)
 */
async function pushUpdate(doc, collectionName, apiEndpoint) {
    console.log(`[Push] UPDATE ${collectionName}:`, doc);

    // Get document ID
    const docId = getDocumentId(doc, collectionName);
    const url = `${API_CONFIG.baseURL}${apiEndpoint}/${docId}`;
    const payload = transformRxDBToBackend(doc, collectionName);

    const response = await fetch(url, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
    });

    if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();

    return {
        assumedMasterState: doc,
        newDocumentState: {
            ...doc,
            syncStatus: 'synced',
            updatedAt: Date.now()
        }
    };
}

/**
 * Push DELETE
 */
async function pushDelete(doc, collectionName, apiEndpoint) {
    console.log(`[Push] DELETE ${collectionName}:`, doc);

    const docId = getDocumentId(doc, collectionName);
    const url = `${API_CONFIG.baseURL}${apiEndpoint}/${docId}`;

    const response = await fetch(url, {
        method: 'DELETE',
        headers: {
            'Accept': 'application/json'
        }
    });

    if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    // Return null to indicate document should be removed
    return null;
}

/**
 * Get document ID based on collection
 */
function getDocumentId(doc, collectionName) {
    switch (collectionName) {
        case 'transactions':
            return doc.transactionId;
        case 'waterChecks':
        case 'complaints':
            return doc.id;
        default:
            return doc.id || doc._id;
    }
}

/**
 * Transform RxDB document to backend format
 */
function transformRxDBToBackend(doc, collectionName) {
    // Remove RxDB internal fields
    const { _rev, _attachments, _deleted, _meta, ...cleanDoc } = doc;

    // Collection-specific transformations
    switch (collectionName) {
        case 'transactions':
            return {
                transactionId: doc.transactionId,
                poNumber: doc.poNumber,
                vendor: doc.vendor,
                lineItems: doc.lineItems,
                createdAt: doc.createdAt,
                updatedAt: doc.updatedAt
            };

        case 'waterChecks':
            return {
                id: doc.id,
                temp_fahrenheit: doc.temp_fahrenheit,
                temp_celsius: doc.temp_celsius,
                location: doc.location,
                photo_path: doc.photo_path,
                timestamp: doc.timestamp
            };

        case 'complaints':
            return {
                id: doc.id,
                barcode: doc.barcode,
                product_sku: doc.product_sku,
                product_name: doc.product_name,
                complaint_type: doc.complaint_type,
                description: doc.description,
                photo_path: doc.photo_path,
                timestamp: doc.timestamp
            };

        default:
            return cleanDoc;
    }
}

/**
 * Create push handlers for all collections
 */
function createAllPushHandlers() {
    return {
        transactions: createPushHandler('transactions', API_CONFIG.endpoints.transactions),
        waterChecks: createPushHandler('waterChecks', API_CONFIG.endpoints.waterChecks),
        complaints: createPushHandler('complaints', API_CONFIG.endpoints.complaints)
    };
}

// Export
if (typeof window !== 'undefined') {
    window.RxDBPushHandler = {
        create: createPushHandler,
        createAll: createAllPushHandlers
    };
}

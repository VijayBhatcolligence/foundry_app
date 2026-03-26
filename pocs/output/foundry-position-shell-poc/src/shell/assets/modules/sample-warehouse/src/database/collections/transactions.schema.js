// Transaction Collection Schema for RxDB

const transactionsSchema = {
    title: 'transaction schema',
    version: 0,
    description: 'Purchase Order transactions schema',
    primaryKey: 'transactionId',
    type: 'object',
    properties: {
        transactionId: {
            type: 'string',
            maxLength: 100
        },
        poNumber: {
            type: 'string',
            maxLength: 100
        },
        vendor: {
            type: 'string',
            maxLength: 200
        },
        lineItems: {
            type: 'array',
            items: {
                type: 'object',
                properties: {
                    id: { type: 'string' },
                    sku: { type: 'string' },
                    description: { type: 'string' },
                    quantity: { type: 'number' },
                    location: { type: 'string' },
                    photoPath: { type: 'string' }
                }
            }
        },
        createdAt: {
            type: 'number',
            minimum: 0
        },
        updatedAt: {
            type: 'number',
            minimum: 0
        },
        deleted: {
            type: 'boolean',
            default: false
        },
        deletedAt: {
            type: 'number'
        },
        syncStatus: {
            type: 'string',
            enum: ['pending', 'syncing', 'synced', 'failed'],
            default: 'pending'
        },
        retryCount: {
            type: 'number',
            minimum: 0,
            default: 0
        },
        lastError: {
            type: 'string'
        },
        lastSyncAttempt: {
            type: 'number'
        }
    },
    required: ['transactionId', 'poNumber', 'createdAt'],
    indexes: [
        'poNumber',
        'syncStatus',
        'createdAt',
        'deleted'
    ]
};

// Collection Methods (attached to each document)
const transactionMethods = {
    // Soft delete
    softDelete() {
        return this.update({
            $set: {
                deleted: true,
                deletedAt: Date.now(),
                syncStatus: 'pending' // Mark for sync
            }
        });
    },

    // Mark as synced
    markSynced() {
        return this.update({
            $set: {
                syncStatus: 'synced',
                retryCount: 0,
                lastError: null,
                lastSyncAttempt: Date.now()
            }
        });
    },

    // Mark as failed
    markFailed(error) {
        return this.update({
            $set: {
                syncStatus: 'failed',
                retryCount: (this.retryCount || 0) + 1,
                lastError: error.message || error.toString(),
                lastSyncAttempt: Date.now()
            }
        });
    },

    // Get display info
    getDisplayInfo() {
        return {
            id: this.transactionId,
            po: this.poNumber,
            vendor: this.vendor,
            items: this.lineItems?.length || 0,
            date: new Date(this.createdAt).toLocaleString(),
            status: this.syncStatus
        };
    }
};

// Static Collection Methods (attached to collection)
const transactionCollectionMethods = {
    // Find pending sync items
    async findPendingSync() {
        return this.find({
            selector: {
                syncStatus: { $in: ['pending', 'failed'] },
                deleted: false
            },
            sort: [{ createdAt: 'asc' }]
        }).exec();
    },

    // Find deleted items pending sync
    async findPendingDeletes() {
        return this.find({
            selector: {
                deleted: true,
                syncStatus: 'pending'
            }
        }).exec();
    },

    // Get active transactions (not deleted)
    async findActive(limit = 100) {
        return this.find({
            selector: {
                deleted: false
            },
            sort: [{ createdAt: 'desc' }],
            limit
        }).exec();
    }
};

// Export schema and methods
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        schema: transactionsSchema,
        methods: transactionMethods,
        statics: transactionCollectionMethods
    };
}

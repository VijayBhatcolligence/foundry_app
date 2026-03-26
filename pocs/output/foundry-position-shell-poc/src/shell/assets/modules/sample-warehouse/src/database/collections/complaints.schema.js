// Complaint Collection Schema for RxDB

const complaintsSchema = {
    title: 'complaint schema',
    version: 0,
    description: 'Product complaints schema',
    primaryKey: 'id',
    type: 'object',
    properties: {
        id: {
            type: 'string',
            maxLength: 100
        },
        barcode: {
            type: 'string',
            maxLength: 100
        },
        product_sku: {
            type: 'string',
            maxLength: 100
        },
        product_name: {
            type: 'string',
            maxLength: 200
        },
        complaint_type: {
            type: 'string',
            maxLength: 100
        },
        description: {
            type: 'string',
            maxLength: 1000
        },
        photo_path: {
            type: 'string' // Base64 encoded image
        },
        timestamp: {
            type: 'number',
            minimum: 0
        },
        createdAt: {
            type: 'number',
            minimum: 0
        },
        updatedAt: {
            type: 'number'
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
    required: ['id', 'product_sku', 'complaint_type', 'timestamp'],
    indexes: [
        'product_sku',
        'complaint_type',
        'timestamp',
        'syncStatus',
        'createdAt',
        'deleted'
    ]
};

// Document Methods
const complaintMethods = {
    softDelete() {
        return this.update({
            $set: {
                deleted: true,
                deletedAt: Date.now(),
                syncStatus: 'pending'
            }
        });
    },

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

    getDisplayInfo() {
        return {
            id: this.id,
            product: this.product_name || this.product_sku,
            type: this.complaint_type,
            description: this.description?.substring(0, 50) + '...',
            date: new Date(this.timestamp).toLocaleString(),
            status: this.syncStatus
        };
    }
};

// Collection Methods
const complaintCollectionMethods = {
    async findPendingSync() {
        return this.find({
            selector: {
                syncStatus: { $in: ['pending', 'failed'] },
                deleted: false
            },
            sort: [{ timestamp: 'asc' }]
        }).exec();
    },

    async findPendingDeletes() {
        return this.find({
            selector: {
                deleted: true,
                syncStatus: 'pending'
            }
        }).exec();
    },

    async findRecent(limit = 50) {
        return this.find({
            selector: {
                deleted: false
            },
            sort: [{ timestamp: 'desc' }],
            limit
        }).exec();
    },

    async findByProduct(productSku) {
        return this.find({
            selector: {
                product_sku: productSku,
                deleted: false
            },
            sort: [{ timestamp: 'desc' }]
        }).exec();
    }
};

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        schema: complaintsSchema,
        methods: complaintMethods,
        statics: complaintCollectionMethods
    };
}

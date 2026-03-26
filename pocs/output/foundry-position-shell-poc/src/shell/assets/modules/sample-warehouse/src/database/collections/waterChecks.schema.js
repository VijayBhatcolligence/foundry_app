// Water Check Collection Schema for RxDB

const waterChecksSchema = {
    title: 'water check schema',
    version: 0,
    description: 'Water temperature checks schema',
    primaryKey: 'id',
    type: 'object',
    properties: {
        id: {
            type: 'string',
            maxLength: 100
        },
        temp_fahrenheit: {
            type: 'number',
            minimum: 0,
            maximum: 200
        },
        temp_celsius: {
            type: 'number',
            minimum: -20,
            maximum: 100
        },
        location: {
            type: 'string',
            maxLength: 200
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
    required: ['id', 'temp_fahrenheit', 'timestamp'],
    indexes: [
        'timestamp',
        'syncStatus',
        'createdAt',
        'deleted'
    ]
};

// Document Methods
const waterCheckMethods = {
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
            temp: `${this.temp_fahrenheit}°F (${this.temp_celsius}°C)`,
            location: this.location || 'Unknown',
            date: new Date(this.timestamp).toLocaleString(),
            status: this.syncStatus
        };
    }
};

// Collection Methods
const waterCheckCollectionMethods = {
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
    }
};

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        schema: waterChecksSchema,
        methods: waterCheckMethods,
        statics: waterCheckCollectionMethods
    };
}

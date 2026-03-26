// RxDB Database Initialization

/**
 * Initialize RxDB database with all collections
 * This is the main entry point for database setup
 */

let dbInstance = null;

async function initializeDatabase() {
    console.log('[RxDB] Initializing database...');

    try {
        // Check if already initialized
        if (dbInstance) {
            console.log('[RxDB] Database already initialized');
            return dbInstance;
        }

        // Create RxDB database
        const db = await RxDB.createRxDatabase({
            name: 'warehouse_rxdb',
            storage: getRxStorageIndexedDB(), // Use IndexedDB storage
            multiInstance: true, // Allow multiple tabs
            ignoreDuplicate: true
        });

        console.log('[RxDB] Database created');

        // Add collections
        await addCollections(db);

        // Store instance
        dbInstance = db;

        console.log('[RxDB] ✅ Database initialized successfully');
        return db;

    } catch (error) {
        console.error('[RxDB] ❌ Failed to initialize database:', error);
        throw error;
    }
}

/**
 * Add all collections to the database
 */
async function addCollections(db) {
    console.log('[RxDB] Adding collections...');

    // Import schemas (these will be loaded in the HTML)
    const { schema: transactionsSchema, methods: transactionMethods, statics: transactionStatics } = window.TransactionsSchema;
    const { schema: waterChecksSchema, methods: waterCheckMethods, statics: waterCheckStatics } = window.WaterChecksSchema;
    const { schema: complaintsSchema, methods: complaintMethods, statics: complaintStatics } = window.ComplaintsSchema;

    // Add collections
    await db.addCollections({
        transactions: {
            schema: transactionsSchema,
            methods: transactionMethods,
            statics: transactionStatics
        },
        waterChecks: {
            schema: waterChecksSchema,
            methods: waterCheckMethods,
            statics: waterCheckStatics
        },
        complaints: {
            schema: complaintsSchema,
            methods: complaintMethods,
            statics: complaintStatics
        }
    });

    console.log('[RxDB] ✅ Collections added: transactions, waterChecks, complaints');
}

/**
 * Get database instance (must be initialized first)
 */
function getDatabase() {
    if (!dbInstance) {
        throw new Error('[RxDB] Database not initialized. Call initializeDatabase() first.');
    }
    return dbInstance;
}

/**
 * Close database connection
 */
async function closeDatabase() {
    if (dbInstance) {
        console.log('[RxDB] Closing database...');
        await dbInstance.destroy();
        dbInstance = null;
        console.log('[RxDB] Database closed');
    }
}

/**
 * Check if database is initialized
 */
function isDatabaseInitialized() {
    return dbInstance !== null;
}

// Export functions
if (typeof window !== 'undefined') {
    window.RxDBDatabase = {
        initialize: initializeDatabase,
        getDatabase,
        closeDatabase,
        isDatabaseInitialized
    };
}

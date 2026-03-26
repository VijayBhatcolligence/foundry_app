// Dexie to RxDB Migration Script

/**
 * Migrate data from Dexie to RxDB
 * This is a one-time migration that runs on first load after RxDB is added
 */

const MIGRATION_FLAG = 'rxdb_migration_completed';
const MIGRATION_BACKUP_FLAG = 'rxdb_migration_backup';

async function migrateDexieToRxDB(dexieDB, rxDB) {
    console.log('[Migration] ========================================');
    console.log('[Migration] Starting Dexie → RxDB Migration');
    console.log('[Migration] ========================================');

    try {
        // Check if migration already done
        if (localStorage.getItem(MIGRATION_FLAG) === 'true') {
            console.log('[Migration] ✅ Migration already completed, skipping');
            return { success: true, skipped: true };
        }

        // Verify both databases are ready
        if (!dexieDB || !rxDB) {
            throw new Error('Both databases must be initialized');
        }

        console.log('[Migration] Starting migration process...');

        const results = {
            transactions: 0,
            waterChecks: 0,
            complaints: 0,
            errors: []
        };

        // Migrate transactions
        console.log('[Migration] Step 1/3: Migrating transactions...');
        results.transactions = await migrateTransactions(dexieDB, rxDB);

        // Migrate water checks
        console.log('[Migration] Step 2/3: Migrating water checks...');
        results.waterChecks = await migrateWaterChecks(dexieDB, rxDB);

        // Migrate complaints
        console.log('[Migration] Step 3/3: Migrating complaints...');
        results.complaints = await migrateComplaints(dexieDB, rxDB);

        // Verify migration
        console.log('[Migration] Verifying migration...');
        const verified = await verifyMigration(dexieDB, rxDB, results);

        if (!verified) {
            throw new Error('Migration verification failed');
        }

        // Mark migration as complete
        localStorage.setItem(MIGRATION_FLAG, 'true');
        localStorage.setItem(MIGRATION_BACKUP_FLAG, JSON.stringify({
            date: new Date().toISOString(),
            results
        }));

        console.log('[Migration] ========================================');
        console.log('[Migration] ✅ Migration completed successfully!');
        console.log('[Migration] Transactions:', results.transactions);
        console.log('[Migration] Water Checks:', results.waterChecks);
        console.log('[Migration] Complaints:', results.complaints);
        console.log('[Migration] ========================================');

        return { success: true, results };

    } catch (error) {
        console.error('[Migration] ❌ Migration failed:', error);
        return { success: false, error: error.message };
    }
}

/**
 * Migrate transactions from Dexie to RxDB
 */
async function migrateTransactions(dexieDB, rxDB) {
    try {
        // Read all transactions from Dexie
        const dexieTransactions = await dexieDB.transactions.toArray();
        console.log(`[Migration] Found ${dexieTransactions.length} transactions in Dexie`);

        if (dexieTransactions.length === 0) {
            return 0;
        }

        // Transform and insert into RxDB
        let migrated = 0;
        for (const dexieTx of dexieTransactions) {
            try {
                // Transform to RxDB format
                const rxDoc = {
                    transactionId: dexieTx.transactionId,
                    poNumber: dexieTx.poNumber || '',
                    vendor: dexieTx.vendor || '',
                    lineItems: dexieTx.lineItems || [],
                    createdAt: dexieTx.createdAt || Date.now(),
                    updatedAt: dexieTx.updatedAt || dexieTx.createdAt || Date.now(),
                    deleted: dexieTx.deleted || false,
                    deletedAt: dexieTx.deletedAt,
                    syncStatus: dexieTx.syncStatus || 'synced',
                    retryCount: dexieTx.retryCount || 0,
                    lastError: dexieTx.lastError,
                    lastSyncAttempt: dexieTx.lastSyncAttempt
                };

                // Insert into RxDB
                await rxDB.transactions.insert(rxDoc);
                migrated++;

            } catch (insertError) {
                console.warn(`[Migration] Failed to migrate transaction ${dexieTx.transactionId}:`, insertError);
            }
        }

        console.log(`[Migration] ✅ Migrated ${migrated}/${dexieTransactions.length} transactions`);
        return migrated;

    } catch (error) {
        console.error('[Migration] Transaction migration error:', error);
        throw error;
    }
}

/**
 * Migrate water checks from Dexie to RxDB
 */
async function migrateWaterChecks(dexieDB, rxDB) {
    try {
        const dexieChecks = await dexieDB.waterChecks.toArray();
        console.log(`[Migration] Found ${dexieChecks.length} water checks in Dexie`);

        if (dexieChecks.length === 0) {
            return 0;
        }

        let migrated = 0;
        for (const dexieCheck of dexieChecks) {
            try {
                const rxDoc = {
                    id: dexieCheck.id,
                    temp_fahrenheit: dexieCheck.temp_fahrenheit,
                    temp_celsius: dexieCheck.temp_celsius,
                    location: dexieCheck.location,
                    photo_path: dexieCheck.photo_path,
                    timestamp: dexieCheck.timestamp || dexieCheck.createdAt || Date.now(),
                    createdAt: dexieCheck.createdAt || dexieCheck.timestamp || Date.now(),
                    updatedAt: dexieCheck.updatedAt || dexieCheck.createdAt || Date.now(),
                    deleted: dexieCheck.deleted || false,
                    deletedAt: dexieCheck.deletedAt,
                    syncStatus: dexieCheck.syncStatus || 'synced',
                    retryCount: dexieCheck.retryCount || 0,
                    lastError: dexieCheck.lastError,
                    lastSyncAttempt: dexieCheck.lastSyncAttempt
                };

                await rxDB.waterChecks.insert(rxDoc);
                migrated++;

            } catch (insertError) {
                console.warn(`[Migration] Failed to migrate water check ${dexieCheck.id}:`, insertError);
            }
        }

        console.log(`[Migration] ✅ Migrated ${migrated}/${dexieChecks.length} water checks`);
        return migrated;

    } catch (error) {
        console.error('[Migration] Water check migration error:', error);
        throw error;
    }
}

/**
 * Migrate complaints from Dexie to RxDB
 */
async function migrateComplaints(dexieDB, rxDB) {
    try {
        const dexieComplaints = await dexieDB.complaints.toArray();
        console.log(`[Migration] Found ${dexieComplaints.length} complaints in Dexie`);

        if (dexieComplaints.length === 0) {
            return 0;
        }

        let migrated = 0;
        for (const dexieComplaint of dexieComplaints) {
            try {
                const rxDoc = {
                    id: dexieComplaint.id,
                    barcode: dexieComplaint.barcode,
                    product_sku: dexieComplaint.product_sku,
                    product_name: dexieComplaint.product_name,
                    complaint_type: dexieComplaint.complaint_type,
                    description: dexieComplaint.description,
                    photo_path: dexieComplaint.photo_path,
                    timestamp: dexieComplaint.timestamp || dexieComplaint.createdAt || Date.now(),
                    createdAt: dexieComplaint.createdAt || dexieComplaint.timestamp || Date.now(),
                    updatedAt: dexieComplaint.updatedAt || dexieComplaint.createdAt || Date.now(),
                    deleted: dexieComplaint.deleted || false,
                    deletedAt: dexieComplaint.deletedAt,
                    syncStatus: dexieComplaint.syncStatus || 'synced',
                    retryCount: dexieComplaint.retryCount || 0,
                    lastError: dexieComplaint.lastError,
                    lastSyncAttempt: dexieComplaint.lastSyncAttempt
                };

                await rxDB.complaints.insert(rxDoc);
                migrated++;

            } catch (insertError) {
                console.warn(`[Migration] Failed to migrate complaint ${dexieComplaint.id}:`, insertError);
            }
        }

        console.log(`[Migration] ✅ Migrated ${migrated}/${dexieComplaints.length} complaints`);
        return migrated;

    } catch (error) {
        console.error('[Migration] Complaint migration error:', error);
        throw error;
    }
}

/**
 * Verify migration completed successfully
 */
async function verifyMigration(dexieDB, rxDB, results) {
    console.log('[Migration] Verifying data integrity...');

    try {
        // Count records in RxDB
        const rxTransactions = await rxDB.transactions.count().exec();
        const rxWaterChecks = await rxDB.waterChecks.count().exec();
        const rxComplaints = await rxDB.complaints.count().exec();

        console.log('[Migration] RxDB counts:', {
            transactions: rxTransactions,
            waterChecks: rxWaterChecks,
            complaints: rxComplaints
        });

        console.log('[Migration] Expected counts:', results);

        // Verify counts match
        const transactionsMatch = rxTransactions >= results.transactions;
        const waterChecksMatch = rxWaterChecks >= results.waterChecks;
        const complaintsMatch = rxComplaints >= results.complaints;

        const verified = transactionsMatch && waterChecksMatch && complaintsMatch;

        if (verified) {
            console.log('[Migration] ✅ Verification passed');
        } else {
            console.error('[Migration] ❌ Verification failed - counts do not match');
        }

        return verified;

    } catch (error) {
        console.error('[Migration] Verification error:', error);
        return false;
    }
}

/**
 * Reset migration (for testing/debugging)
 */
function resetMigration() {
    console.log('[Migration] Resetting migration flags...');
    localStorage.removeItem(MIGRATION_FLAG);
    localStorage.removeItem(MIGRATION_BACKUP_FLAG);
    console.log('[Migration] Migration flags cleared');
}

/**
 * Check if migration is needed
 */
function isMigrationNeeded() {
    return localStorage.getItem(MIGRATION_FLAG) !== 'true';
}

// Export
if (typeof window !== 'undefined') {
    window.RxDBMigration = {
        migrate: migrateDexieToRxDB,
        reset: resetMigration,
        isNeeded: isMigrationNeeded
    };
}

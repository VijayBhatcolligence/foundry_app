// useTransactions Hook - Transactions CRUD with observables

/**
 * Hook for transaction operations
 * Provides CRUD methods and reactive queries
 */
function useTransactions() {
    const { db, isInitialized } = window.useRxDB();
    const [transactions, setTransactions] = React.useState([]);
    const [loading, setLoading] = React.useState(true);
    const [error, setError] = React.useState(null);

    // Subscribe to transactions collection (live updates!)
    React.useEffect(() => {
        if (!isInitialized || !db) {
            return;
        }

        console.log('[useTransactions] Setting up observable query...');
        setLoading(true);

        // Create observable query (filters out deleted items)
        const query = db.transactions
            .find({
                selector: {
                    deleted: false
                },
                sort: [{ createdAt: 'desc' }]
            });

        // Subscribe to query results
        const subscription = query.$.subscribe(docs => {
            console.log('[useTransactions] Received update:', docs.length, 'transactions');
            setTransactions(docs);
            setLoading(false);
        });

        return () => {
            console.log('[useTransactions] Unsubscribing');
            subscription.unsubscribe();
        };
    }, [isInitialized, db]);

    // Add new transaction
    const addTransaction = React.useCallback(async (transactionData) => {
        if (!db) throw new Error('Database not initialized');

        console.log('[useTransactions] Adding transaction:', transactionData);

        try {
            const doc = await db.transactions.insert({
                transactionId: transactionData.transactionId || `tx-${Date.now()}`,
                poNumber: transactionData.poNumber,
                vendor: transactionData.vendor,
                lineItems: transactionData.lineItems || [],
                createdAt: Date.now(),
                updatedAt: Date.now(),
                deleted: false,
                syncStatus: 'pending',
                retryCount: 0
            });

            console.log('[useTransactions] ✅ Transaction added:', doc.transactionId);
            return doc;

        } catch (err) {
            console.error('[useTransactions] ❌ Add failed:', err);
            setError(err.message);
            throw err;
        }
    }, [db]);

    // Update transaction
    const updateTransaction = React.useCallback(async (transactionId, updates) => {
        if (!db) throw new Error('Database not initialized');

        console.log('[useTransactions] Updating:', transactionId);

        try {
            const doc = await db.transactions.findOne(transactionId).exec();

            if (!doc) {
                throw new Error('Transaction not found');
            }

            await doc.update({
                $set: {
                    ...updates,
                    updatedAt: Date.now(),
                    syncStatus: 'pending'
                }
            });

            console.log('[useTransactions] ✅ Transaction updated');
            return doc;

        } catch (err) {
            console.error('[useTransactions] ❌ Update failed:', err);
            setError(err.message);
            throw err;
        }
    }, [db]);

    // Delete transaction (soft delete)
    const deleteTransaction = React.useCallback(async (transactionId) => {
        if (!db) throw new Error('Database not initialized');

        console.log('[useTransactions] Deleting:', transactionId);

        try {
            const doc = await db.transactions.findOne(transactionId).exec();

            if (!doc) {
                throw new Error('Transaction not found');
            }

            // Use soft delete method from schema
            await doc.softDelete();

            console.log('[useTransactions] ✅ Transaction deleted');
            return true;

        } catch (err) {
            console.error('[useTransactions] ❌ Delete failed:', err);
            setError(err.message);
            throw err;
        }
    }, [db]);

    // Get single transaction
    const getTransaction = React.useCallback(async (transactionId) => {
        if (!db) throw new Error('Database not initialized');

        const doc = await db.transactions.findOne(transactionId).exec();
        return doc;
    }, [db]);

    // Get pending sync count
    const getPendingCount = React.useCallback(async () => {
        if (!db) return 0;

        const pending = await db.transactions.findPendingSync();
        return pending.length;
    }, [db]);

    return {
        transactions,
        loading,
        error,
        addTransaction,
        updateTransaction,
        deleteTransaction,
        getTransaction,
        getPendingCount
    };
}

// Export
if (typeof window !== 'undefined') {
    window.useTransactions = useTransactions;
}

// useWaterChecks Hook - Water checks CRUD with observables

function useWaterChecks() {
    const { db, isInitialized } = window.useRxDB();
    const [waterChecks, setWaterChecks] = React.useState([]);
    const [loading, setLoading] = React.useState(true);
    const [error, setError] = React.useState(null);

    // Subscribe to water checks collection
    React.useEffect(() => {
        if (!isInitialized || !db) return;

        console.log('[useWaterChecks] Setting up observable query...');
        setLoading(true);

        const query = db.waterChecks.find({
            selector: { deleted: false },
            sort: [{ timestamp: 'desc' }],
            limit: 100
        });

        const subscription = query.$.subscribe(docs => {
            console.log('[useWaterChecks] Update:', docs.length, 'checks');
            setWaterChecks(docs);
            setLoading(false);
        });

        return () => subscription.unsubscribe();
    }, [isInitialized, db]);

    // Add water check
    const addWaterCheck = React.useCallback(async (checkData) => {
        if (!db) throw new Error('Database not initialized');

        console.log('[useWaterChecks] Adding check:', checkData);

        try {
            const doc = await db.waterChecks.insert({
                id: checkData.id || `wt-${Date.now()}`,
                temp_fahrenheit: checkData.temp_fahrenheit,
                temp_celsius: checkData.temp_celsius,
                location: checkData.location,
                photo_path: checkData.photo_path,
                timestamp: checkData.timestamp || Date.now(),
                createdAt: Date.now(),
                updatedAt: Date.now(),
                deleted: false,
                syncStatus: 'pending',
                retryCount: 0
            });

            console.log('[useWaterChecks] ✅ Check added:', doc.id);
            return doc;

        } catch (err) {
            console.error('[useWaterChecks] ❌ Add failed:', err);
            setError(err.message);
            throw err;
        }
    }, [db]);

    // Delete water check
    const deleteWaterCheck = React.useCallback(async (id) => {
        if (!db) throw new Error('Database not initialized');

        console.log('[useWaterChecks] Deleting:', id);

        try {
            const doc = await db.waterChecks.findOne(id).exec();
            if (!doc) throw new Error('Check not found');

            await doc.softDelete();
            console.log('[useWaterChecks] ✅ Check deleted');
            return true;

        } catch (err) {
            console.error('[useWaterChecks] ❌ Delete failed:', err);
            setError(err.message);
            throw err;
        }
    }, [db]);

    return {
        waterChecks,
        loading,
        error,
        addWaterCheck,
        deleteWaterCheck
    };
}

// Export
if (typeof window !== 'undefined') {
    window.useWaterChecks = useWaterChecks;
}

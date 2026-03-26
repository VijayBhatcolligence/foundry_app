// useSyncStatus Hook - Monitor sync/replication status

function useSyncStatus() {
    const { db, isInitialized } = window.useRxDB();
    const [isOnline, setIsOnline] = React.useState(navigator.onLine);
    const [isSyncing, setIsSyncing] = React.useState(false);
    const [pendingCounts, setPendingCounts] = React.useState({
        transactions: 0,
        waterChecks: 0,
        complaints: 0,
        total: 0
    });
    const [lastSyncTime, setLastSyncTime] = React.useState(null);
    const [syncError, setSyncError] = React.useState(null);

    // Monitor online/offline status
    React.useEffect(() => {
        const handleOnline = () => {
            console.log('[useSyncStatus] ONLINE');
            setIsOnline(true);
        };

        const handleOffline = () => {
            console.log('[useSyncStatus] OFFLINE');
            setIsOnline(false);
        };

        window.addEventListener('online', handleOnline);
        window.addEventListener('offline', handleOffline);

        return () => {
            window.removeEventListener('online', handleOnline);
            window.removeEventListener('offline', handleOffline);
        };
    }, []);

    // Update pending counts periodically
    React.useEffect(() => {
        if (!isInitialized || !db) return;

        const updatePendingCounts = async () => {
            try {
                const txPending = await db.transactions.findPendingSync();
                const wcPending = await db.waterChecks.findPendingSync();
                const coPending = await db.complaints.findPendingSync();

                const counts = {
                    transactions: txPending.length,
                    waterChecks: wcPending.length,
                    complaints: coPending.length,
                    total: txPending.length + wcPending.length + coPending.length
                };

                setPendingCounts(counts);

            } catch (error) {
                console.error('[useSyncStatus] Error getting pending counts:', error);
            }
        };

        // Update immediately
        updatePendingCounts();

        // Update every 5 seconds
        const interval = setInterval(updatePendingCounts, 5000);

        return () => clearInterval(interval);
    }, [isInitialized, db]);

    // Trigger manual sync
    const triggerSync = React.useCallback(async () => {
        if (!isOnline) {
            setSyncError('Cannot sync while offline');
            return { success: false, error: 'offline' };
        }

        console.log('[useSyncStatus] Triggering manual sync...');
        setIsSyncing(true);
        setSyncError(null);

        try {
            const results = await window.RxDBReplication.trigger();
            setLastSyncTime(Date.now());
            console.log('[useSyncStatus] ✅ Sync complete:', results);

            setIsSyncing(false);
            return { success: true, results };

        } catch (error) {
            console.error('[useSyncStatus] ❌ Sync failed:', error);
            setSyncError(error.message);
            setIsSyncing(false);
            return { success: false, error: error.message };
        }
    }, [isOnline]);

    return {
        isOnline,
        isSyncing,
        pendingCounts,
        lastSyncTime,
        syncError,
        triggerSync
    };
}

// Export
if (typeof window !== 'undefined') {
    window.useSyncStatus = useSyncStatus;
}

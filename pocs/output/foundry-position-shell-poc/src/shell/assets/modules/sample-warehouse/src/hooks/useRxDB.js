// useRxDB Hook - Access RxDB database instance

/**
 * Hook to access the RxDB database
 * Returns database instance and initialization status
 */
function useRxDB() {
    const [db, setDb] = React.useState(null);
    const [isInitialized, setIsInitialized] = React.useState(false);
    const [error, setError] = React.useState(null);

    React.useEffect(() => {
        let mounted = true;

        async function init() {
            try {
                console.log('[useRxDB] Initializing database...');

                // Get or create database
                const database = await window.RxDBDatabase.initialize();

                if (mounted) {
                    setDb(database);
                    setIsInitialized(true);
                    console.log('[useRxDB] ✅ Database ready');
                }

            } catch (err) {
                console.error('[useRxDB] ❌ Initialization failed:', err);
                if (mounted) {
                    setError(err.message);
                }
            }
        }

        init();

        return () => {
            mounted = false;
        };
    }, []);

    return {
        db,
        isInitialized,
        error
    };
}

// Export
if (typeof window !== 'undefined') {
    window.useRxDB = useRxDB;
}

// useComplaints Hook - Complaints CRUD with observables

function useComplaints() {
    const { db, isInitialized } = window.useRxDB();
    const [complaints, setComplaints] = React.useState([]);
    const [loading, setLoading] = React.useState(true);
    const [error, setError] = React.useState(null);

    // Subscribe to complaints collection
    React.useEffect(() => {
        if (!isInitialized || !db) return;

        console.log('[useComplaints] Setting up observable query...');
        setLoading(true);

        const query = db.complaints.find({
            selector: { deleted: false },
            sort: [{ timestamp: 'desc' }],
            limit: 100
        });

        const subscription = query.$.subscribe(docs => {
            console.log('[useComplaints] Update:', docs.length, 'complaints');
            setComplaints(docs);
            setLoading(false);
        });

        return () => subscription.unsubscribe();
    }, [isInitialized, db]);

    // Add complaint
    const addComplaint = React.useCallback(async (complaintData) => {
        if (!db) throw new Error('Database not initialized');

        console.log('[useComplaints] Adding complaint:', complaintData);

        try {
            const doc = await db.complaints.insert({
                id: complaintData.id || `comp-${Date.now()}`,
                barcode: complaintData.barcode,
                product_sku: complaintData.product_sku,
                product_name: complaintData.product_name,
                complaint_type: complaintData.complaint_type,
                description: complaintData.description,
                photo_path: complaintData.photo_path,
                timestamp: complaintData.timestamp || Date.now(),
                createdAt: Date.now(),
                updatedAt: Date.now(),
                deleted: false,
                syncStatus: 'pending',
                retryCount: 0
            });

            console.log('[useComplaints] ✅ Complaint added:', doc.id);
            return doc;

        } catch (err) {
            console.error('[useComplaints] ❌ Add failed:', err);
            setError(err.message);
            throw err;
        }
    }, [db]);

    // Delete complaint
    const deleteComplaint = React.useCallback(async (id) => {
        if (!db) throw new Error('Database not initialized');

        console.log('[useComplaints] Deleting:', id);

        try {
            const doc = await db.complaints.findOne(id).exec();
            if (!doc) throw new Error('Complaint not found');

            await doc.softDelete();
            console.log('[useComplaints] ✅ Complaint deleted');
            return true;

        } catch (err) {
            console.error('[useComplaints] ❌ Delete failed:', err);
            setError(err.message);
            throw err;
        }
    }, [db]);

    return {
        complaints,
        loading,
        error,
        addComplaint,
        deleteComplaint
    };
}

// Export
if (typeof window !== 'undefined') {
    window.useComplaints = useComplaints;
}

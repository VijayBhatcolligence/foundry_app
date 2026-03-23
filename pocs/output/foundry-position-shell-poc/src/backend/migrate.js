// Migration script - Add products table to existing database
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'backend_transactions.db');
const db = new sqlite3.Database(dbPath);

console.log('🔧 Running database migration...\n');

const createProductsTableSQL = `
  CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sku TEXT NOT NULL,
    barcode TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    default_location TEXT NOT NULL
  )
`;

const createTransactionPhotosTableSQL = `
  CREATE TABLE IF NOT EXISTS transaction_photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id TEXT NOT NULL,
    line_item_id TEXT,
    photo_path TEXT NOT NULL,
    thumbnail_path TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
  )
`;

db.serialize(() => {
    // Create products table
    db.run(createProductsTableSQL, (err) => {
        if (err) {
            console.error('❌ Failed to create products table:', err.message);
            process.exit(1);
        } else {
            console.log('✅ Products table created');
        }
    });

    // Create index on barcode
    db.run('CREATE INDEX IF NOT EXISTS idx_barcode ON products(barcode)', (err) => {
        if (err) {
            console.error('❌ Failed to create barcode index:', err.message);
        } else {
            console.log('✅ Barcode index created');
        }
    });

    // Create transaction_photos table
    db.run(createTransactionPhotosTableSQL, (err) => {
        if (err) {
            console.error('❌ Failed to create transaction_photos table:', err.message);
        } else {
            console.log('✅ Transaction_photos table created');
        }
    });

    // Create index on transaction_id for photos
    db.run('CREATE INDEX IF NOT EXISTS idx_photos_transaction ON transaction_photos(transaction_id)', (err) => {
        if (err) {
            console.error('❌ Failed to create photos transaction index:', err.message);
        } else {
            console.log('✅ Photos transaction index created');
        }
    });

    // Create water_temp_checks table
    const createWaterTempChecksTableSQL = `
        CREATE TABLE IF NOT EXISTS water_temp_checks (
            id TEXT PRIMARY KEY,
            temp_fahrenheit REAL NOT NULL,
            temp_celsius REAL NOT NULL,
            location TEXT,
            photo_path TEXT,
            timestamp INTEGER NOT NULL,
            created_at INTEGER NOT NULL
        )
    `;

    db.run(createWaterTempChecksTableSQL, (err) => {
        if (err) {
            console.error('❌ Failed to create water_temp_checks table:', err.message);
        } else {
            console.log('✅ Water_temp_checks table created');
        }
    });

    // Create complaints table
    const createComplaintsTableSQL = `
        CREATE TABLE IF NOT EXISTS complaints (
            id TEXT PRIMARY KEY,
            barcode TEXT NOT NULL,
            product_sku TEXT,
            product_name TEXT,
            complaint_type TEXT NOT NULL,
            description TEXT NOT NULL,
            photo_path TEXT,
            timestamp INTEGER NOT NULL,
            status TEXT DEFAULT 'open',
            created_at INTEGER NOT NULL
        )
    `;

    db.run(createComplaintsTableSQL, (err) => {
        if (err) {
            console.error('❌ Failed to create complaints table:', err.message);
        } else {
            console.log('✅ Complaints table created');
        }

        console.log('\n🎉 Migration complete!\n');
        db.close();
    });
});

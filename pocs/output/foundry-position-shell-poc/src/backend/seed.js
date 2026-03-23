// Seed script - Populate database with sample transactions
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'backend_transactions.db');
const db = new sqlite3.Database(dbPath);

console.log('🌱 Seeding database with sample data...\n');

// Phase 5: Sample products with barcodes for scanner testing
const seedProducts = [
    {
        sku: 'WIDGET-001',
        barcode: '1234567890123', // UPC-A format (12 digits)
        name: 'Standard Widget',
        description: 'Basic widget for testing',
        default_location: 'A-01-01'
    },
    {
        sku: 'WIDGET-002',
        barcode: '2345678901234',
        name: 'Premium Widget',
        description: 'High-quality widget',
        default_location: 'A-01-02'
    },
    {
        sku: 'GADGET-100',
        barcode: '3456789012345',
        name: 'Small Gadget',
        description: 'Compact electronic gadget',
        default_location: 'B-02-01'
    },
    {
        sku: 'GADGET-200',
        barcode: '4567890123456',
        name: 'Large Gadget',
        description: 'Full-size electronic gadget',
        default_location: 'B-02-02'
    },
    {
        sku: 'TOOL-050',
        barcode: '5678901234567',
        name: 'Precision Tool',
        description: 'High-precision measurement tool',
        default_location: 'C-03-01'
    },
    {
        sku: 'PART-789',
        barcode: '6789012345678',
        name: 'Replacement Part',
        description: 'Universal replacement component',
        default_location: 'D-04-01'
    },
    {
        sku: 'CABLE-USB',
        barcode: '7890123456789',
        name: 'USB-C Cable 2m',
        description: 'High-speed USB-C cable',
        default_location: 'E-05-01'
    },
    {
        sku: 'SENSOR-TEMP',
        barcode: '8901234567890',
        name: 'Temperature Sensor',
        description: 'Digital temperature sensor module',
        default_location: 'F-06-01'
    },
    {
        sku: 'MOTOR-DC',
        barcode: '9012345678901',
        name: 'DC Motor 12V',
        description: '12V DC motor with encoder',
        default_location: 'G-07-01'
    },
    {
        sku: 'BATTERY-LIPO',
        barcode: '0123456789012',
        name: 'LiPo Battery 3000mAh',
        description: 'Lithium polymer battery pack',
        default_location: 'H-08-01'
    },
    {
        sku: 'DISPLAY-LCD',
        barcode: '1230456789012',
        name: '7-inch LCD Display',
        description: 'Color LCD touchscreen display',
        default_location: 'I-09-01'
    },
    {
        sku: 'SWITCH-RELAY',
        barcode: '2340567890123',
        name: 'Power Relay Switch',
        description: '30A power relay module',
        default_location: 'J-10-01'
    }
];

// Sample seed data - 5 realistic warehouse transactions
const seedTransactions = [
    {
        transactionId: 'TXN-SEED-001',
        poNumber: 'PO-20260310-001',
        vendor: 'Acme Manufacturing Corp',
        lineItems: JSON.stringify([
            { sku: 'WDG-001', description: 'Widget Type A', quantity: '50', location: 'A1-B2' },
            { sku: 'WDG-002', description: 'Widget Type B', quantity: '30', location: 'A1-B3' },
            { sku: 'SPR-101', description: 'Spring Assembly', quantity: '100', location: 'C2-D1' }
        ]),
        createdAt: Date.now() - (7 * 24 * 60 * 60 * 1000), // 7 days ago
        receivedAt: Date.now() - (7 * 24 * 60 * 60 * 1000),
        status: 'received'
    },
    {
        transactionId: 'TXN-SEED-002',
        poNumber: 'PO-20260312-045',
        vendor: 'Global Parts Supplier Ltd',
        lineItems: JSON.stringify([
            { sku: 'BLT-M8', description: 'M8 Bolt 50mm', quantity: '500', location: 'F3-G2' },
            { sku: 'NUT-M8', description: 'M8 Nut', quantity: '500', location: 'F3-G3' }
        ]),
        createdAt: Date.now() - (5 * 24 * 60 * 60 * 1000), // 5 days ago
        receivedAt: Date.now() - (5 * 24 * 60 * 60 * 1000),
        status: 'received'
    },
    {
        transactionId: 'TXN-SEED-003',
        poNumber: 'PO-20260314-102',
        vendor: 'Premium Electronics Inc',
        lineItems: JSON.stringify([
            { sku: 'PCB-A100', description: 'Circuit Board A100', quantity: '25', location: 'H1-J2' },
            { sku: 'CAP-470', description: 'Capacitor 470uF', quantity: '200', location: 'H1-J3' },
            { sku: 'RES-10K', description: 'Resistor 10K Ohm', quantity: '500', location: 'H1-J4' },
            { sku: 'LED-RED', description: 'Red LED 5mm', quantity: '100', location: 'H2-J1' }
        ]),
        createdAt: Date.now() - (3 * 24 * 60 * 60 * 1000), // 3 days ago
        receivedAt: Date.now() - (3 * 24 * 60 * 60 * 1000),
        status: 'received'
    },
    {
        transactionId: 'TXN-SEED-004',
        poNumber: 'PO-20260316-078',
        vendor: 'Industrial Supplies Co',
        lineItems: JSON.stringify([
            { sku: 'STL-PLATE', description: 'Steel Plate 1m x 2m', quantity: '10', location: 'K1-L1' },
            { sku: 'WLD-ROD', description: 'Welding Rod 3mm', quantity: '50', location: 'K2-L2' }
        ]),
        createdAt: Date.now() - (2 * 24 * 60 * 60 * 1000), // 2 days ago
        receivedAt: Date.now() - (2 * 24 * 60 * 60 * 1000),
        status: 'received'
    },
    {
        transactionId: 'TXN-SEED-005',
        poNumber: 'PO-20260317-199',
        vendor: 'Quick Ship Logistics',
        lineItems: JSON.stringify([
            { sku: 'BOX-SML', description: 'Small Cardboard Box', quantity: '100', location: 'M1-N1' },
            { sku: 'BOX-MED', description: 'Medium Cardboard Box', quantity: '50', location: 'M1-N2' },
            { sku: 'TAPE-PKG', description: 'Packaging Tape Roll', quantity: '20', location: 'M2-N1' },
            { sku: 'LBL-SHIP', description: 'Shipping Labels', quantity: '500', location: 'M2-N2' }
        ]),
        createdAt: Date.now() - (1 * 24 * 60 * 60 * 1000), // 1 day ago
        receivedAt: Date.now() - (1 * 24 * 60 * 60 * 1000),
        status: 'received'
    }
];

// Insert products first
console.log('📦 Seeding products...\n');

const insertProductStmt = db.prepare(`
    INSERT OR IGNORE INTO products
    (sku, barcode, name, description, default_location)
    VALUES (?, ?, ?, ?, ?)
`);

let productsInserted = 0;
let productsProcessed = 0;

seedProducts.forEach((product) => {
    insertProductStmt.run(
        product.sku,
        product.barcode,
        product.name,
        product.description,
        product.default_location,
        function(err) {
            if (err) {
                console.error(`❌ Failed to insert product ${product.sku}:`, err.message);
            } else {
                if (this.changes > 0) {
                    productsInserted++;
                    console.log(`✅ ${product.sku} (barcode: ${product.barcode})`);
                } else {
                    console.log(`⏭️  ${product.sku} (already exists)`);
                }
            }

            productsProcessed++;
            if (productsProcessed === seedProducts.length) {
                insertProductStmt.finalize();
                console.log('\n📊 Products: ' + productsInserted + ' inserted, ' +
                           (seedProducts.length - productsInserted) + ' skipped\n');

                // Now insert transactions
                insertTransactions();
            }
        }
    );
});

// Insert transaction seed data
function insertTransactions() {
    console.log('📋 Seeding transactions...\n');

    const insertStmt = db.prepare(`
        INSERT OR IGNORE INTO transactions
        (transaction_id, po_number, vendor, line_items, created_at, received_at, status)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    let insertedCount = 0;
    let processed = 0;

    seedTransactions.forEach((tx) => {
        insertStmt.run(
            tx.transactionId,
            tx.poNumber,
            tx.vendor,
            tx.lineItems,
            tx.createdAt,
            tx.receivedAt,
            tx.status,
            function(err) {
                if (err) {
                    console.error(`❌ Failed to insert ${tx.transactionId}:`, err.message);
                } else {
                    if (this.changes > 0) {
                        insertedCount++;
                        const items = JSON.parse(tx.lineItems);
                        console.log(`✅ ${tx.transactionId}`);
                        console.log(`   PO: ${tx.poNumber}`);
                        console.log(`   Vendor: ${tx.vendor}`);
                        console.log(`   Items: ${items.length}`);
                        console.log('');
                    } else {
                        console.log(`⏭️  ${tx.transactionId} (already exists)`);
                    }
                }

                processed++;
                if (processed === seedTransactions.length) {
                    finalize(insertedCount);
                }
            }
        );
    });

    function finalize(transactionCount) {
        insertStmt.finalize();

        // Summary
        const skippedCount = seedTransactions.length - transactionCount;
        console.log('─────────────────────────────────────');
        console.log(`✅ Transactions Inserted: ${transactionCount}`);
        console.log(`⏭️  Transactions Skipped: ${skippedCount}`);
        console.log('─────────────────────────────────────');

        // Verify total counts
        db.get('SELECT COUNT(*) as count FROM transactions', (err, row) => {
            if (err) {
                console.error('Error counting transactions:', err.message);
            } else {
                console.log(`📊 Total transactions in database: ${row.count}`);
            }

            db.get('SELECT COUNT(*) as count FROM products', (err2, row2) => {
                if (err2) {
                    console.error('Error counting products:', err2.message);
                } else {
                    console.log(`📦 Total products in database: ${row2.count}`);
                }
                console.log('');
                console.log('🎉 Seed complete!\n');
                db.close();
            });
        });
    }
}

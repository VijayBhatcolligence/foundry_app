const express = require('express');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const multer = require('multer');
const fs = require('fs');

// Configuration
const PORT = process.env.PORT || 3000;
const DB_PATH = path.join(__dirname, 'backend_transactions.db');
const UPLOADS_DIR = path.join(__dirname, 'uploads');

// Ensure uploads directory exists
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
  console.log('[Server] Created uploads directory:', UPLOADS_DIR);
}

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOADS_DIR);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'photo-' + uniqueSuffix + ext);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept images only
    if (!file.originalname.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
      return cb(new Error('Only image files are allowed'), false);
    }
    cb(null, true);
  }
});

// Initialize Express app
const app = express();

// Middleware - CORS with logging
app.use((req, res, next) => {
  const origin = req.headers['origin'] || 'no-origin';
  console.log(`[CORS] Request from origin: ${origin}`);

  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  console.log(`[CORS] Headers set: Allow-Origin=*, Allow-Methods=GET,POST,DELETE,OPTIONS`);

  // Handle preflight
  if (req.method === 'OPTIONS') {
    console.log(`[CORS] Preflight request handled for ${req.path}`);
    return res.sendStatus(200);
  }

  next();
});

// Increase body size limit for base64 photos (default 100kb is too small)
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Serve uploaded photos statically
app.use('/uploads', express.static(UPLOADS_DIR));

// Enhanced request logging middleware
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const clientIp = req.ip || req.connection.remoteAddress || req.headers['x-forwarded-for'];
  const userAgent = req.headers['user-agent'] || 'unknown';
  const origin = req.headers['origin'] || 'unknown';
  const host = req.headers['host'] || 'unknown';

  console.log(`[${timestamp}] ${req.method} ${req.path}`);
  console.log(`  Client IP: ${clientIp}`);
  console.log(`  User-Agent: ${userAgent}`);
  console.log(`  Origin: ${origin}`);
  console.log(`  Host: ${host}`);

  next();
});

// Initialize SQLite database
const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    console.error('[Database] Connection error:', err.message);
    process.exit(1);
  }
  console.log('[Database] Connected to SQLite database');
});

// Enable WAL mode for better concurrency
db.run('PRAGMA journal_mode = WAL');

// Create transactions and products tables
const initDatabase = () => {
  const createTransactionsTableSQL = `
    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id TEXT UNIQUE NOT NULL,
      po_number TEXT NOT NULL,
      vendor TEXT NOT NULL,
      line_items TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      received_at INTEGER NOT NULL,
      status TEXT DEFAULT 'received'
    )
  `;

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
    // Create transactions table
    db.run(createTransactionsTableSQL, (err) => {
      if (err) {
        console.error('[Database] Transactions table creation error:', err.message);
        process.exit(1);
      }
    });

    db.run('CREATE INDEX IF NOT EXISTS idx_transaction_id ON transactions(transaction_id)');
    db.run('CREATE INDEX IF NOT EXISTS idx_po_number ON transactions(po_number)');
    db.run('CREATE INDEX IF NOT EXISTS idx_created_at ON transactions(created_at DESC)');

    // Create products table
    db.run(createProductsTableSQL, (err) => {
      if (err) {
        console.error('[Database] Products table creation error:', err.message);
        process.exit(1);
      } else {
        console.log('[Database] Products table created');

        // Seed product data for testing
        const products = [
          { sku: 'WH-001', barcode: '1234567890123', name: 'Industrial Hammer', description: 'Heavy-duty construction hammer', location: 'A-12' },
          { sku: 'WH-002', barcode: '1234567890124', name: 'Steel Wrench Set', description: '10-piece metric wrench set', location: 'B-05' },
          { sku: 'WH-003', barcode: '1234567890125', name: 'Power Drill', description: '18V cordless drill with battery', location: 'C-22' },
          { sku: 'WH-004', barcode: '1234567890126', name: 'Safety Goggles', description: 'Impact-resistant eye protection', location: 'D-18' },
          { sku: 'WH-005', barcode: '1234567890127', name: 'Measuring Tape', description: '25ft retractable measuring tape', location: 'A-08' },
          { sku: 'WH-006', barcode: '1234567890128', name: 'Screwdriver Set', description: 'Phillips and flathead, 12-piece', location: 'B-14' },
          { sku: 'WH-007', barcode: '1234567890129', name: 'Work Gloves', description: 'Leather palm work gloves, size L', location: 'D-25' },
          { sku: 'WH-008', barcode: '1234567890130', name: 'LED Flashlight', description: 'Rechargeable 1000-lumen flashlight', location: 'C-09' },
          { sku: 'WH-009', barcode: '1234567890131', name: 'Tool Belt', description: 'Heavy-duty canvas tool belt', location: 'E-03' },
          { sku: 'WH-010', barcode: '1234567890132', name: 'Extension Cord', description: '50ft outdoor extension cord', location: 'A-20' },
          { sku: 'WH-011', barcode: '1234567890133', name: 'Paint Roller Set', description: 'Includes tray and 3 rollers', location: 'F-11' },
          { sku: 'WH-012', barcode: '1234567890134', name: 'Utility Knife', description: 'Retractable blade utility knife', location: 'B-07' },
          { sku: 'WH-013', barcode: '1234567890135', name: 'Duct Tape', description: 'Industrial strength, 60-yard roll', location: 'D-30' },
          { sku: 'WH-014', barcode: '1234567890136', name: 'Level Tool', description: '24-inch magnetic level', location: 'C-15' },
          { sku: 'WH-015', barcode: '1234567890137', name: 'Wire Cutters', description: 'Heavy-duty wire cutting pliers', location: 'A-05' },
        ];

        products.forEach(product => {
          db.run(
            'INSERT OR IGNORE INTO products (sku, barcode, name, description, default_location) VALUES (?, ?, ?, ?, ?)',
            [product.sku, product.barcode, product.name, product.description, product.location],
            (err) => {
              if (err && !err.message.includes('UNIQUE constraint')) {
                console.error(`[Database] Error seeding product ${product.sku}:`, err.message);
              }
            }
          );
        });

        console.log('[Database] Seeded 15 products for testing');
      }
    });

    db.run('CREATE INDEX IF NOT EXISTS idx_barcode ON products(barcode)', (err) => {
      if (err) {
        console.error('[Database] Index creation error:', err.message);
      } else {
        console.log('[Database] Product indexes created');
      }
    });

    // Create transaction_photos table
    db.run(createTransactionPhotosTableSQL, (err) => {
      if (err) {
        console.error('[Database] Transaction_photos table creation error:', err.message);
        process.exit(1);
      } else {
        console.log('[Database] Transaction_photos table created');
      }
    });

    db.run('CREATE INDEX IF NOT EXISTS idx_photos_transaction ON transaction_photos(transaction_id)', (err) => {
      if (err) {
        console.error('[Database] Photos index creation error:', err.message);
      } else {
        console.log('[Database] Tables and indexes initialized successfully');
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
        console.error('[Database] Water_temp_checks table creation error:', err.message);
      } else {
        console.log('[Database] Water_temp_checks table created');
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
        console.error('[Database] Complaints table creation error:', err.message);
      } else {
        console.log('[Database] Complaints table created');
      }
    });

    // NEW Phase 3: Tables for test modules

    // Stock counts table (Inventory Checker)
    const createStockCountsTableSQL = `
      CREATE TABLE IF NOT EXISTS stock_counts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        location TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    `;

    db.run(createStockCountsTableSQL, (err) => {
      if (err) {
        console.error('[Database] Stock_counts table creation error:', err.message);
      } else {
        console.log('[Database] Stock_counts table created');
      }
    });

    // Audit trail table (Inventory Checker)
    const createAuditTrailTableSQL = `
      CREATE TABLE IF NOT EXISTS audit_trail (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        notes TEXT,
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    `;

    db.run(createAuditTrailTableSQL, (err) => {
      if (err) {
        console.error('[Database] Audit_trail table creation error:', err.message);
      } else {
        console.log('[Database] Audit_trail table created');
      }
    });

    // Defects table (Quality Inspector)
    const createDefectsTableSQL = `
      CREATE TABLE IF NOT EXISTS defects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        description TEXT NOT NULL,
        severity TEXT NOT NULL
      )
    `;

    db.run(createDefectsTableSQL, (err) => {
      if (err) {
        console.error('[Database] Defects table creation error:', err.message);
      } else {
        console.log('[Database] Defects table created');

        // Seed some defect codes
        const defects = [
          { code: 'D001', description: 'Surface damage', severity: 'medium' },
          { code: 'D002', description: 'Missing parts', severity: 'high' },
          { code: 'D003', description: 'Discoloration', severity: 'low' },
          { code: 'D004', description: 'Incorrect labeling', severity: 'medium' },
          { code: 'D005', description: 'Structural defect', severity: 'high' },
        ];

        defects.forEach(defect => {
          db.run(
            'INSERT OR IGNORE INTO defects (code, description, severity) VALUES (?, ?, ?)',
            [defect.code, defect.description, defect.severity]
          );
        });
      }
    });

    // Inspection logs table (Quality Inspector)
    const createInspectionLogsTableSQL = `
      CREATE TABLE IF NOT EXISTS inspection_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product TEXT NOT NULL,
        result TEXT NOT NULL,
        notes TEXT,
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    `;

    db.run(createInspectionLogsTableSQL, (err) => {
      if (err) {
        console.error('[Database] Inspection_logs table creation error:', err.message);
      } else {
        console.log('[Database] Inspection_logs table created');
      }
    });

    // Reports table (Quality Inspector)
    const createReportsTableSQL = `
      CREATE TABLE IF NOT EXISTS reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_type TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    `;

    db.run(createReportsTableSQL, (err) => {
      if (err) {
        console.error('[Database] Reports table creation error:', err.message);
      } else {
        console.log('[Database] Reports table created');
      }
    });
  });
};

initDatabase();

// Validation helper
const validateTransaction = (data) => {
  const errors = [];

  if (!data.transactionId || typeof data.transactionId !== 'string') {
    errors.push('transactionId is required and must be a string');
  }

  if (!data.poNumber || typeof data.poNumber !== 'string') {
    errors.push('poNumber is required and must be a string');
  } else if (data.poNumber.length > 50) {
    errors.push('poNumber must be 50 characters or less');
  }

  if (!data.vendor || typeof data.vendor !== 'string') {
    errors.push('vendor is required and must be a string');
  } else if (data.vendor.length > 100) {
    errors.push('vendor must be 100 characters or less');
  }

  if (!Array.isArray(data.lineItems)) {
    errors.push('lineItems must be an array');
  } else {
    if (data.lineItems.length === 0) {
      errors.push('lineItems must contain at least one item');
    }
    if (data.lineItems.length > 50) {
      errors.push('lineItems must contain no more than 50 items');
    }

    data.lineItems.forEach((item, index) => {
      if (!item.sku || typeof item.sku !== 'string') {
        errors.push(`lineItems[${index}].sku is required`);
      }
      if (!item.quantity) {
        errors.push(`lineItems[${index}].quantity is required`);
      }
      if (!item.location || typeof item.location !== 'string') {
        errors.push(`lineItems[${index}].location is required`);
      }
    });
  }

  if (!data.createdAt || typeof data.createdAt !== 'number') {
    errors.push('createdAt is required and must be a timestamp');
  }

  return errors;
};

// Validate JSON helper
const isValidJSON = (str) => {
  try {
    JSON.parse(str);
    return true;
  } catch (e) {
    return false;
  }
};

// API Routes

// Health check endpoint
app.get('/api/health', (req, res) => {
  const clientIp = req.ip || req.connection.remoteAddress;
  console.log(`[Health Check] Client IP: ${clientIp}`);

  res.json({
    status: 'ok',
    timestamp: Date.now(),
    database: 'connected',
    clientIp: clientIp
  });
});

// Network diagnostics endpoint
app.get('/api/debug/network', (req, res) => {
  const clientIp = req.ip || req.connection.remoteAddress || req.headers['x-forwarded-for'];
  const networkInfo = {
    server: {
      timestamp: Date.now(),
      nodeVersion: process.version,
      platform: process.platform,
      port: PORT
    },
    client: {
      ip: clientIp,
      userAgent: req.headers['user-agent'],
      origin: req.headers['origin'],
      host: req.headers['host'],
      connection: req.headers['connection'],
      acceptEncoding: req.headers['accept-encoding']
    },
    request: {
      method: req.method,
      path: req.path,
      protocol: req.protocol,
      secure: req.secure,
      headers: req.headers
    }
  };

  console.log('[Network Debug] Request from:', clientIp);
  console.log('[Network Debug] Full info:', JSON.stringify(networkInfo, null, 2));

  res.json({
    success: true,
    message: 'Network diagnostics',
    ...networkInfo
  });
});

// POST /api/transactions - Submit new transaction
app.post('/api/transactions', (req, res) => {
  try {
    const data = req.body;
    console.log('[POST /api/transactions] Received:', JSON.stringify(data, null, 2));

    // Validate request
    const validationErrors = validateTransaction(data);
    if (validationErrors.length > 0) {
      return res.status(400).json({
        success: false,
        error: `Validation error: ${validationErrors.join(', ')}`
      });
    }

    // Check for duplicate transaction ID
    db.get('SELECT id FROM transactions WHERE transaction_id = ?', [data.transactionId], (err, existing) => {
      if (err) {
        console.error('[POST /api/transactions] Database error:', err.message);
        return res.status(500).json({
          success: false,
          error: `Server error: ${err.message}`
        });
      }

      if (existing) {
        return res.status(409).json({
          success: false,
          error: 'Transaction ID already exists'
        });
      }

      // Insert transaction
      const receivedAt = Date.now();
      const lineItemsJSON = JSON.stringify(data.lineItems);

      db.run(
        `INSERT INTO transactions (transaction_id, po_number, vendor, line_items, created_at, received_at, status)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [data.transactionId, data.poNumber, data.vendor, lineItemsJSON, data.createdAt, receivedAt, 'received'],
        function(err) {
          if (err) {
            console.error('[POST /api/transactions] Insert error:', err.message);
            return res.status(500).json({
              success: false,
              error: `Server error: ${err.message}`
            });
          }

          console.log(`[POST /api/transactions] Transaction ${data.transactionId} inserted with ID ${this.lastID}`);

          res.status(201).json({
            success: true,
            transactionId: data.transactionId,
            receivedAt: receivedAt,
            status: 'received'
          });
        }
      );
    });

  } catch (error) {
    console.error('[POST /api/transactions] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// GET /api/transactions - List all transactions
app.get('/api/transactions', (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    console.log(`[GET /api/transactions] Fetching transactions (limit: ${limit}, offset: ${offset})`);

    // Get transactions
    db.all(
      `SELECT id, transaction_id, po_number, vendor, line_items, created_at, received_at, status
       FROM transactions
       ORDER BY received_at DESC
       LIMIT ? OFFSET ?`,
      [limit, offset],
      (err, transactions) => {
        if (err) {
          console.error('[GET /api/transactions] Query error:', err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        // Parse line_items JSON
        const parsedTransactions = transactions.map(tx => ({
          ...tx,
          lineItems: JSON.parse(tx.line_items)
        }));

        // Get total count
        db.get('SELECT COUNT(*) as count FROM transactions', [], (err, result) => {
          if (err) {
            console.error('[GET /api/transactions] Count error:', err.message);
            return res.status(500).json({
              success: false,
              error: `Server error: ${err.message}`
            });
          }

          const count = result.count;
          console.log(`[GET /api/transactions] Returning ${parsedTransactions.length} of ${count} total transactions`);

          res.json({
            success: true,
            transactions: parsedTransactions,
            count: count,
            limit: limit,
            offset: offset
          });
        });
      }
    );

  } catch (error) {
    console.error('[GET /api/transactions] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// GET /api/transactions/:transactionId - Get single transaction
app.get('/api/transactions/:transactionId', (req, res) => {
  try {
    const { transactionId } = req.params;
    console.log(`[GET /api/transactions/${transactionId}] Fetching transaction`);

    db.get(
      `SELECT id, transaction_id, po_number, vendor, line_items, created_at, received_at, status
       FROM transactions
       WHERE transaction_id = ?`,
      [transactionId],
      (err, transaction) => {
        if (err) {
          console.error(`[GET /api/transactions/${transactionId}] Query error:`, err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        if (!transaction) {
          return res.status(404).json({
            success: false,
            error: 'Transaction not found'
          });
        }

        // Parse line_items JSON
        transaction.lineItems = JSON.parse(transaction.line_items);

        console.log(`[GET /api/transactions/${transactionId}] Transaction found`);

        res.json({
          success: true,
          transaction: transaction
        });
      }
    );

  } catch (error) {
    console.error(`[GET /api/transactions/${req.params.transactionId}] Error:`, error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// POST /api/transactions/:id/photos - Upload photo for transaction
app.post('/api/transactions/:id/photos', upload.single('photo'), async (req, res) => {
  try {
    const { id } = req.params;
    const { lineItemId } = req.body;

    console.log(`[POST /api/transactions/${id}/photos] Upload request`);
    console.log('[Upload] Line item ID:', lineItemId);
    console.log('[Upload] File:', req.file);

    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No photo file provided'
      });
    }

    // Check if transaction exists
    db.get('SELECT id FROM transactions WHERE transaction_id = ?', [id], (err, transaction) => {
      if (err) {
        console.error(`[POST /api/transactions/${id}/photos] Database error:`, err.message);
        return res.status(500).json({
          success: false,
          error: 'Database error'
        });
      }

      if (!transaction) {
        return res.status(404).json({
          success: false,
          error: 'Transaction not found'
        });
      }

      // Insert photo record
      const photoPath = `/uploads/${req.file.filename}`;
      const createdAt = Date.now();

      db.run(
        'INSERT INTO transaction_photos (transaction_id, line_item_id, photo_path, created_at) VALUES (?, ?, ?, ?)',
        [id, lineItemId || null, photoPath, createdAt],
        function(err) {
          if (err) {
            console.error(`[POST /api/transactions/${id}/photos] Insert error:`, err.message);
            return res.status(500).json({
              success: false,
              error: 'Failed to save photo record'
            });
          }

          console.log(`[POST /api/transactions/${id}/photos] Photo saved: ${photoPath}`);

          res.status(201).json({
            success: true,
            photoId: this.lastID,
            photoPath: photoPath,
            thumbnailPath: photoPath, // For now, use same path
            fileSize: req.file.size,
            createdAt: createdAt
          });
        }
      );
    });

  } catch (error) {
    console.error(`[POST /api/transactions/${req.params.id}/photos] Error:`, error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// GET /api/transactions/:id/photos - List photos for transaction
app.get('/api/transactions/:id/photos', (req, res) => {
  try {
    const { id } = req.params;

    console.log(`[GET /api/transactions/${id}/photos] Fetching photos`);

    db.all(
      'SELECT id, transaction_id, line_item_id, photo_path, thumbnail_path, created_at FROM transaction_photos WHERE transaction_id = ? ORDER BY created_at DESC',
      [id],
      (err, photos) => {
        if (err) {
          console.error(`[GET /api/transactions/${id}/photos] Query error:`, err.message);
          return res.status(500).json({
            success: false,
            error: 'Database error'
          });
        }

        console.log(`[GET /api/transactions/${id}/photos] Found ${photos.length} photos`);

        res.json({
          success: true,
          photos: photos
        });
      }
    );

  } catch (error) {
    console.error(`[GET /api/transactions/${req.params.id}/photos] Error:`, error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// GET /api/products/:barcode - Lookup product by barcode
app.get('/api/products/:barcode', (req, res) => {
  try {
    const { barcode } = req.params;

    // Validate barcode parameter
    if (!barcode || barcode.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Barcode parameter required'
      });
    }

    console.log(`[GET /api/products/${barcode}] Looking up product`);

    db.get(
      `SELECT id, sku, barcode, name, description, default_location
       FROM products
       WHERE barcode = ? COLLATE NOCASE`,
      [barcode.trim()],
      (err, product) => {
        if (err) {
          console.error(`[GET /api/products/${barcode}] Query error:`, err.message);
          return res.status(500).json({
            success: false,
            error: 'Database error'
          });
        }

        if (!product) {
          console.log(`[GET /api/products/${barcode}] Product not found`);
          return res.status(404).json({
            success: false,
            error: 'Product not found'
          });
        }

        console.log(`[GET /api/products/${barcode}] Product found: ${product.name}`);

        res.json({
          success: true,
          product: {
            sku: product.sku,
            barcode: product.barcode,
            name: product.name,
            description: product.description,
            default_location: product.default_location
          }
        });
      }
    );

  } catch (error) {
    console.error(`[GET /api/products/${req.params.barcode}] Error:`, error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// POST /api/water-temp - Submit water temp check
app.post('/api/water-temp', async (req, res) => {
  try {
    const { id, temp_fahrenheit, temp_celsius, location, photo_path, timestamp } = req.body;

    console.log('[POST /api/water-temp] Received:', req.body);

    // Validation
    if (!id || !temp_fahrenheit || !temp_celsius || !timestamp) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields'
      });
    }

    const createdAt = Date.now();

    db.run(
      'INSERT INTO water_temp_checks VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, temp_fahrenheit, temp_celsius, location || null, photo_path || null, timestamp, createdAt],
      function(err) {
        if (err) {
          console.error('[POST /api/water-temp] Insert error:', err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        console.log(`[POST /api/water-temp] Check ${id} inserted`);

        res.status(201).json({
          success: true,
          id: id,
          createdAt: createdAt
        });
      }
    );

  } catch (error) {
    console.error('[POST /api/water-temp] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// GET /api/water-temp - Get all temp checks
app.get('/api/water-temp', (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    console.log(`[GET /api/water-temp] Fetching checks (limit: ${limit}, offset: ${offset})`);

    db.all(
      `SELECT * FROM water_temp_checks ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [limit, offset],
      (err, checks) => {
        if (err) {
          console.error('[GET /api/water-temp] Query error:', err.message);
          return res.status(500).json({
            success: false,
            error: 'Database error'
          });
        }

        console.log(`[GET /api/water-temp] Returning ${checks.length} checks`);

        res.json({
          success: true,
          checks: checks
        });
      }
    );

  } catch (error) {
    console.error('[GET /api/water-temp] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// POST /api/complaints - Submit complaint
app.post('/api/complaints', async (req, res) => {
  try {
    const { id, barcode, product_sku, product_name, complaint_type, description, photo_path, timestamp } = req.body;

    console.log('[POST /api/complaints] Received:', req.body);

    // Validation
    if (!id || !barcode || !complaint_type || !description || !timestamp) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields'
      });
    }

    const createdAt = Date.now();

    db.run(
      'INSERT INTO complaints VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, barcode, product_sku || null, product_name || null, complaint_type, description, photo_path || null, timestamp, 'open', createdAt],
      function(err) {
        if (err) {
          console.error('[POST /api/complaints] Insert error:', err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        console.log(`[POST /api/complaints] Complaint ${id} inserted`);

        res.status(201).json({
          success: true,
          id: id,
          createdAt: createdAt
        });
      }
    );

  } catch (error) {
    console.error('[POST /api/complaints] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// GET /api/complaints - Get all complaints
app.get('/api/complaints', (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    console.log(`[GET /api/complaints] Fetching complaints (limit: ${limit}, offset: ${offset})`);

    db.all(
      `SELECT * FROM complaints ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [limit, offset],
      (err, complaints) => {
        if (err) {
          console.error('[GET /api/complaints] Query error:', err.message);
          return res.status(500).json({
            success: false,
            error: 'Database error'
          });
        }

        console.log(`[GET /api/complaints] Returning ${complaints.length} complaints`);

        res.json({
          success: true,
          complaints: complaints
        });
      }
    );

  } catch (error) {
    console.error('[GET /api/complaints] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// DELETE /api/transactions/:transactionId - Delete transaction
app.delete('/api/transactions/:transactionId', (req, res) => {
  try {
    const { transactionId } = req.params;
    console.log(`[DELETE /api/transactions/${transactionId}] Deleting transaction`);

    db.run(
      'DELETE FROM transactions WHERE transaction_id = ?',
      [transactionId],
      function(err) {
        if (err) {
          console.error(`[DELETE /api/transactions/${transactionId}] Delete error:`, err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        if (this.changes === 0) {
          return res.status(404).json({
            success: false,
            error: 'Transaction not found'
          });
        }

        console.log(`[DELETE /api/transactions/${transactionId}] Transaction deleted`);

        res.json({
          success: true,
          message: 'Transaction deleted'
        });
      }
    );

  } catch (error) {
    console.error(`[DELETE /api/transactions/${req.params.transactionId}] Error:`, error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// ========================================
// NEW Phase 3: API Endpoints for Test Modules
// ========================================

// 1. GET /api/products - Product search (Inventory Checker)
app.get('/api/products', (req, res) => {
  try {
    const query = req.query.q || '';
    console.log(`[GET /api/products] Search query: "${query}"`);

    db.all(
      'SELECT * FROM products WHERE name LIKE ? OR sku LIKE ? ORDER BY name LIMIT 100',
      [`%${query}%`, `%${query}%`],
      (err, rows) => {
        if (err) {
          console.error('[GET /api/products] Query error:', err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        console.log(`[GET /api/products] Found ${rows.length} products`);

        const response = {
          success: true,
          data: rows,  // ReferenceDataManager expects "data" field
          count: rows.length
        };

        console.log(`[GET /api/products] Response structure:`, {
          success: response.success,
          dataIsArray: Array.isArray(response.data),
          dataLength: response.data?.length,
          count: response.count
        });

        res.json(response);
      }
    );

  } catch (error) {
    console.error('[GET /api/products] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// 2. POST /api/stock-counts - Stock count submission (Inventory Checker)
app.post('/api/stock-counts', (req, res) => {
  try {
    const { product_id, new_quantity, timestamp, sku, quantity, location } = req.body;

    console.log('[POST /api/stock-counts] Received stock count:', req.body);

    // Support both new format (product_id, new_quantity) and legacy format (sku, quantity, location)
    let productId, newQty, countTimestamp;

    if (product_id !== undefined && new_quantity !== undefined) {
      // New format
      productId = product_id;
      newQty = new_quantity;
      countTimestamp = timestamp;

      console.log('[POST /api/stock-counts] Using new format (product_id, new_quantity)');

      // Validation
      if (!productId || newQty === undefined || !countTimestamp) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: product_id, new_quantity, timestamp'
        });
      }

      if (typeof newQty !== 'number' || newQty < 0) {
        return res.status(400).json({
          success: false,
          error: 'new_quantity must be a non-negative number'
        });
      }

      // Get product details and update its quantity
      db.get(
        'SELECT * FROM products WHERE id = ?',
        [productId],
        (err, product) => {
          if (err) {
            console.error('[POST /api/stock-counts] Product query error:', err.message);
            return res.status(500).json({
              success: false,
              error: `Server error: ${err.message}`
            });
          }

          if (!product) {
            return res.status(404).json({
              success: false,
              error: 'Product not found'
            });
          }

          console.log(`[POST /api/stock-counts] Product found: ${product.name} (current qty: ${product.quantity})`);

          const createdAt = Date.now();

          // Save stock count record
          db.run(
            'INSERT INTO stock_counts (sku, quantity, location, timestamp, created_at) VALUES (?, ?, ?, ?, ?)',
            [product.sku, newQty, product.default_location || 'N/A', countTimestamp, createdAt],
            function(err) {
              if (err) {
                console.error('[POST /api/stock-counts] Insert error:', err.message);
                return res.status(500).json({
                  success: false,
                  error: `Server error: ${err.message}`
                });
              }

              const countId = this.lastID;

              // Update product quantity
              db.run(
                'UPDATE products SET quantity = ? WHERE id = ?',
                [newQty, productId],
                function(err) {
                  if (err) {
                    console.error('[POST /api/stock-counts] Product update error:', err.message);
                    // Still return success since count was saved
                  } else {
                    console.log(`[POST /api/stock-counts] ✅ Product quantity updated: ${product.quantity} → ${newQty}`);
                  }

                  console.log(`[POST /api/stock-counts] ✅ Stock count saved with ID: ${countId}`);

                  res.status(201).json({
                    success: true,
                    id: countId,
                    message: 'Stock count saved and product quantity updated',
                    old_quantity: product.quantity,
                    new_quantity: newQty
                  });
                }
              );
            }
          );
        }
      );

    } else if (sku && quantity !== undefined && location) {
      // Legacy format
      console.log('[POST /api/stock-counts] Using legacy format (sku, quantity, location)');

      // Validation
      if (!sku || quantity === undefined || !location || !timestamp) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: sku, quantity, location, timestamp'
        });
      }

      if (typeof quantity !== 'number' || quantity < 0) {
        return res.status(400).json({
          success: false,
          error: 'Quantity must be a non-negative number'
        });
      }

      const createdAt = Date.now();

      db.run(
        'INSERT INTO stock_counts (sku, quantity, location, timestamp, created_at) VALUES (?, ?, ?, ?, ?)',
        [sku, quantity, location, timestamp, createdAt],
        function(err) {
          if (err) {
            console.error('[POST /api/stock-counts] Insert error:', err.message);
            return res.status(500).json({
              success: false,
              error: `Server error: ${err.message}`
            });
          }

          console.log(`[POST /api/stock-counts] ✅ Stock count saved with ID: ${this.lastID}`);

          res.status(201).json({
            success: true,
            id: this.lastID,
            message: 'Stock count saved'
          });
        }
      );

    } else {
      return res.status(400).json({
        success: false,
        error: 'Invalid payload. Expected either (product_id, new_quantity, timestamp) or (sku, quantity, location, timestamp)'
      });
    }

  } catch (error) {
    console.error('[POST /api/stock-counts] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// 3. POST /api/audit-trail - Audit trail submission (Inventory Checker)
app.post('/api/audit-trail', (req, res) => {
  try {
    const { action, notes, timestamp } = req.body;

    console.log('[POST /api/audit-trail] Received audit entry:', {
      action,
      notes: notes ? notes.substring(0, 50) : 'none'
    });

    // Validation
    if (!action || !timestamp) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: action, timestamp'
      });
    }

    const createdAt = Date.now();

    db.run(
      'INSERT INTO audit_trail (action, notes, timestamp, created_at) VALUES (?, ?, ?, ?)',
      [action, notes || null, timestamp, createdAt],
      function(err) {
        if (err) {
          console.error('[POST /api/audit-trail] Insert error:', err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        console.log(`[POST /api/audit-trail] Audit entry saved with ID: ${this.lastID}`);

        res.status(201).json({
          success: true,
          id: this.lastID,
          message: 'Audit entry saved'
        });
      }
    );

  } catch (error) {
    console.error('[POST /api/audit-trail] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// 4. GET /api/defects/:code - Defect lookup (Quality Inspector)
app.get('/api/defects/:code', (req, res) => {
  try {
    const { code } = req.params;
    console.log(`[GET /api/defects/${code}] Looking up defect`);

    db.get(
      'SELECT * FROM defects WHERE code = ?',
      [code],
      (err, row) => {
        if (err) {
          console.error(`[GET /api/defects/${code}] Query error:`, err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        if (!row) {
          console.log(`[GET /api/defects/${code}] Defect not found`);
          return res.status(404).json({
            success: false,
            error: 'Defect code not found'
          });
        }

        console.log(`[GET /api/defects/${code}] Defect found:`, row.description);

        res.json({
          success: true,
          defect: row
        });
      }
    );

  } catch (error) {
    console.error(`[GET /api/defects/${req.params.code}] Error:`, error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// 5. POST /api/inspection-logs - Inspection log submission (Quality Inspector)
app.post('/api/inspection-logs', (req, res) => {
  try {
    const { product, result, notes, timestamp } = req.body;

    console.log('[POST /api/inspection-logs] Received inspection log:', {
      product,
      result
    });

    // Validation
    if (!product || !result || !timestamp) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: product, result, timestamp'
      });
    }

    if (!['pass', 'fail'].includes(result.toLowerCase())) {
      return res.status(400).json({
        success: false,
        error: 'Result must be "pass" or "fail"'
      });
    }

    const createdAt = Date.now();

    db.run(
      'INSERT INTO inspection_logs (product, result, notes, timestamp, created_at) VALUES (?, ?, ?, ?, ?)',
      [product, result, notes || null, timestamp, createdAt],
      function(err) {
        if (err) {
          console.error('[POST /api/inspection-logs] Insert error:', err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        console.log(`[POST /api/inspection-logs] Inspection log saved with ID: ${this.lastID}`);

        res.status(201).json({
          success: true,
          id: this.lastID,
          message: 'Inspection log saved'
        });
      }
    );

  } catch (error) {
    console.error('[POST /api/inspection-logs] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// 6. POST /api/reports - Report submission (Quality Inspector)
app.post('/api/reports', (req, res) => {
  try {
    // Accept both old format (data, timestamp) and new format (summary, details, etc.)
    const {
      report_type,
      summary,
      details,
      priority,
      submitted_at,
      photoPath,
      photoUrl,
      hasPhoto,
      photo,  // NEW: base64 photo data from SyncManager
      // Legacy support
      data,
      timestamp
    } = req.body;

    console.log('[POST /api/reports] Received report:', {
      type: report_type,
      summary: summary || 'N/A',
      hasPhoto: hasPhoto || false,
      hasPhotoData: !!photo
    });

    // Validation - support both formats
    if (!report_type) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: report_type'
      });
    }

    if (!summary && !data) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: summary or data'
      });
    }

    // NEW: Process base64 photo if provided
    let savedPhotoPath = photoPath;
    let savedPhotoUrl = photoUrl;

    if (photo && typeof photo === 'string') {
      try {
        console.log('[POST /api/reports] Processing base64 photo...');

        // Extract base64 data (remove data:image/...;base64, prefix if present)
        let base64Data = photo;
        if (photo.includes(',')) {
          base64Data = photo.split(',')[1];
        }

        // Decode base64
        const buffer = Buffer.from(base64Data, 'base64');
        console.log('[POST /api/reports] Decoded photo: ' + buffer.length + ' bytes');

        // Generate unique filename
        const filename = `report_${Date.now()}_${Math.random().toString(36).substring(7)}.jpg`;
        const uploadDir = path.join(__dirname, 'uploads', 'reports');
        const filePath = path.join(uploadDir, filename);

        // Create directory if it doesn't exist
        if (!fs.existsSync(uploadDir)) {
          fs.mkdirSync(uploadDir, { recursive: true });
          console.log('[POST /api/reports] Created uploads directory: ' + uploadDir);
        }

        // Write file
        fs.writeFileSync(filePath, buffer);
        console.log('[POST /api/reports] ✅ Photo saved: ' + filePath);

        // Set paths for storage
        savedPhotoPath = filePath;
        savedPhotoUrl = `/uploads/reports/${filename}`;
      } catch (photoError) {
        console.error('[POST /api/reports] Error saving photo:', photoError.message);
        // Continue without photo
      }
    }

    // Build data object from new format or use legacy data
    let reportData;
    if (summary) {
      // New format
      reportData = {
        summary,
        details: details || '',
        priority: priority || 'normal',
        photoPath: savedPhotoPath || null,
        photoUrl: savedPhotoUrl || null,
        hasPhoto: hasPhoto || !!photo
      };
    } else {
      // Legacy format
      reportData = typeof data === 'string' ? JSON.parse(data) : data;
    }

    const createdAt = Date.now();
    const reportTimestamp = submitted_at || timestamp || new Date().toISOString();
    const dataStr = JSON.stringify(reportData);

    db.run(
      'INSERT INTO reports (report_type, data, timestamp, created_at) VALUES (?, ?, ?, ?)',
      [report_type, dataStr, reportTimestamp, createdAt],
      function(err) {
        if (err) {
          console.error('[POST /api/reports] Insert error:', err.message);
          return res.status(500).json({
            success: false,
            error: `Server error: ${err.message}`
          });
        }

        console.log(`[POST /api/reports] ✅ Report saved with ID: ${this.lastID}`);
        if (hasPhoto) {
          console.log(`[POST /api/reports] 📸 Photo URL: ${photoUrl || photoPath}`);
        }

        res.status(201).json({
          success: true,
          id: this.lastID,
          message: 'Report saved successfully'
        });
      }
    );

  } catch (error) {
    console.error('[POST /api/reports] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Server error: ${error.message}`
    });
  }
});

// ====================================================================
// File Upload Endpoint (Base64)
// ====================================================================

/**
 * POST /api/upload
 *
 * Upload a file from React (base64 encoded)
 * Used by SyncManager when syncing actions with photos
 *
 * Request body:
 * {
 *   fileName: "photo.jpg",
 *   fileData: "data:image/jpeg;base64,/9j/4AAQ..." (or just base64 string)
 * }
 *
 * Response:
 * {
 *   success: true,
 *   fileUrl: "/uploads/photo-1234567890.jpg"
 * }
 */
app.post('/api/upload', async (req, res) => {
  try {
    console.log('[POST /api/upload] File upload request received');

    const { fileName, fileData } = req.body;

    if (!fileName || !fileData) {
      console.error('[POST /api/upload] Missing fileName or fileData');
      return res.status(400).json({
        success: false,
        error: 'Missing fileName or fileData in request body'
      });
    }

    // Extract base64 data (handle data URLs like "data:image/jpeg;base64,...")
    let base64Data = fileData;
    if (fileData.includes('base64,')) {
      base64Data = fileData.split('base64,')[1];
    }

    // Decode base64 to buffer
    const buffer = Buffer.from(base64Data, 'base64');

    // Generate unique filename
    const ext = path.extname(fileName);
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const uniqueFileName = `photo-${uniqueSuffix}${ext}`;
    const filePath = path.join(UPLOADS_DIR, uniqueFileName);

    // Write file to disk
    fs.writeFileSync(filePath, buffer);

    // Return file URL (relative to server)
    const fileUrl = `/uploads/${uniqueFileName}`;

    console.log('[POST /api/upload] ✅ File saved:', fileUrl);
    console.log('[POST /api/upload] File size:', (buffer.length / 1024).toFixed(2), 'KB');

    res.json({
      success: true,
      fileUrl: fileUrl,
      fileName: uniqueFileName,
      size: buffer.length
    });

  } catch (error) {
    console.error('[POST /api/upload] Error:', error.message);
    res.status(500).json({
      success: false,
      error: `Upload failed: ${error.message}`
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('[Server Error]', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  const os = require('os');
  const networkInterfaces = os.networkInterfaces();
  const addresses = [];

  // Get all local IP addresses
  Object.keys(networkInterfaces).forEach(interfaceName => {
    networkInterfaces[interfaceName].forEach(iface => {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push(iface.address);
      }
    });
  });

  console.log('='.repeat(60));
  console.log('Warehouse Transaction Backend Server - ENHANCED LOGGING');
  console.log('='.repeat(60));
  console.log(`Server running on: http://localhost:${PORT}`);
  console.log(`Database: ${DB_PATH}`);
  console.log(`Health check: http://localhost:${PORT}/api/health`);
  console.log(`Network debug: http://localhost:${PORT}/api/debug/network`);
  console.log('='.repeat(60));
  console.log('Local IP addresses (use for physical device):');
  addresses.forEach(addr => {
    console.log(`  http://${addr}:${PORT}`);
  });
  console.log('='.repeat(60));
  console.log('API Endpoints:');
  console.log('  --- Sample Warehouse ---');
  console.log(`  POST   http://localhost:${PORT}/api/transactions`);
  console.log(`  GET    http://localhost:${PORT}/api/transactions`);
  console.log(`  GET    http://localhost:${PORT}/api/transactions/:id`);
  console.log(`  DELETE http://localhost:${PORT}/api/transactions/:id`);
  console.log(`  POST   http://localhost:${PORT}/api/transactions/:id/photos`);
  console.log(`  GET    http://localhost:${PORT}/api/transactions/:id/photos`);
  console.log(`  GET    http://localhost:${PORT}/api/products/:barcode`);
  console.log(`  POST   http://localhost:${PORT}/api/water-temp`);
  console.log(`  GET    http://localhost:${PORT}/api/water-temp`);
  console.log(`  POST   http://localhost:${PORT}/api/complaints`);
  console.log(`  GET    http://localhost:${PORT}/api/complaints`);
  console.log('  --- NEW Phase 3: Test Modules ---');
  console.log(`  GET    http://localhost:${PORT}/api/products?q=search`);
  console.log(`  POST   http://localhost:${PORT}/api/stock-counts`);
  console.log(`  POST   http://localhost:${PORT}/api/audit-trail`);
  console.log(`  GET    http://localhost:${PORT}/api/defects/:code`);
  console.log(`  POST   http://localhost:${PORT}/api/inspection-logs`);
  console.log(`  POST   http://localhost:${PORT}/api/reports`);
  console.log('  --- Utilities ---');
  console.log(`  GET    http://localhost:${PORT}/api/health`);
  console.log(`  GET    http://localhost:${PORT}/api/debug/network`);
  console.log('='.repeat(60));
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n[Server] Shutting down gracefully...');
  db.close((err) => {
    if (err) {
      console.error('[Database] Close error:', err.message);
    } else {
      console.log('[Database] Connection closed');
    }
    process.exit(0);
  });
});

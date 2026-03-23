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

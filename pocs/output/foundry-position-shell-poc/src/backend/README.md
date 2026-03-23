# Warehouse Transaction Backend Server

Phase 3.5: Online-First Transaction Flow

## Overview

This is a Node.js + Express + SQLite backend server for the warehouse transaction management system. It provides RESTful APIs for submitting and retrieving warehouse receiving transactions.

**Purpose**: Establish a real backend with persistent storage before adding offline capabilities in Phase 4.

## Technology Stack

- **Runtime**: Node.js 18+
- **Web Framework**: Express 4.x
- **Database**: SQLite3 (via sqlite3 npm package)
- **CORS**: Enabled for WebView access
- **Data Format**: JSON

## Prerequisites

- Node.js 18.0.0 or higher
- npm (comes with Node.js)

## Installation

```bash
cd backend
npm install
```

This will install:
- express: Web framework
- sqlite3: SQLite database driver
- cors: CORS middleware
- uuid: UUID generation (optional, frontend generates IDs)
- nodemon: Auto-reload for development (dev dependency)

## Starting the Server

### Production Mode
```bash
npm start
```

### Development Mode (auto-reload on file changes)
```bash
npm run dev
```

The server will start on **http://localhost:3000** by default.

### Custom Port

```bash
PORT=8080 npm start
```

## API Endpoints

### Health Check

**GET** `/api/health`

Check if the backend server is running.

**Response:**
```json
{
  "status": "ok",
  "timestamp": 1773818591619,
  "database": "connected"
}
```

**Example:**
```bash
curl http://localhost:3000/api/health
```

---

### Submit Transaction

**POST** `/api/transactions`

Submit a new warehouse receiving transaction.

**Request Body:**
```json
{
  "transactionId": "TXN-1234567890",
  "poNumber": "PO-20260318-001",
  "vendor": "Acme Manufacturing Corp",
  "lineItems": [
    {
      "sku": "SKU001",
      "description": "Widget A",
      "quantity": "10",
      "location": "A1-B2"
    },
    {
      "sku": "SKU002",
      "description": "Widget B",
      "quantity": "5",
      "location": "C3-D4"
    }
  ],
  "createdAt": 1773818000000
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "transactionId": "TXN-1234567890",
  "receivedAt": 1773818001000,
  "status": "received"
}
```

**Response (400 Bad Request - Validation Error):**
```json
{
  "success": false,
  "error": "Validation error: poNumber is required and must be a string"
}
```

**Response (409 Conflict - Duplicate ID):**
```json
{
  "success": false,
  "error": "Transaction ID already exists"
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/api/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transactionId":"TXN-TEST-001",
    "poNumber":"PO-001",
    "vendor":"Test Vendor",
    "lineItems":[
      {"sku":"SKU001","description":"Test Item","quantity":"5","location":"A1"}
    ],
    "createdAt":1773818000000
  }'
```

---

### Get All Transactions

**GET** `/api/transactions`

Retrieve all transactions, ordered by received date (newest first).

**Query Parameters:**
- `limit` (optional): Maximum number of transactions to return (default: 50)
- `offset` (optional): Number of transactions to skip (default: 0)

**Response (200 OK):**
```json
{
  "success": true,
  "transactions": [
    {
      "id": 1,
      "transaction_id": "TXN-1234567890",
      "po_number": "PO-20260318-001",
      "vendor": "Acme Manufacturing Corp",
      "lineItems": [
        {
          "sku": "SKU001",
          "description": "Widget A",
          "quantity": "10",
          "location": "A1-B2"
        }
      ],
      "created_at": 1773818000000,
      "received_at": 1773818001000,
      "status": "received"
    }
  ],
  "count": 1,
  "limit": 50,
  "offset": 0
}
```

**Example:**
```bash
curl http://localhost:3000/api/transactions

# With pagination
curl "http://localhost:3000/api/transactions?limit=10&offset=0"
```

---

### Get Single Transaction

**GET** `/api/transactions/:transactionId`

Retrieve a specific transaction by its transaction ID.

**Response (200 OK):**
```json
{
  "success": true,
  "transaction": {
    "id": 1,
    "transaction_id": "TXN-1234567890",
    "po_number": "PO-20260318-001",
    "vendor": "Acme Manufacturing Corp",
    "lineItems": [...],
    "created_at": 1773818000000,
    "received_at": 1773818001000,
    "status": "received"
  }
}
```

**Response (404 Not Found):**
```json
{
  "success": false,
  "error": "Transaction not found"
}
```

**Example:**
```bash
curl http://localhost:3000/api/transactions/TXN-TEST-001
```

---

### Delete Transaction

**DELETE** `/api/transactions/:transactionId`

Delete a transaction by its transaction ID.

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Transaction deleted"
}
```

**Response (404 Not Found):**
```json
{
  "success": false,
  "error": "Transaction not found"
}
```

**Example:**
```bash
curl -X DELETE http://localhost:3000/api/transactions/TXN-TEST-001
```

---

## Database Schema

**Table**: `transactions`

```sql
CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id TEXT UNIQUE NOT NULL,
  po_number TEXT NOT NULL,
  vendor TEXT NOT NULL,
  line_items TEXT NOT NULL,       -- JSON string
  created_at INTEGER NOT NULL,     -- Unix timestamp (client)
  received_at INTEGER NOT NULL,    -- Unix timestamp (server)
  status TEXT DEFAULT 'received'
);

-- Indexes
CREATE INDEX idx_transaction_id ON transactions(transaction_id);
CREATE INDEX idx_po_number ON transactions(po_number);
CREATE INDEX idx_created_at ON transactions(created_at DESC);
```

**Database File**: `backend_transactions.db` (created automatically on first run)

**Location**: `backend/backend_transactions.db`

### Viewing Database Contents

```bash
# Install SQLite CLI if not already installed
# Windows: Download from https://www.sqlite.org/download.html
# Mac: brew install sqlite
# Linux: apt-get install sqlite3

# Query the database
sqlite3 backend_transactions.db "SELECT * FROM transactions;"

# Get transaction count
sqlite3 backend_transactions.db "SELECT COUNT(*) FROM transactions;"

# View recent transactions
sqlite3 backend_transactions.db "SELECT transaction_id, po_number, vendor, received_at FROM transactions ORDER BY received_at DESC LIMIT 10;"
```

---

## Validation Rules

The backend validates all incoming transactions:

### Required Fields
- `transactionId`: String (must be unique)
- `poNumber`: String (max 50 characters)
- `vendor`: String (max 100 characters)
- `lineItems`: Array (min 1 item, max 50 items)
- `createdAt`: Number (Unix timestamp)

### Line Item Requirements
Each line item must have:
- `sku`: String (required)
- `quantity`: Any (required)
- `location`: String (required)
- `description`: String (optional)

### Error Responses
All validation errors return HTTP 400 with:
```json
{
  "success": false,
  "error": "Validation error: [detailed message]"
}
```

---

## CORS Configuration

The backend allows requests from any origin to support WebView access:

```javascript
cors({
  origin: '*',
  methods: ['GET', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
})
```

This is required because the React app runs in a WebView with `file://` protocol.

**Production Note**: In production, restrict `origin` to specific domains.

---

## Testing

### Test 1: Backend Standalone (curl)

```bash
# Start server
npm start

# Test health check
curl http://localhost:3000/api/health

# Submit transaction
curl -X POST http://localhost:3000/api/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transactionId":"TEST-001",
    "poNumber":"PO-001",
    "vendor":"Test Vendor",
    "lineItems":[{"sku":"SKU001","description":"Test Item","quantity":"5","location":"A1"}],
    "createdAt":1773818000000
  }'

# Get all transactions
curl http://localhost:3000/api/transactions

# Get single transaction
curl http://localhost:3000/api/transactions/TEST-001

# Delete transaction
curl -X DELETE http://localhost:3000/api/transactions/TEST-001
```

### Test 2: React App in Browser

1. Start backend: `npm start`
2. Open `test_browser.html` in Chrome
3. Open DevTools (F12) → Console tab
4. Fill transaction form
5. Submit transaction
6. Check Console for fetch() logs
7. Check backend terminal for request logs
8. Switch to "History" tab
9. Verify transaction appears

### Test 3: Android Emulator

1. Start backend on host machine
2. React app uses `BACKEND_URL = 'http://10.0.2.2:3000'`
3. 10.0.2.2 is the emulator's alias for host machine localhost
4. Build Flutter app: `flutter run`
5. Navigate to Warehouse Clerk module
6. Submit transaction
7. Check backend logs on host machine

### Test 4: Physical Android Device

1. Start backend on host machine
2. Find host machine IP:
   - Windows: `ipconfig` (look for IPv4 Address)
   - Mac/Linux: `ifconfig` or `ip addr`
3. Update BACKEND_URL in React app: `http://YOUR_IP:3000`
4. Ensure device and computer on same WiFi network
5. Build and run: `flutter run`
6. Submit transaction

---

## Troubleshooting

### Issue: Backend won't start

**Solution:**
- Check if port 3000 is already in use: `netstat -an | findstr 3000` (Windows) or `lsof -i :3000` (Mac/Linux)
- Kill the process using port 3000 or use a different port: `PORT=8080 npm start`

### Issue: "Cannot find module 'express'"

**Solution:**
```bash
rm -rf node_modules package-lock.json
npm install
```

### Issue: CORS errors in browser

**Symptoms:** Console shows "CORS policy: No 'Access-Control-Allow-Origin' header"

**Solution:**
- Verify CORS middleware is enabled in server.js
- Check backend logs show the OPTIONS preflight request
- Try: `curl -I http://localhost:3000/api/health` and verify `Access-Control-Allow-Origin: *` header

### Issue: Android emulator can't reach backend

**Symptoms:** React app shows "Network error" or "Backend Disconnected"

**Solution:**
- Verify backend is running on host machine
- Use `http://10.0.2.2:3000` NOT `http://localhost:3000`
- Check network_security_config.xml is configured in AndroidManifest.xml
- Test connectivity: In Android Studio → Device File Explorer → Terminal
  ```bash
  adb shell curl http://10.0.2.2:3000/api/health
  ```

### Issue: Physical device can't reach backend

**Solution:**
- Ensure device and computer on same WiFi network
- Check firewall allows incoming connections on port 3000
- Windows: Allow Node.js through Windows Firewall
- Verify IP address is correct (not 127.0.0.1 or localhost)
- Test: On device browser, navigate to `http://YOUR_IP:3000/api/health`

### Issue: Database locked error

**Symptoms:** "database is locked" error

**Solution:**
- Close any SQLite CLI sessions
- Restart the backend server
- Delete `.db-shm` and `.db-wal` files (backup `.db` first)

### Issue: Transactions not persisting

**Solution:**
- Check `backend_transactions.db` file exists
- Query database directly: `sqlite3 backend_transactions.db "SELECT * FROM transactions;"`
- Check backend logs for insertion errors
- Verify disk has write permissions

---

## File Structure

```
backend/
├── server.js                    # Main Express server
├── package.json                 # NPM dependencies
├── package-lock.json            # Locked dependency versions
├── README.md                    # This file
├── test_browser.html            # Browser test page
├── .gitignore                   # Git ignore rules
├── backend_transactions.db      # SQLite database (created on first run)
├── backend_transactions.db-shm  # SQLite shared memory (WAL mode)
└── backend_transactions.db-wal  # SQLite write-ahead log
```

---

## Development Notes

### Adding New Endpoints

1. Add route in `server.js`:
```javascript
app.get('/api/your-endpoint', (req, res) => {
  // Your logic
  res.json({ success: true, data: ... });
});
```

2. Test with curl
3. Update this README

### Modifying Database Schema

1. Stop the backend server
2. Backup database: `cp backend_transactions.db backup.db`
3. Modify schema in `initDatabase()` function
4. Delete old database: `rm backend_transactions.db*`
5. Restart server (recreates tables)

### Logging

All requests are logged to console:
```
[2026-03-18T12:00:00.000Z] POST /api/transactions
[POST /api/transactions] Received: { "transactionId": "..." }
[POST /api/transactions] Transaction TXN-001 inserted with ID 1
```

---

## Phase 4 Preview: Offline Capabilities

This backend will serve as the **sync target** for Phase 4:

1. React detects network state
2. If **online** → Direct POST to this backend (already works)
3. If **offline** → Queue in local SQLite
4. When network restores → Sync queue to this backend
5. Backend validates and stores (same POST endpoint)

The online-first approach established in Phase 3.5 provides the foundation for offline sync.

---

## License

MIT

---

## Support

For issues or questions about Phase 3.5 implementation, refer to:
- `PHASE_3.5_PLAN.md` in project root
- Backend logs: Check terminal where `npm start` is running
- Network inspection: Browser DevTools → Network tab
- Database inspection: `sqlite3 backend_transactions.db`

---

**Last Updated**: 2026-03-18
**Phase**: 3.5 - Online-First Transaction Flow

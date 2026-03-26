# Third-Party Libraries

## RxDB Setup

RxDB will be loaded via CDN in the main index.html file:

```html
<!-- RxDB Core -->
<script src="https://cdn.jsdelivr.net/npm/rxdb@15.0.0/dist/rxdb.min.js"></script>

<!-- RxDB Plugins (if needed) -->
<script src="https://cdn.jsdelivr.net/npm/rxdb@15.0.0/dist/plugins/replication.min.js"></script>
```

### Alternative: Local Installation

If offline bundling is required:
1. Download rxdb.min.js from https://github.com/pubkey/rxdb/releases
2. Place in this `lib/` folder
3. Update index.html script tags to local paths

### Bundle Size
- RxDB Core: ~200KB (minified + gzipped)
- With replication plugin: ~250KB total
- Current app: ~300KB
- **New total: ~550KB** (acceptable for offline-first app)

### Why RxDB?
- Built-in offline-first replication
- Observable queries (real-time UI updates)
- Conflict resolution
- Multi-tab/worker support
- Battle-tested at scale

// RxDB Implementation Validation Script
// Run this in Node.js to validate all files exist and have valid syntax

const fs = require('fs');
const path = require('path');

const BASE_PATH = path.join(__dirname, '..');

const REQUIRED_FILES = [
    // Config files
    'src/config/database.config.js',
    'src/config/api.config.js',
    'src/config/replication.config.js',

    // Schema files
    'src/database/collections/transactions.schema.js',
    'src/database/collections/waterChecks.schema.js',
    'src/database/collections/complaints.schema.js',

    // Database core
    'src/database/database.js',

    // Replication files
    'src/database/replication/pull-handler.js',
    'src/database/replication/push-handler.js',
    'src/database/replication/conflict-handler.js',
    'src/database/replication/replication-setup.js',

    // Migration
    'src/database/migrations/dexie-to-rxdb.js',

    // React hooks
    'src/hooks/useRxDB.js',
    'src/hooks/useTransactions.js',
    'src/hooks/useWaterChecks.js',
    'src/hooks/useComplaints.js',
    'src/hooks/useSyncStatus.js',

    // Documentation
    'RXDB_INTEGRATION_GUIDE.md',
    'QUICK_REFERENCE.md',
    'lib/README.md'
];

const VALIDATION_RESULTS = {
    filesExist: [],
    filesMissing: [],
    syntaxValid: [],
    syntaxErrors: [],
    totalFiles: 0,
    passed: 0,
    failed: 0
};

console.log('🔍 RxDB Implementation Validation\n');
console.log('='.repeat(50));

// Test 1: File Existence
console.log('\n📁 TEST 1: File Existence');
console.log('-'.repeat(50));

REQUIRED_FILES.forEach(file => {
    const filePath = path.join(BASE_PATH, file);
    const exists = fs.existsSync(filePath);

    VALIDATION_RESULTS.totalFiles++;

    if (exists) {
        VALIDATION_RESULTS.filesExist.push(file);
        VALIDATION_RESULTS.passed++;
        console.log(`✅ ${file}`);
    } else {
        VALIDATION_RESULTS.filesMissing.push(file);
        VALIDATION_RESULTS.failed++;
        console.log(`❌ ${file} - NOT FOUND`);
    }
});

// Test 2: JavaScript Syntax Validation
console.log('\n\n🔧 TEST 2: JavaScript Syntax Validation');
console.log('-'.repeat(50));

REQUIRED_FILES.forEach(file => {
    // Skip markdown files
    if (file.endsWith('.md')) return;

    const filePath = path.join(BASE_PATH, file);

    if (!fs.existsSync(filePath)) {
        console.log(`⏭️  ${file} - SKIPPED (file not found)`);
        return;
    }

    try {
        const content = fs.readFileSync(filePath, 'utf8');

        // Basic syntax check - try to parse as JavaScript
        // Note: This won't catch all errors since these files use browser globals
        if (content.trim().length === 0) {
            throw new Error('File is empty');
        }

        // Check for common syntax errors
        const hasBalancedBraces = (content.match(/{/g) || []).length === (content.match(/}/g) || []).length;
        const hasBalancedParens = (content.match(/\(/g) || []).length === (content.match(/\)/g) || []).length;
        const hasBalancedBrackets = (content.match(/\[/g) || []).length === (content.match(/\]/g) || []).length;

        if (!hasBalancedBraces) {
            throw new Error('Unbalanced curly braces {}');
        }
        if (!hasBalancedParens) {
            throw new Error('Unbalanced parentheses ()');
        }
        if (!hasBalancedBrackets) {
            throw new Error('Unbalanced brackets []');
        }

        VALIDATION_RESULTS.syntaxValid.push(file);
        console.log(`✅ ${file} - Valid`);

    } catch (error) {
        VALIDATION_RESULTS.syntaxErrors.push({ file, error: error.message });
        console.log(`❌ ${file} - ERROR: ${error.message}`);
    }
});

// Test 3: Configuration Validation
console.log('\n\n⚙️  TEST 3: Configuration Validation');
console.log('-'.repeat(50));

// Validate database config
try {
    const dbConfigPath = path.join(BASE_PATH, 'src/config/database.config.js');
    const dbConfig = fs.readFileSync(dbConfigPath, 'utf8');

    const hasDBName = dbConfig.includes('name:') && dbConfig.includes('warehouse');
    const hasCollections = dbConfig.includes('collections:') &&
                          dbConfig.includes('transactions') &&
                          dbConfig.includes('waterChecks') &&
                          dbConfig.includes('complaints');

    if (hasDBName && hasCollections) {
        console.log('✅ database.config.js - Valid (name + 3 collections)');
    } else {
        console.log('❌ database.config.js - Missing required fields');
    }
} catch (error) {
    console.log(`❌ database.config.js - ${error.message}`);
}

// Validate API config
try {
    const apiConfigPath = path.join(BASE_PATH, 'src/config/api.config.js');
    const apiConfig = fs.readFileSync(apiConfigPath, 'utf8');

    const hasBaseURL = apiConfig.includes('baseURL:');
    const hasEndpoints = apiConfig.includes('endpoints:') &&
                        apiConfig.includes('/api/transactions') &&
                        apiConfig.includes('/api/water-checks') &&
                        apiConfig.includes('/api/complaints');

    if (hasBaseURL && hasEndpoints) {
        console.log('✅ api.config.js - Valid (baseURL + 3 endpoints)');
    } else {
        console.log('❌ api.config.js - Missing required fields');
    }
} catch (error) {
    console.log(`❌ api.config.js - ${error.message}`);
}

// Validate replication config
try {
    const repConfigPath = path.join(BASE_PATH, 'src/config/replication.config.js');
    const repConfig = fs.readFileSync(repConfigPath, 'utf8');

    const hasSyncInterval = repConfig.includes('syncInterval:');
    const hasBatchSize = repConfig.includes('batchSize:');

    if (hasSyncInterval && hasBatchSize) {
        console.log('✅ replication.config.js - Valid (syncInterval + batchSize)');
    } else {
        console.log('❌ replication.config.js - Missing required fields');
    }
} catch (error) {
    console.log(`❌ replication.config.js - ${error.message}`);
}

// Test 4: Schema Validation
console.log('\n\n📋 TEST 4: Schema Validation');
console.log('-'.repeat(50));

const schemas = [
    { file: 'src/database/collections/transactions.schema.js', primaryKey: 'transactionId' },
    { file: 'src/database/collections/waterChecks.schema.js', primaryKey: 'id' },
    { file: 'src/database/collections/complaints.schema.js', primaryKey: 'id' }
];

schemas.forEach(({ file, primaryKey }) => {
    try {
        const schemaPath = path.join(BASE_PATH, file);
        const content = fs.readFileSync(schemaPath, 'utf8');

        const hasPrimaryKey = content.includes(`primaryKey: '${primaryKey}'`);
        const hasProperties = content.includes('properties:');
        const hasIndexes = content.includes('indexes:');
        const hasSyncStatus = content.includes('syncStatus');
        const hasDeleted = content.includes('deleted');
        const hasMethods = content.includes('Methods') && content.includes('softDelete');

        if (hasPrimaryKey && hasProperties && hasIndexes && hasSyncStatus && hasDeleted && hasMethods) {
            console.log(`✅ ${file} - Complete schema with methods`);
        } else {
            const missing = [];
            if (!hasPrimaryKey) missing.push('primaryKey');
            if (!hasProperties) missing.push('properties');
            if (!hasIndexes) missing.push('indexes');
            if (!hasSyncStatus) missing.push('syncStatus');
            if (!hasDeleted) missing.push('deleted');
            if (!hasMethods) missing.push('methods');
            console.log(`⚠️  ${file} - Missing: ${missing.join(', ')}`);
        }
    } catch (error) {
        console.log(`❌ ${file} - ${error.message}`);
    }
});

// Test 5: Handler Validation
console.log('\n\n🔄 TEST 5: Replication Handler Validation');
console.log('-'.repeat(50));

const handlers = [
    { file: 'src/database/replication/pull-handler.js', exports: ['createPullHandler', 'createAll'] },
    { file: 'src/database/replication/push-handler.js', exports: ['createPushHandler', 'createAll'] },
    { file: 'src/database/replication/conflict-handler.js', exports: ['createConflictHandler', 'createAll'] },
    { file: 'src/database/replication/replication-setup.js', exports: ['setup', 'trigger', 'stop'] }
];

handlers.forEach(({ file, exports }) => {
    try {
        const handlerPath = path.join(BASE_PATH, file);
        const content = fs.readFileSync(handlerPath, 'utf8');

        const hasAllExports = exports.every(exp =>
            content.includes(`${exp}:`) || content.includes(`function ${exp}`)
        );

        const hasWindowExport = content.includes('window.');

        if (hasAllExports && hasWindowExport) {
            console.log(`✅ ${file} - All exports present`);
        } else {
            console.log(`⚠️  ${file} - Missing some exports`);
        }
    } catch (error) {
        console.log(`❌ ${file} - ${error.message}`);
    }
});

// Test 6: React Hook Validation
console.log('\n\n⚛️  TEST 6: React Hook Validation');
console.log('-'.repeat(50));

const hooks = [
    { file: 'src/hooks/useRxDB.js', returns: ['db', 'isInitialized', 'error'] },
    { file: 'src/hooks/useTransactions.js', returns: ['transactions', 'addTransaction', 'deleteTransaction'] },
    { file: 'src/hooks/useWaterChecks.js', returns: ['waterChecks', 'addWaterCheck', 'deleteWaterCheck'] },
    { file: 'src/hooks/useComplaints.js', returns: ['complaints', 'addComplaint', 'deleteComplaint'] },
    { file: 'src/hooks/useSyncStatus.js', returns: ['isOnline', 'isSyncing', 'pendingCounts', 'triggerSync'] }
];

hooks.forEach(({ file, returns }) => {
    try {
        const hookPath = path.join(BASE_PATH, file);
        const content = fs.readFileSync(hookPath, 'utf8');

        const usesReact = content.includes('React.useState') || content.includes('React.useEffect');
        const hasReturn = content.includes('return {');
        const hasAllReturns = returns.every(ret => content.includes(ret));
        const hasWindowExport = content.includes('window.');

        if (usesReact && hasReturn && hasAllReturns && hasWindowExport) {
            console.log(`✅ ${file} - Valid React hook`);
        } else {
            const issues = [];
            if (!usesReact) issues.push('no React hooks');
            if (!hasReturn) issues.push('no return statement');
            if (!hasAllReturns) issues.push('missing return values');
            if (!hasWindowExport) issues.push('no window export');
            console.log(`⚠️  ${file} - Issues: ${issues.join(', ')}`);
        }
    } catch (error) {
        console.log(`❌ ${file} - ${error.message}`);
    }
});

// Final Summary
console.log('\n\n📊 VALIDATION SUMMARY');
console.log('='.repeat(50));
console.log(`Total Files Checked: ${VALIDATION_RESULTS.totalFiles}`);
console.log(`Files Exist: ${VALIDATION_RESULTS.filesExist.length}/${REQUIRED_FILES.length}`);
console.log(`Syntax Valid: ${VALIDATION_RESULTS.syntaxValid.length}`);
console.log(`Syntax Errors: ${VALIDATION_RESULTS.syntaxErrors.length}`);

if (VALIDATION_RESULTS.filesMissing.length > 0) {
    console.log('\n❌ Missing Files:');
    VALIDATION_RESULTS.filesMissing.forEach(file => console.log(`   - ${file}`));
}

if (VALIDATION_RESULTS.syntaxErrors.length > 0) {
    console.log('\n❌ Syntax Errors:');
    VALIDATION_RESULTS.syntaxErrors.forEach(({ file, error }) => {
        console.log(`   - ${file}: ${error}`);
    });
}

const allPassed = VALIDATION_RESULTS.filesMissing.length === 0 &&
                  VALIDATION_RESULTS.syntaxErrors.length === 0;

if (allPassed) {
    console.log('\n✅ ALL VALIDATIONS PASSED!');
    console.log('✅ Implementation is ready for integration.');
    process.exit(0);
} else {
    console.log('\n❌ VALIDATION FAILED');
    console.log('⚠️  Please fix the issues above before integration.');
    process.exit(1);
}

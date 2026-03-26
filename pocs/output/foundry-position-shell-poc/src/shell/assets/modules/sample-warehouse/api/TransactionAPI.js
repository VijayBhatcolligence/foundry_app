/**
 * Transaction API Client
 *
 * Handles HTTP requests to the backend API for submitting transactions.
 * Includes error handling, request/response logging, and timeout management.
 */

const API_BASE_URL = 'http://192.168.0.163:3000';
const API_TIMEOUT = 30000; // 30 seconds

/**
 * Submit transaction to backend API
 *
 * @param {Object} transactionData - Transaction data to submit
 * @returns {Promise<Object>} Response object with success status
 */
export async function submitTransactionToAPI(transactionData) {
  const url = `${API_BASE_URL}/api/transactions`;

  console.log('[TransactionAPI] Submitting to:', url);
  console.log('[TransactionAPI] Data:', transactionData);

  try {
    // Create abort controller for timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT);

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify(transactionData),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    console.log('[TransactionAPI] Response status:', response.status);

    if (!response.ok) {
      const errorText = await response.text();
      console.error('[TransactionAPI] Error response:', errorText);
      throw new Error(`HTTP ${response.status}: ${errorText}`);
    }

    const result = await response.json();
    console.log('[TransactionAPI] Success:', result);

    return {
      success: true,
      data: result
    };

  } catch (error) {
    console.error('[TransactionAPI] Request failed:', error);

    // Handle different error types
    if (error.name === 'AbortError') {
      return {
        success: false,
        error: 'Request timeout (30s)'
      };
    }

    if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
      return {
        success: false,
        error: 'Network error - server unreachable'
      };
    }

    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Load transaction history from API
 *
 * @param {Object} options - Query options (limit, offset)
 * @returns {Promise<Object>} Response with transactions array
 */
export async function loadTransactionHistory(options = {}) {
  const { limit = 50, offset = 0 } = options;
  const url = `${API_BASE_URL}/api/transactions?limit=${limit}&offset=${offset}`;

  console.log('[TransactionAPI] Loading history from:', url);

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT);

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    console.log('[TransactionAPI] History loaded:', data.transactions?.length || 0, 'transactions');

    return {
      success: true,
      transactions: data.transactions || [],
      count: data.count || 0
    };

  } catch (error) {
    console.error('[TransactionAPI] History load failed:', error);

    return {
      success: false,
      error: error.message,
      transactions: []
    };
  }
}

/**
 * Check API health
 *
 * @returns {Promise<Boolean>} True if API is reachable
 */
export async function checkAPIHealth() {
  const url = `${API_BASE_URL}/api/health`;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    return response.ok;

  } catch (error) {
    console.error('[TransactionAPI] Health check failed:', error);
    return false;
  }
}

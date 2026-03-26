/**
 * React Hook for RxDB Database Access
 *
 * Provides a singleton database instance to React components
 * with initialization on first use and error handling.
 */

import { useState, useEffect } from 'react';
import { initDatabase } from './schema.js';

let databaseInstance = null;
let initializationPromise = null;

/**
 * React hook to access the RxDB database
 *
 * @returns {Object} { db, isLoading, error }
 */
export function useDatabase() {
  const [db, setDb] = useState(databaseInstance);
  const [isLoading, setIsLoading] = useState(!databaseInstance);
  const [error, setError] = useState(null);

  useEffect(() => {
    // If database already exists, use it
    if (databaseInstance) {
      setDb(databaseInstance);
      setIsLoading(false);
      return;
    }

    // If initialization is in progress, wait for it
    if (initializationPromise) {
      initializationPromise
        .then((database) => {
          databaseInstance = database;
          setDb(database);
          setIsLoading(false);
        })
        .catch((err) => {
          console.error('[useDatabase] Initialization error:', err);
          setError(err.message);
          setIsLoading(false);
        });
      return;
    }

    // Start initialization
    setIsLoading(true);
    initializationPromise = initDatabase();

    initializationPromise
      .then((database) => {
        console.log('[useDatabase] Database initialized successfully');
        databaseInstance = database;
        setDb(database);
        setIsLoading(false);
        setError(null);
      })
      .catch((err) => {
        console.error('[useDatabase] Database initialization failed:', err);
        setError(err.message);
        setIsLoading(false);
        initializationPromise = null; // Allow retry
      });

  }, []);

  return { db, isLoading, error };
}

/**
 * Get database instance directly (non-hook version)
 * Useful for non-React code
 */
export async function getDatabaseInstance() {
  if (databaseInstance) {
    return databaseInstance;
  }

  if (initializationPromise) {
    return initializationPromise;
  }

  initializationPromise = initDatabase();
  databaseInstance = await initializationPromise;
  return databaseInstance;
}

import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

console.log('[test-inventory-checker] Module initializing...');
console.log('[test-inventory-checker] Origin:', window.location.origin);
console.log('[test-inventory-checker] ActionQueue available:', window.ActionQueue ? 'YES' : 'NO');

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

console.log('[test-inventory-checker] Module loaded successfully');

import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

console.log('[test-quality-inspector] Module initializing...');
console.log('[test-quality-inspector] Origin:', window.location.origin);
console.log('[test-quality-inspector] ActionQueue available:', window.ActionQueue ? 'YES' : 'NO');

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<React.StrictMode><App /></React.StrictMode>);

console.log('[test-quality-inspector] Module loaded successfully');

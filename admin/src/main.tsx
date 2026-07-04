import { registerSW } from 'virtual:pwa-register';
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { ApolloProvider } from '@apollo/client';
import { AuthProvider } from '@/contexts/AuthContext';
import client from '@/lib/apollo-client';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ApolloProvider client={client}>
      <AuthProvider>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </AuthProvider>
    </ApolloProvider>
  </React.StrictMode>
);

registerSW({ immediate: true });

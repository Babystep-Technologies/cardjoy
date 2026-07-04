import { registerSW } from 'virtual:pwa-register';
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { ApolloProvider } from '@apollo/client';
import { AuthProvider } from '@/contexts/AuthContext';
import { PostHogProvider } from 'posthog-js/react';
import client from '@/lib/apollo-client';
import { POSTHOG_HOST } from './lib/constants';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ApolloProvider client={client}>
      <AuthProvider>
        <PostHogProvider
          apiKey={import.meta.env.VITE_POSTHOG_KEY}
          options={{ api_host: POSTHOG_HOST }}
        >
          <BrowserRouter>
            <App />
          </BrowserRouter>
        </PostHogProvider>
      </AuthProvider>
    </ApolloProvider>
  </React.StrictMode>
);
registerSW({ immediate: true });

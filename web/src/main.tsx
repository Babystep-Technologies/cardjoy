import { registerSW } from 'virtual:pwa-register';
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { ApolloProvider } from '@apollo/client';
import { AuthProvider } from '@/contexts/AuthContext';
import { OrganizationProvider } from '@/contexts/OrganizationContext';
import { PostHogProvider } from 'posthog-js/react';
import client from '@/lib/apollo-client';
import { POSTHOG_HOST } from './lib/constants';
import './index.css';

// PostHog is optional — only wrap the app in the provider when a key is set.
const POSTHOG_KEY = import.meta.env.VITE_POSTHOG_KEY as string | undefined;

const appTree = (
  <BrowserRouter>
    <App />
  </BrowserRouter>
);

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ApolloProvider client={client}>
      <AuthProvider>
        {/* Inside AuthProvider: the active organization is read with the token, so the session has
            to resolve first. */}
        <OrganizationProvider>
          {POSTHOG_KEY ? (
            <PostHogProvider apiKey={POSTHOG_KEY} options={{ api_host: POSTHOG_HOST }}>
              {appTree}
            </PostHogProvider>
          ) : (
            appTree
          )}
        </OrganizationProvider>
      </AuthProvider>
    </ApolloProvider>
  </React.StrictMode>
);
registerSW({ immediate: true });

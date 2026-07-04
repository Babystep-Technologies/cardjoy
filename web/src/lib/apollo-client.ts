import { ApolloClient, InMemoryCache, from, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';
import { APP_TOKEN_KEY } from '@/lib/constants';

const httpLink = createHttpLink({
  uri: import.meta.env.VITE_GRAPHQL_ENDPOINT,
  credentials: 'include',
});

const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem(APP_TOKEN_KEY);
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : '',
    },
  };
});

const errorLink = onError(({ graphQLErrors, networkError }) => {
  if (graphQLErrors) {
    for (const err of graphQLErrors) {
      if (err.extensions?.code === 'UNAUTHENTICATED' || err.message === 'Unauthorized') {
        console.warn('GraphQL Unauthorized error caught, clearing token...');
        localStorage.removeItem(APP_TOKEN_KEY);
        // Don't redirect - let the page handle auth requirements
        // This allows public pages like invitation views to continue working
      }
    }
  }

  if (networkError && 'statusCode' in networkError) {
    const serverError = networkError as { statusCode: number };
    if (serverError.statusCode === 401) {
      console.warn('Network 401 Unauthorized error caught, clearing token...');
      localStorage.removeItem(APP_TOKEN_KEY);
      // Don't redirect - let the page handle auth requirements
    }
  }
});

const client = new ApolloClient({
  link: from([errorLink, authLink, httpLink]),
  cache: new InMemoryCache(),
});

export default client;

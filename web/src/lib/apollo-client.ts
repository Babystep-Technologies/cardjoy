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

/**
 * A holiday card template's slot ids (`photo_1`, `greeting`, `corner_tl`) are
 * unique *within a template*, not across the catalogue — that is deliberate on
 * the server, where a slot is only ever read alongside the template that owns
 * it.
 *
 * Apollo, though, normalizes any object carrying an `id` into a global entry, so
 * `HolidayCardPhotoSlot:photo_1` from Snowy Trio and the one from Single Moment
 * would be the same cache record and the last query to land would win. The
 * symptom is the worst kind this feature can have: the editor draws a real
 * template with another template's coordinates, and the preview stops matching
 * what prints.
 *
 * `keyFields: false` keeps these embedded in their parent template, which is
 * where they belong. Templates and stickers keep their normal identity — those
 * ids really are catalogue-wide.
 */
const cache = new InMemoryCache({
  typePolicies: {
    HolidayCardPhotoSlot: { keyFields: false },
    HolidayCardTextRegion: { keyFields: false },
    HolidayCardStickerRegion: { keyFields: false },
  },
});

const client = new ApolloClient({
  link: from([errorLink, authLink, httpLink]),
  cache,
});

export default client;

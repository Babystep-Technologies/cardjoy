import { APP_TOKEN_KEY } from '@/lib/constants';

interface UploadOptions {
  /** The mutation document, as a string rather than a `gql` tag. */
  query: string;
  /** Mutation input. The file variable itself must be `null` here — `map` wires it up. */
  input: Record<string, unknown>;
  /** Dot-path of the `Upload` variable, e.g. `variables.input.coverImageFile`. */
  filePath: string;
  file: Blob;
  filename: string;
}

/**
 * POSTs a GraphQL mutation carrying a file, using the multipart request spec
 * (`operations` / `map` / `0`) that `apollo_upload_server` expects on the API.
 *
 * Apollo Client cannot do this on its own — `apollo-upload-client` is not a
 * dependency — so file-carrying mutations bypass the client and fetch directly.
 */
export async function uploadGraphQLMutation<T = Record<string, unknown>>({
  query,
  input,
  filePath,
  file,
  filename,
}: UploadOptions): Promise<{ data?: T; errors?: { message: string }[] }> {
  const formData = new FormData();
  formData.append('operations', JSON.stringify({ query, variables: { input } }));
  formData.append('map', JSON.stringify({ '0': [filePath] }));
  formData.append('0', file, filename);

  const token = localStorage.getItem(APP_TOKEN_KEY);
  const res = await fetch(import.meta.env.VITE_GRAPHQL_ENDPOINT, {
    method: 'POST',
    body: formData,
    credentials: 'include',
    headers: {
      Authorization: token ? `Bearer ${token}` : '',
    },
  });

  return res.json();
}

declare module 'apollo-upload-client' {
  export function createUploadLink(options: {
    uri: string;
    credentials?: 'include' | 'same-origin' | 'omit';
  }): import('@apollo/client').ApolloLink;
}

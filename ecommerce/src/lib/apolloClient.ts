import {
  ApolloClient,
  InMemoryCache,
  HttpLink,
  ApolloLink,
  from,
} from '@apollo/client';
import { getBrowserCorrelationId } from './correlation';

const defaultGraphqlUrl =
  typeof window !== 'undefined'
    ? `${window.location.origin}/graphql`
    : process.env.INTERNAL_GRAPHQL_URL || 'http://localhost:4000/graphql';

const httpLink = new HttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL || defaultGraphqlUrl,
  credentials: 'include',
});

const authLink = new ApolloLink((operation, forward) => {
  if (typeof window !== 'undefined') {
    const token = document.cookie
      .split('; ')
      .find((row) => row.startsWith('accessToken='))
      ?.split('=')[1];
    const correlationId = getBrowserCorrelationId();
    const oldHeaders = operation.getContext().headers;

    operation.setContext({
      headers: {
        ...oldHeaders,
        ...(correlationId && {
          'x-correlation-id': correlationId,
        }),
      },
    });

    if (token) {
      operation.setContext({
        headers: {
          ...operation.getContext().headers,
          authorization: `Bearer ${token}`,
        },
      });
    }
  }

  return forward(operation);
});

export const apolloClient = new ApolloClient({
  link: from([authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          products: {
            merge(existing, incoming) {
              return incoming;
            },
          },
        },
      },
    },
  }),
});

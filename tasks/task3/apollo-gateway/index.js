
const { ApolloServer } = require('@apollo/server');
const { startStandaloneServer } = require('@apollo/server/standalone');
const { ApolloGateway, IntrospectAndCompose, RemoteGraphQLDataSource } = require('@apollo/gateway');

class AuthenticatedDataSource extends RemoteGraphQLDataSource {
  willSendRequest({ request, context }) {
    // Пробрасываем userid из входящего запроса в subgraphs
    if (context.userid) {
      request.http.headers.set('userid', context.userid);
    }
    if (context.userHeaders) {
      for (const [key, value] of Object.entries(context.userHeaders)) {
        if (key !== 'host' && key !== 'content-length' && key !== 'content-type') {
          request.http.headers.set(key, value);
        }
      }
    }
  }
}

async function startGateway() {
  const gateway = new ApolloGateway({
    supergraphSdl: new IntrospectAndCompose({
      subgraphs: [
        { name: 'booking', url: 'http://booking-subgraph:4001/' },
        { name: 'hotel', url: 'http://hotel-subgraph:4002/' },
        { name: 'promocode', url: 'http://promocode-subgraph:4003/' }
      ],
    }),
    buildService({ url }) {
      return new AuthenticatedDataSource({ url });
    },
    debug: true
  });

  const server = new ApolloServer({
    gateway,
    introspection: true,
    plugins: [
      {
        requestDidStart() {
          return {
            didResolveOperation(requestContext) {
              console.log('🎯 GraphQL Operation:', requestContext.request.operationName || 'Anonymous');
              console.log('📋 Query:', requestContext.request.query);
            },
            willSendResponse(requestContext) {
              const headers = requestContext.request.http?.headers;
              if (headers) {
                console.log('🔑 Request headers:', JSON.stringify(Object.fromEntries(headers), null, 2));
              }
            }
          };
        }
      }
    ]
  });

  const { url } = await startStandaloneServer(server, {
    listen: { port: 4000 },
    context: async ({ req }) => {
      return {
        userid: req.headers['userid'] || req.headers['user-id'],
        userHeaders: req.headers
      };
    }
  });

  console.log(`🚀 Apollo Gateway ready at ${url}`);
  console.log('🌐 Federated subgraphs:');
  console.log('  - booking-subgraph (port 4001) - ACL enabled');
  console.log('  - hotel-subgraph (port 4002) - DataLoader enabled');
  console.log('  - promocode-subgraph (port 4003) - @override enabled');
}

startGateway().catch(error => {
  console.error('Failed to start Apollo Gateway:', error);
  process.exit(1);
});
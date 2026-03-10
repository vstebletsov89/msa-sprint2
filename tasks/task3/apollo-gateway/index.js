const { ApolloServer } = require('@apollo/server');
const { startStandaloneServer } = require('@apollo/server/standalone');
const { ApolloGateway, IntrospectAndCompose } = require('@apollo/gateway');

async function startGateway() {
  const gateway = new ApolloGateway({
    supergraphSdl: new IntrospectAndCompose({
      subgraphs: [
        { name: 'booking', url: 'http://booking-subgraph:4001/graphql' },
        { name: 'hotel', url: 'http://hotel-subgraph:4002/graphql' },
        { name: 'promocode', url: 'http://promocode-subgraph:4003/graphql' }
      ],
    }),
    debug: true
  });

  const server = new ApolloServer({
    gateway,
    introspection: true,
    plugins: [
      // Логирование запросов
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
      // Передаем все заголовки в подграфы
      return {
        headers: req.headers
      };
    }
  });

  console.log(`🚀 Apollo Gateway ready at ${url}`);
  console.log('🌐 Federated subgraphs:');
  console.log('  - booking-subgraph (port 4001) - ACL enabled');
  console.log('  - hotel-subgraph (port 4002) - DataLoader enabled');
  console.log('  - promocode-subgraph (port 4003) - @override enabled');
  console.log('');
  console.log('🧪 Test queries:');
  console.log('  - userBookings(userId: "test-user-1") - with userid header');
  console.log('  - hotels with booking references (tests N+1 solution)');
  console.log('  - discountPercent field (tests @override from promocode)');
}

startGateway().catch(error => {
  console.error('Failed to start Apollo Gateway:', error);
  process.exit(1);
});
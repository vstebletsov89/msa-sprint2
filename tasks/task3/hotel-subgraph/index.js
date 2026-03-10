const { ApolloServer } = require('@apollo/server');
const { startStandaloneServer } = require('@apollo/server/standalone');
const { buildSubgraphSchema } = require('@apollo/subgraph');
const DataLoader = require('dataloader');
const gql = require('graphql-tag');

const typeDefs = gql`
  type Hotel @key(fields: "id") {
    id: ID!
    name: String!
    city: String!
    address: String!
    rating: Float
    pricePerNight: Float!
  }

  type Query {
    hotel(id: ID!): Hotel
    hotelsByIds(ids: [ID!]!): [Hotel]!
    hotels: [Hotel!]!
  }
`;

// Mock данные отелей
const mockHotels = [
  {
    id: 'h1',
    name: 'Grand Seoul Hotel',
    city: 'Seoul',
    address: '123 Gangnam-gu, Seoul',
    rating: 4.8,
    pricePerNight: 200.0
  },
  {
    id: 'h2',
    name: 'Tokyo Imperial',
    city: 'Tokyo',
    address: '456 Shibuya, Tokyo',
    rating: 4.5,
    pricePerNight: 180.0
  },
  {
    id: 'h3',
    name: 'Busan Beach Resort',
    city: 'Busan',
    address: '789 Haeundae, Busan',
    rating: 4.2,
    pricePerNight: 150.0
  },
  {
    id: 'test-hotel-1',
    name: 'Test Hotel Seoul',
    city: 'Seoul',
    address: 'Test Address Seoul',
    rating: 4.0,
    pricePerNight: 100.0
  },
  {
    id: 'test-hotel-2',
    name: 'Test Hotel Tokyo',
    city: 'Tokyo',
    address: 'Test Address Tokyo',
    rating: 3.5,
    pricePerNight: 80.0
  }
];

// Функция для симуляции внешнего API вызова с батчингом
async function batchLoadHotels(ids) {
  console.log(`🔄 Batch loading hotels for IDs: [${ids.join(', ')}]`);

  // Симулируем задержку внешнего API
  await new Promise(resolve => setTimeout(resolve, 100));

  const hotels = ids.map(id => {
    const hotel = mockHotels.find(h => h.id === id);
    if (!hotel) {
      console.log(`⚠️ Hotel not found: ${id}`);
      return null;
    }
    return hotel;
  });

  console.log(`✅ Batch loaded ${hotels.filter(h => h).length} hotels`);
  return hotels;
}

// Создаем DataLoader для батчинга и кеширования
function createHotelLoader() {
  return new DataLoader(async (ids) => {
    return await batchLoadHotels(ids);
  }, {
    cache: true, // Кеширование включено
    batchScheduleFn: callback => setTimeout(callback, 10) // Небольшая задержка для батчинга
  });
}

const resolvers = {
  Query: {
    hotel: async (parent, { id }, { dataSources }) => {
      console.log(`🔍 Single hotel request: ${id}`);
      return await dataSources.hotelLoader.load(id);
    },

    hotelsByIds: async (parent, { ids }, { dataSources }) => {
      console.log(`🔍 Batch hotels request: [${ids.join(', ')}]`);
      return await dataSources.hotelLoader.loadMany(ids);
    },

    hotels: () => {
      console.log('🔍 All hotels request');
      return mockHotels;
    }
  },

  Hotel: {
    __resolveReference: async (hotel, { dataSources }) => {
      console.log(`🔄 Resolving hotel reference: ${hotel.id}`);

      // Используем DataLoader для батчинга и кеширования
      const resolvedHotel = await dataSources.hotelLoader.load(hotel.id);

      if (!resolvedHotel) {
        console.log(`❌ Hotel reference not resolved: ${hotel.id}`);
        return null;
      }

      console.log(`✅ Hotel reference resolved: ${resolvedHotel.name}`);
      return resolvedHotel;
    }
  }
};

async function startServer() {
  const server = new ApolloServer({
    schema: buildSubgraphSchema({ typeDefs, resolvers }),
    introspection: true
  });

  const { url } = await startStandaloneServer(server, {
    listen: { port: 4002 },
    context: async ({ req }) => ({
      headers: req.headers,
      dataSources: {
        hotelLoader: createHotelLoader() // Создаем новый DataLoader для каждого запроса
      }
    })
  });

  console.log(`🚀 Hotel subgraph ready at ${url}`);
  console.log('🎯 DataLoader configured for N+1 problem prevention');
}

startServer().catch(error => {
  console.error('Failed to start hotel subgraph:', error);
  process.exit(1);
});
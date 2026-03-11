const { ApolloServer } = require('@apollo/server');
const { startStandaloneServer } = require('@apollo/server/standalone');
const { buildSubgraphSchema } = require('@apollo/subgraph');
const gql = require('graphql-tag');

const typeDefs = gql`
  enum BookingStatus {
    PENDING
    CONFIRMED
    CANCELLED
  }

  type Booking @key(fields: "id") {
    id: ID!
    userId: ID!
    hotelId: ID!
    promoCode: String
    discountPercent: Float!
    checkIn: String!
    checkOut: String!
    status: BookingStatus!
    hotel: Hotel @provides(fields: "id")
  }

  extend type Hotel @key(fields: "id") {
    id: ID! @external
  }

  type Query {
    userBookings(userId: ID!): [Booking!]!
    booking(id: ID!): Booking
  }
`;

// Mock данные
const mockBookings = [
  {
    id: 'b1',
    userId: 'test-user-1',
    hotelId: 'h1',
    promoCode: 'SUMMER2024',
    discountPercent: 0.0,
    checkIn: '2024-07-01',
    checkOut: '2024-07-07',
    status: 'CONFIRMED'
  },
  {
    id: 'b2',
    userId: 'test-user-2',
    hotelId: 'h2',
    promoCode: null,
    discountPercent: 0.0,
    checkIn: '2024-08-15',
    checkOut: '2024-08-20',
    status: 'PENDING'
  },
  {
    id: 'b3',
    userId: 'test-user-1',
    hotelId: 'h3',
    promoCode: 'WINTER2024',
    discountPercent: 0.0,
    checkIn: '2024-12-01',
    checkOut: '2024-12-10',
    status: 'CONFIRMED'
  }
];

const resolvers = {
  Query: {
    userBookings: (parent, { userId }, { headers }) => {
      const requestingUserId = headers['userid'] || headers['user-id'];
      console.log(`🔐 ACL Check: requesting user=${requestingUserId}, target user=${userId}`);

      if (!requestingUserId) {
        console.log('❌ No userid in headers - access denied');
        throw new Error('Authentication required');
      }

      if (requestingUserId !== userId) {
        console.log(`❌ ACL violation: user ${requestingUserId} tried to access bookings of ${userId}`);
        throw new Error('Access denied: You can only view your own bookings');
      }

      console.log(`✅ ACL passed for user ${userId}`);
      return mockBookings.filter(booking => booking.userId === userId);
    },

    booking: (parent, { id }, { headers }) => {
      const booking = mockBookings.find(b => b.id === id);
      if (!booking) return null;

      const requestingUserId = headers['userid'] || headers['user-id'];
      if (!requestingUserId) {
        throw new Error('Authentication required');
      }

      if (requestingUserId !== booking.userId) {
        console.log(`❌ ACL violation: user ${requestingUserId} tried to access booking ${id} of ${booking.userId}`);
        throw new Error('Access denied: You can only view your own bookings');
      }

      return booking;
    }
  },

  Booking: {
    __resolveReference: (booking) => {
      return mockBookings.find(b => b.id === booking.id);
    },

    hotel: (booking) => {
      return { __typename: 'Hotel', id: booking.hotelId };
    }
  }
};

async function startServer() {
  const server = new ApolloServer({
    schema: buildSubgraphSchema({ typeDefs, resolvers }),
    introspection: true
  });

  const { url } = await startStandaloneServer(server, {
    listen: { port: 4001 },
    context: async ({ req }) => ({
      headers: req.headers
    })
  });

  console.log(`🚀 Booking subgraph ready at ${url}`);
  console.log('📋 Available headers for ACL: userid, user-id');
}

startServer().catch(error => {
  console.error('Failed to start booking subgraph:', error);
  process.exit(1);
});
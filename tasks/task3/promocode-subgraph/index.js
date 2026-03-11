const { ApolloServer } = require('@apollo/server');
const { startStandaloneServer } = require('@apollo/server/standalone');
const { buildSubgraphSchema } = require('@apollo/subgraph');
const gql = require('graphql-tag');

const typeDefs = gql`
  extend schema
    @link(url: "https://specs.apollo.dev/federation/v2.0",
          import: ["@key", "@external", "@override"])

  type Booking @key(fields: "id") {
    id: ID!
    discountPercent: Float! @override(from: "booking")
    discountInfo: DiscountInfo
  }

  type DiscountInfo {
    isValid: Boolean!
    originalDiscount: Float!
    finalDiscount: Float!
    description: String
    expiresAt: String
    applicableHotels: [ID!]!
  }

  type Query {
    validatePromoCode(code: String!, hotelId: ID): DiscountInfo!
    activePromoCodes: [DiscountInfo!]!
  }
`;

// Mock данные промокодов
const mockPromoCodes = {
  'SUMMER2024': {
    code: 'SUMMER2024',
    discount: 25.0,
    description: 'Summer vacation special',
    expiresAt: '2024-08-31T23:59:59Z',
    isActive: true,
    applicableHotels: ['h1', 'h2', 'test-hotel-1']
  },
  'WINTER2024': {
    code: 'WINTER2024',
    discount: 15.0,
    description: 'Winter holiday discount',
    expiresAt: '2024-12-31T23:59:59Z',
    isActive: true,
    applicableHotels: ['h1', 'h3', 'test-hotel-1']
  },
  'TESTCODE1': {
    code: 'TESTCODE1',
    discount: 10.0,
    description: 'Test promo code',
    expiresAt: '2025-12-31T23:59:59Z',
    isActive: true,
    applicableHotels: ['h1', 'h2', 'h3', 'test-hotel-1', 'test-hotel-2']
  },
  'EXPIRED': {
    code: 'EXPIRED',
    discount: 30.0,
    description: 'Expired promo code',
    expiresAt: '2023-12-31T23:59:59Z',
    isActive: false,
    applicableHotels: []
  }
};

// Хранилище промокодов бронирований (заполняется при resolveReference)
const bookingPromoCodes = new Map();

function validatePromoCode(code, hotelId = null) {
  const promo = mockPromoCodes[code];

  if (!promo) {
    return {
      isValid: false,
      originalDiscount: 0.0,
      finalDiscount: 0.0,
      description: 'Invalid promo code',
      expiresAt: null,
      applicableHotels: []
    };
  }

  const now = new Date();
  const expiryDate = new Date(promo.expiresAt);
  const isNotExpired = now <= expiryDate;
  const isHotelApplicable = !hotelId || promo.applicableHotels.includes(hotelId);

  const isValid = promo.isActive && isNotExpired && isHotelApplicable;

  return {
    isValid,
    originalDiscount: promo.discount,
    finalDiscount: isValid ? promo.discount : 0.0,
    description: promo.description,
    expiresAt: promo.expiresAt,
    applicableHotels: promo.applicableHotels
  };
}

const resolvers = {
  Query: {
    validatePromoCode: (parent, { code, hotelId }) => {
      console.log(`🎟️ Validating promo code: ${code} for hotel: ${hotelId || 'any'}`);
      return validatePromoCode(code, hotelId);
    },

    activePromoCodes: () => {
      console.log('🎟️ Getting all active promo codes');
      const now = new Date();

      return Object.values(mockPromoCodes)
          .filter(promo => promo.isActive && new Date(promo.expiresAt) > now)
          .map(promo => validatePromoCode(promo.code));
    }
  },

  Booking: {
    __resolveReference: (booking) => {
      console.log(`🔄 Resolving booking reference: ${booking.id}, promoCode: ${booking.promoCode}`);
      // Сохраняем promoCode из representation для использования в резолверах полей
      if (booking.promoCode !== undefined) {
        bookingPromoCodes.set(booking.id, booking.promoCode);
      }
      return { id: booking.id, promoCode: booking.promoCode };
    },

    discountPercent: (booking) => {
      const promoCode = booking.promoCode || bookingPromoCodes.get(booking.id);
      console.log(`💰 @override discountPercent for booking ${booking.id} with promo: ${promoCode}`);

      if (!promoCode) {
        return 0.0;
      }

      const discountInfo = validatePromoCode(promoCode);
      console.log(`💰 Calculated discount: ${discountInfo.finalDiscount}%`);
      return discountInfo.finalDiscount;
    },

    discountInfo: (booking) => {
      const promoCode = booking.promoCode || bookingPromoCodes.get(booking.id);
      console.log(`💰 Getting discount info for booking ${booking.id}, promo: ${promoCode}`);

      if (!promoCode) {
        return {
          isValid: false,
          originalDiscount: 0.0,
          finalDiscount: 0.0,
          description: 'No promo code applied',
          expiresAt: null,
          applicableHotels: []
        };
      }

      return validatePromoCode(promoCode);
    }
  }
};

async function startServer() {
  const server = new ApolloServer({
    schema: buildSubgraphSchema({ typeDefs, resolvers }),
    introspection: true
  });

  const { url } = await startStandaloneServer(server, {
    listen: { port: 4003 }
  });

  console.log(`🚀 Promocode subgraph ready at ${url}`);
  console.log('🎟️ @override configured for discountPercent field');
}

startServer().catch(error => {
  console.error('Failed to start promocode subgraph:', error);
  process.exit(1);
});
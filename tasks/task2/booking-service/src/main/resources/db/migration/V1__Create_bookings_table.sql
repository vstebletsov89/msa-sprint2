CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL,
    hotel_id VARCHAR(255) NOT NULL,
    promo_code VARCHAR(100),
    discount_percent DECIMAL(5,2) DEFAULT 0.00,
    price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT DEFAULT 0
);

-- Indexes for better query performance
CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_hotel_id ON bookings(hotel_id);
CREATE INDEX idx_bookings_created_at ON bookings(created_at);

-- Comments
COMMENT ON TABLE bookings IS 'Bookings made by users for hotels';
COMMENT ON COLUMN bookings.id IS 'Unique booking identifier';
COMMENT ON COLUMN bookings.user_id IS 'ID of the user who made the booking';
COMMENT ON COLUMN bookings.hotel_id IS 'ID of the booked hotel';
COMMENT ON COLUMN bookings.promo_code IS 'Applied promotional code';
COMMENT ON COLUMN bookings.discount_percent IS 'Discount percentage applied';
COMMENT ON COLUMN bookings.price IS 'Final price after discount';
COMMENT ON COLUMN bookings.created_at IS 'Booking creation timestamp';
COMMENT ON COLUMN bookings.version IS 'Version for optimistic locking';

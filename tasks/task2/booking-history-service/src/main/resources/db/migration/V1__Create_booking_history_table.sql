-- Create booking history table
CREATE TABLE booking_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    hotel_id VARCHAR(255) NOT NULL,
    promo_code VARCHAR(100),
    discount_percent DECIMAL(5,2) DEFAULT 0.00,
    price DECIMAL(10,2) NOT NULL,
    booking_created_at TIMESTAMP NOT NULL,
    event_id VARCHAR(255) NOT NULL UNIQUE,
    event_timestamp TIMESTAMP NOT NULL,
    processed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create booking statistics table  
CREATE TABLE booking_statistics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL,
    user_id VARCHAR(255),
    hotel_id VARCHAR(255),
    total_bookings BIGINT NOT NULL DEFAULT 0,
    total_revenue DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_discount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    avg_discount_percent DECIMAL(5,2) DEFAULT 0.00,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Essential indexes for booking_history (real use cases from ADR)
CREATE INDEX idx_booking_history_user_id ON booking_history(user_id);
CREATE INDEX idx_booking_history_hotel_id ON booking_history(hotel_id);
CREATE INDEX idx_booking_history_booking_created_at ON booking_history(booking_created_at);

-- Essential indexes for booking_statistics (analytics use cases)
CREATE INDEX idx_booking_statistics_date ON booking_statistics(date);
CREATE INDEX idx_booking_statistics_date_user ON booking_statistics(date, user_id);
CREATE INDEX idx_booking_statistics_date_hotel ON booking_statistics(date, hotel_id);

-- Unique constraint for statistics (one record per date/user/hotel combination)
CREATE UNIQUE INDEX idx_booking_statistics_unique ON booking_statistics(date, COALESCE(user_id, ''), COALESCE(hotel_id, ''));

-- Comments
COMMENT ON TABLE booking_history IS 'Historical records of all booking events received from Kafka';
COMMENT ON TABLE booking_statistics IS 'Aggregated booking statistics by day, user, and hotel';

COMMENT ON COLUMN booking_history.booking_id IS 'ID of the booking from the main booking service';
COMMENT ON COLUMN booking_history.event_id IS 'Unique event identifier for idempotency';
COMMENT ON COLUMN booking_history.booking_created_at IS 'When the booking was originally created';
COMMENT ON COLUMN booking_history.processed_at IS 'When this event was processed by history service';

COMMENT ON COLUMN booking_statistics.date IS 'Date for which statistics are calculated';
COMMENT ON COLUMN booking_statistics.user_id IS 'User ID (NULL for overall statistics)';
COMMENT ON COLUMN booking_statistics.hotel_id IS 'Hotel ID (NULL for overall statistics)';
COMMENT ON COLUMN booking_statistics.total_bookings IS 'Total number of bookings';
COMMENT ON COLUMN booking_statistics.total_revenue IS 'Total revenue after discounts';
COMMENT ON COLUMN booking_statistics.total_discount IS 'Total discount amount given';
COMMENT ON COLUMN booking_statistics.avg_discount_percent IS 'Average discount percentage';

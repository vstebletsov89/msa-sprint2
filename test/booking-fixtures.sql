-- Фикстуры для booking-service базы данных
DELETE FROM bookings;

-- Бронирования (для тестирования API /api/bookings)
INSERT INTO bookings (user_id, hotel_id, promo_code, discount_percent, price, created_at, version)
VALUES
('test-user-2', 'test-hotel-1', 'TESTCODE1', 10.0, 90.0, NOW(), 0),
('test-user-3', 'test-hotel-1', null, 0.0, 80.0, NOW(), 0);

package com.hotelio.history.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hotelio.history.entity.BookingHistory;
import com.hotelio.history.event.BookingCreatedEvent;
import com.hotelio.history.repository.BookingHistoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookingEventConsumer {

    private final BookingHistoryRepository bookingHistoryRepository;
    private final StatisticsService statisticsService;
    private final ObjectMapper objectMapper;

    @KafkaListener(topics = "booking-created", groupId = "booking-history-service")
    public void handleBookingCreatedEvent(
            String message,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset
    ) {
        log.info("📨 KAFKA MESSAGE RECEIVED: topic={} partition={} offset={} messageLength={}",
                topic, partition, offset, message != null ? message.length() : 0);

        if (message == null || message.isBlank()) {
            log.warn("⚠️ Empty message received from partition={}, offset={}", partition, offset);
            return;
        }

        try {
            BookingCreatedEvent event = objectMapper.readValue(message, BookingCreatedEvent.class);

            if (event == null || event.getEventId() == null) {
                log.warn("⚠️ Event is null or missing eventId from partition={}, offset={}", partition, offset);
                return;
            }

            log.info("✅ Deserialized event: bookingId={}, eventId={}, userId={}",
                    event.getBookingId(), event.getEventId(), event.getUserId());

            if (bookingHistoryRepository.findByEventId(event.getEventId()).isPresent()) {
                log.warn("🔁 Duplicate event received, skipping: eventId={}", event.getEventId());
                return;
            }

            processBookingEvent(event);

            log.info("✔️ SUCCESS: eventId={} processed and saved to DB", event.getEventId());

        } catch (Exception e) {
            log.error("❌ ERROR from partition={}, offset={}", partition, offset, e);
            log.error("Raw message: {}", message);
        }
    }

    @Transactional
    public void processBookingEvent(BookingCreatedEvent event) {

        if (bookingHistoryRepository.findByEventId(event.getEventId()).isPresent()) {
            log.warn("🔁 DUPLICATE event skipped: eventId={}", event.getEventId());
            return;
        }

        // IMPORTANT FIX
        var bookingCreatedAt = event.getCreatedAt() != null
                ? event.getCreatedAt()
                : event.getEventTimestamp();

        BookingHistory bookingHistory = BookingHistory.builder()
                .bookingId(event.getBookingId())
                .userId(event.getUserId())
                .hotelId(event.getHotelId())
                .promoCode(event.getPromoCode())
                .discountPercent(event.getDiscountPercent())
                .price(event.getPrice())
                .bookingCreatedAt(bookingCreatedAt)
                .eventId(event.getEventId())
                .eventTimestamp(event.getEventTimestamp())
                .build();

        BookingHistory saved = bookingHistoryRepository.save(bookingHistory);

        log.info("💾 SAVED booking history with ID: {} for booking: {}",
                saved.getId(), event.getBookingId());

        statisticsService.updateStatistics(event);
    }
}
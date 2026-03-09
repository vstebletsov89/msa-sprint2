package com.hotelio.history.service;

import com.fasterxml.jackson.core.JsonProcessingException;
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
        log.info("🎯 KAFKA MESSAGE RECEIVED: topic={} partition={} offset={} messageLength={} content={}", 
                topic, partition, offset, message != null ? message.length() : 0, message);

        try {
            // Deserialize JSON to event object
            BookingCreatedEvent event = objectMapper.readValue(message, BookingCreatedEvent.class);
            log.info("📋 Deserialized event: bookingId={}, eventId={}", 
                    event.getBookingId(), event.getEventId());

            // Check for duplicate events (idempotency)
            if (bookingHistoryRepository.findByEventId(event.getEventId()).isPresent()) {
                log.warn("⚠️ Duplicate event received, skipping: eventId={}", event.getEventId());
                return;
            }

            // Process within transaction
            processBookingEvent(event);

            log.info("✅ SUCCESS: eventId={} processed and saved", event.getEventId());

        } catch (Exception e) {
            log.error("❌ ERROR processing event from partition={}, offset={}: {}", 
                    partition, offset, e.getMessage(), e);
            // Don't rethrow - just log error and continue
        }
    }

    @Transactional
    public void processBookingEvent(BookingCreatedEvent event) {
        // Check for duplicate events (idempotency)
        if (bookingHistoryRepository.findByEventId(event.getEventId()).isPresent()) {
            log.warn("⚠️ DUPLICATE event skipped: eventId={}", event.getEventId());
            return;
        }

        // Create booking history record
        BookingHistory bookingHistory = BookingHistory.builder()
                .bookingId(event.getBookingId())
                .userId(event.getUserId())
                .hotelId(event.getHotelId())
                .promoCode(event.getPromoCode())
                .discountPercent(event.getDiscountPercent())
                .price(event.getPrice())
                .bookingCreatedAt(event.getCreatedAt())
                .eventId(event.getEventId())
                .eventTimestamp(event.getEventTimestamp())
                .build();

        BookingHistory saved = bookingHistoryRepository.save(bookingHistory);
        log.info("💾 SAVED booking history with ID: {}", saved.getId());

        // Update statistics
        statisticsService.updateStatistics(event);
    }
}

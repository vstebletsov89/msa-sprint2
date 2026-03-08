package com.hotelio.history.service;

import com.hotelio.history.entity.BookingHistory;
import com.hotelio.history.event.BookingCreatedEvent;
import com.hotelio.history.repository.BookingHistoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookingEventConsumer {

    private final BookingHistoryRepository bookingHistoryRepository;
    private final StatisticsService statisticsService;

    @KafkaListener(topics = "${kafka.topics.booking-created:booking-created}")
    @Transactional
    public void handleBookingCreatedEvent(
            @Payload BookingCreatedEvent event,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset,
            Acknowledgment acknowledgment
    ) {
        log.info("Received booking created event: bookingId={}, eventId={}, from topic={}, partition={}, offset={}", 
                event.getBookingId(), event.getEventId(), topic, partition, offset);

        try {
            // Check for duplicate events (idempotency)
            if (bookingHistoryRepository.findByEventId(event.getEventId()).isPresent()) {
                log.warn("Duplicate event received, skipping: eventId={}", event.getEventId());
                acknowledgment.acknowledge();
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

            bookingHistoryRepository.save(bookingHistory);

            // Update statistics
            statisticsService.updateStatistics(event);

            acknowledgment.acknowledge();
            log.info("Successfully processed booking created event: eventId={}", event.getEventId());

        } catch (Exception e) {
            log.error("Error processing booking created event: eventId={}", event.getEventId(), e);
            // Don't acknowledge - message will be retried or sent to DLQ
            throw e;
        }
    }
}

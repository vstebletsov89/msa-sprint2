package com.hotelio.booking.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hotelio.booking.event.BookingCreatedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Service
@RequiredArgsConstructor
@Slf4j
public class EventPublisherService {

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;

    @Value("${kafka.topics.booking-created:booking-created}")
    private String bookingCreatedTopic;

    public void publishBookingCreatedEvent(BookingCreatedEvent event) {
        log.info("📤 STARTING publish: bookingId={} eventId={} topic={}", 
                event.getBookingId(), event.getEventId(), bookingCreatedTopic);

        try {
            String json = objectMapper.writeValueAsString(event);
            log.info("📝 JSON serialized: length={} content={}", json.length(), json);

            CompletableFuture<SendResult<String, String>> future = 
                    kafkaTemplate.send(bookingCreatedTopic, event.getBookingId(), json);

            future.whenComplete((result, throwable) -> {
                if (throwable != null) {
                    log.error("❌ KAFKA SEND FAILED: bookingId={} topic={} error={}", 
                            event.getBookingId(), bookingCreatedTopic, throwable.getMessage(), throwable);
                } else {
                    log.info("✅ KAFKA SEND SUCCESS: bookingId={} topic={} partition={} offset={} timestamp={}", 
                            event.getBookingId(), 
                            bookingCreatedTopic,
                            result.getRecordMetadata().partition(),
                            result.getRecordMetadata().offset(),
                            result.getRecordMetadata().timestamp());
                }
            });

            log.info("📨 Send request submitted for bookingId={}", event.getBookingId());

        } catch (Exception e) {
            log.error("❌ PUBLISH FAILED: bookingId={} error={}", 
                    event.getBookingId(), e.getMessage(), e);
        }
    }
}

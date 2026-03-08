package com.hotelio.booking.service;

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

    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Value("${kafka.topics.booking-created:booking-created}")
    private String bookingCreatedTopic;

    public void publishBookingCreatedEvent(BookingCreatedEvent event) {
        log.info("Publishing booking created event for bookingId: {}", event.getBookingId());

        CompletableFuture<SendResult<String, Object>> future = 
            kafkaTemplate.send(bookingCreatedTopic, event.getBookingId(), event);

        future.whenComplete((result, exception) -> {
            if (exception == null) {
                log.info("Successfully published booking created event for bookingId: {} with offset: {}",
                        event.getBookingId(), result.getRecordMetadata().offset());
            } else {
                log.error("Failed to publish booking created event for bookingId: {}", 
                        event.getBookingId(), exception);
            }
        });
    }
}

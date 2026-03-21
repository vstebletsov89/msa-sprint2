package com.hotelio.booking.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class KafkaConfig {

    @Value("${kafka.topics.booking-created:booking-created}")
    private String bookingCreatedTopic;

    @Bean
    public NewTopic bookingCreatedTopic() {
        return TopicBuilder
                .name(bookingCreatedTopic)
                .partitions(1)
                .replicas(1)
                .build();
    }
}

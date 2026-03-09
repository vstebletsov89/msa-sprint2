package com.hotelio.history.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import javax.annotation.PostConstruct;

@Configuration
@Slf4j
public class KafkaConsumerConfig {

    @Value("${spring.kafka.bootstrap-servers:kafka:9092}")
    private String bootstrapServers;

    @PostConstruct
    public void init() {
        log.info("🚀 KAFKA CONSUMER CONFIG INITIALIZED: bootstrapServers={}", bootstrapServers);
        log.info("🎧 Waiting for messages on topic: booking-created");
        log.info("👥 Consumer group: booking-history-service");
    }
}

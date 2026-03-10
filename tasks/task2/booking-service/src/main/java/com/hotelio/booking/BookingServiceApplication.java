package com.hotelio.booking;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.kafka.annotation.EnableKafka;

@SpringBootApplication
@EnableKafka
public class BookingServiceApplication {

    public static void main(String[] args) {
        System.out.println("BOOKING SERVICE STARTING - CODE VERSION: 2026-03-09-v5-DEBUG");
        ConfigurableApplicationContext context = SpringApplication.run(BookingServiceApplication.class, args);

        // Проверяем что EventPublisherService действительно загрузился
        try {
            Object eventPublisher = context.getBean("eventPublisherService");
            System.out.println("EventPublisherService bean found: " + eventPublisher.getClass().getName());
        } catch (Exception e) {
            System.out.println("EventPublisherService bean NOT FOUND: " + e.getMessage());
        }

        System.out.println("BOOKING SERVICE STARTED SUCCESSFULLY");
    }
}

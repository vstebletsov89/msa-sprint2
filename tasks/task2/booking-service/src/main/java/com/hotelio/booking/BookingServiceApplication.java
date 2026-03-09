package com.hotelio.booking;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.EnableKafka;

@SpringBootApplication
@EnableKafka
public class BookingServiceApplication {

    public static void main(String[] args) {
        System.out.println("🚀 BOOKING SERVICE STARTING - CODE VERSION: 2026-03-09-v2");
        SpringApplication.run(BookingServiceApplication.class, args);
        System.out.println("✅ BOOKING SERVICE STARTED SUCCESSFULLY");
    }
}

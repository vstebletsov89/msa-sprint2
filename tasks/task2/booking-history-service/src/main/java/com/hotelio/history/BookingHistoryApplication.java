package com.hotelio.history;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.EnableKafka;

@SpringBootApplication
@EnableKafka
public class BookingHistoryApplication {

    public static void main(String[] args) {
        System.out.println("BOOKING HISTORY SERVICE STARTING - CODE VERSION: 2026-03-09-v3");
        SpringApplication.run(BookingHistoryApplication.class, args);
        System.out.println("BOOKING HISTORY SERVICE STARTED SUCCESSFULLY");
    }
}

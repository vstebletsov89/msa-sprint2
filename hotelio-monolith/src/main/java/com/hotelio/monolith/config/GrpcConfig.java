package com.hotelio.monolith.config;

import com.hotelio.proto.booking.BookingServiceGrpc;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PreDestroy;
import java.util.concurrent.TimeUnit;

@Configuration
public class GrpcConfig {

    @Value("${booking.service.external-host:booking-service}")
    private String host;

    @Value("${booking.service.external-port:9090}")
    private int port;

    @Bean
    public ManagedChannel bookingGrpcChannel() {
        return ManagedChannelBuilder
                .forAddress(host, port)
                .usePlaintext()
                .build();
    }

    @Bean
    public BookingServiceGrpc.BookingServiceBlockingStub bookingServiceStub(
            ManagedChannel bookingGrpcChannel) {

        return BookingServiceGrpc.newBlockingStub(bookingGrpcChannel);
    }
}

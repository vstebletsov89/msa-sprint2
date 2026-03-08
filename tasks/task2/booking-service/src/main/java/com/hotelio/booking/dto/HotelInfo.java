package com.hotelio.booking.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HotelInfo {
    private String id;
    private String name;
    private String city;
    private BigDecimal rating;
    private BigDecimal pricePerNight;

        public boolean isOperational() {
            return operational;
        }

        public boolean isFullyBooked() {
            return fullyBooked;
        }
    private boolean operational;
    private boolean fullyBooked;
}

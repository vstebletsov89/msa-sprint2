package com.hotelio.history.event;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BookingCreatedEvent {
    private String bookingId;
    private String userId;
    private String hotelId;
    private String promoCode;
    private BigDecimal discountPercent;
    private BigDecimal price;
    private LocalDateTime createdAt;
    private String eventId;
    private LocalDateTime eventTimestamp;
}

package com.hotelio.history.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "booking_statistics")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BookingStatistics {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "date", nullable = false)
    private LocalDate date;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "hotel_id")
    private String hotelId;

    @Column(name = "total_bookings", nullable = false)
    private Long totalBookings;

    @Column(name = "total_revenue", nullable = false, precision = 12, scale = 2)
    private BigDecimal totalRevenue;

    @Column(name = "total_discount", nullable = false, precision = 12, scale = 2)
    private BigDecimal totalDiscount;

    @Column(name = "avg_discount_percent", precision = 5, scale = 2)
    private BigDecimal avgDiscountPercent;

    @Column(name = "last_updated", nullable = false)
    private LocalDateTime lastUpdated;

    // Unique constraint on date + userId + hotelId combination
    @Table(uniqueConstraints = {
        @UniqueConstraint(columnNames = {"date", "user_id", "hotel_id"})
    })
    public static class Constraint {}
}

package com.hotelio.history.service;

import com.hotelio.history.entity.BookingStatistics;
import com.hotelio.history.event.BookingCreatedEvent;
import com.hotelio.history.repository.BookingStatisticsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class StatisticsService {

    private final BookingStatisticsRepository statisticsRepository;

    @Transactional
    public void updateStatistics(BookingCreatedEvent event) {
        LocalDate eventDate = event.getCreatedAt().toLocalDate();

        // Update daily statistics by user
        updateUserStatistics(eventDate, event);

        // Update daily statistics by hotel
        updateHotelStatistics(eventDate, event);

        // Update overall daily statistics
        updateDailyStatistics(eventDate, event);

        log.debug("Updated statistics for booking: {}", event.getBookingId());
    }

    private void updateUserStatistics(LocalDate date, BookingCreatedEvent event) {
        Optional<BookingStatistics> existing = statisticsRepository
                .findByDateAndUserIdAndHotelIdIsNull(date, event.getUserId());

        BookingStatistics stats;
        if (existing.isPresent()) {
            stats = existing.get();
            stats.setTotalBookings(stats.getTotalBookings() + 1);
            stats.setTotalRevenue(stats.getTotalRevenue().add(event.getPrice()));

            BigDecimal eventDiscount = calculateDiscountAmount(event.getPrice(), event.getDiscountPercent());
            stats.setTotalDiscount(stats.getTotalDiscount().add(eventDiscount));

            // Recalculate average discount percentage
            if (stats.getTotalRevenue().compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal avgDiscountPercent = stats.getTotalDiscount()
                        .multiply(BigDecimal.valueOf(100))
                        .divide(stats.getTotalRevenue().add(stats.getTotalDiscount()), 2, RoundingMode.HALF_UP);
                stats.setAvgDiscountPercent(avgDiscountPercent);
            }

            stats.setLastUpdated(LocalDateTime.now());
        } else {
            BigDecimal discountAmount = calculateDiscountAmount(event.getPrice(), event.getDiscountPercent());
            stats = BookingStatistics.builder()
                    .date(date)
                    .userId(event.getUserId())
                    .totalBookings(1L)
                    .totalRevenue(event.getPrice())
                    .totalDiscount(discountAmount)
                    .avgDiscountPercent(event.getDiscountPercent())
                    .lastUpdated(LocalDateTime.now())
                    .build();
        }

        statisticsRepository.save(stats);
    }

    private void updateHotelStatistics(LocalDate date, BookingCreatedEvent event) {
        Optional<BookingStatistics> existing = statisticsRepository
                .findByDateAndHotelIdAndUserIdIsNull(date, event.getHotelId());

        BookingStatistics stats;
        if (existing.isPresent()) {
            stats = existing.get();
            stats.setTotalBookings(stats.getTotalBookings() + 1);
            stats.setTotalRevenue(stats.getTotalRevenue().add(event.getPrice()));

            BigDecimal eventDiscount = calculateDiscountAmount(event.getPrice(), event.getDiscountPercent());
            stats.setTotalDiscount(stats.getTotalDiscount().add(eventDiscount));

            // Recalculate average discount percentage
            if (stats.getTotalRevenue().compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal avgDiscountPercent = stats.getTotalDiscount()
                        .multiply(BigDecimal.valueOf(100))
                        .divide(stats.getTotalRevenue().add(stats.getTotalDiscount()), 2, RoundingMode.HALF_UP);
                stats.setAvgDiscountPercent(avgDiscountPercent);
            }

            stats.setLastUpdated(LocalDateTime.now());
        } else {
            BigDecimal discountAmount = calculateDiscountAmount(event.getPrice(), event.getDiscountPercent());
            stats = BookingStatistics.builder()
                    .date(date)
                    .hotelId(event.getHotelId())
                    .totalBookings(1L)
                    .totalRevenue(event.getPrice())
                    .totalDiscount(discountAmount)
                    .avgDiscountPercent(event.getDiscountPercent())
                    .lastUpdated(LocalDateTime.now())
                    .build();
        }

        statisticsRepository.save(stats);
    }

    private void updateDailyStatistics(LocalDate date, BookingCreatedEvent event) {
        Optional<BookingStatistics> existing = statisticsRepository
                .findByDateAndUserIdIsNullAndHotelIdIsNull(date);

        BookingStatistics stats;
        if (existing.isPresent()) {
            stats = existing.get();
            stats.setTotalBookings(stats.getTotalBookings() + 1);
            stats.setTotalRevenue(stats.getTotalRevenue().add(event.getPrice()));

            BigDecimal eventDiscount = calculateDiscountAmount(event.getPrice(), event.getDiscountPercent());
            stats.setTotalDiscount(stats.getTotalDiscount().add(eventDiscount));

            // Recalculate average discount percentage
            if (stats.getTotalRevenue().compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal avgDiscountPercent = stats.getTotalDiscount()
                        .multiply(BigDecimal.valueOf(100))
                        .divide(stats.getTotalRevenue().add(stats.getTotalDiscount()), 2, RoundingMode.HALF_UP);
                stats.setAvgDiscountPercent(avgDiscountPercent);
            }

            stats.setLastUpdated(LocalDateTime.now());
        } else {
            BigDecimal discountAmount = calculateDiscountAmount(event.getPrice(), event.getDiscountPercent());
            stats = BookingStatistics.builder()
                    .date(date)
                    .totalBookings(1L)
                    .totalRevenue(event.getPrice())
                    .totalDiscount(discountAmount)
                    .avgDiscountPercent(event.getDiscountPercent())
                    .lastUpdated(LocalDateTime.now())
                    .build();
        }

        statisticsRepository.save(stats);
    }

    private BigDecimal calculateDiscountAmount(BigDecimal price, BigDecimal discountPercent) {
        if (discountPercent == null || discountPercent.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }

        // Calculate original price before discount
        BigDecimal originalPrice = price.divide(
                BigDecimal.ONE.subtract(discountPercent.divide(BigDecimal.valueOf(100))), 
                2, RoundingMode.HALF_UP);

        return originalPrice.subtract(price);
    }
}

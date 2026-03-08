package com.hotelio.booking.service;

import com.hotelio.booking.dto.HotelInfo;
import com.hotelio.booking.dto.PromoCodeInfo;
import com.hotelio.booking.dto.UserInfo;
import com.hotelio.booking.entity.Booking;
import com.hotelio.booking.event.BookingCreatedEvent;
import com.hotelio.booking.repository.BookingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookingBusinessService {

    private final BookingRepository bookingRepository;
    private final ExternalServiceClient externalServiceClient;
    private final EventPublisherService eventPublisherService;

    @Transactional
    public Booking createBooking(String userId, String hotelId, String promoCode) {
        log.info("Creating booking: userId={}, hotelId={}, promoCode={}", userId, hotelId, promoCode);

        // Exact logic from monolith
        validateUser(userId);
        validateHotel(hotelId);

        double basePrice = resolveBasePrice(userId);
        double discount = resolvePromoDiscount(promoCode, userId);

        double finalPrice = basePrice - discount;
        log.info("Final price calculated: base={}, discount={}, final={}", basePrice, discount, finalPrice);

        // Create booking exactly like monolith
        Booking booking = Booking.builder()
                .userId(userId)
                .hotelId(hotelId)
                .promoCode(promoCode)
                .discountPercent(BigDecimal.valueOf(discount)) // This stores absolute discount amount
                .price(BigDecimal.valueOf(finalPrice))
                .build();

        booking = bookingRepository.save(booking);

        // Publish event
        publishBookingCreatedEvent(booking);

        log.info("Booking created successfully with ID: {}", booking.getId());
        return booking;
    }

    @Transactional(readOnly = true)
    public List<Booking> getBookingsByUserId(String userId) {
        log.debug("Fetching bookings for userId: {}", userId);
        return bookingRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    private void validateUser(String userId) {
        UserInfo userInfo = externalServiceClient.getUserInfo(userId);
        if (userInfo == null || !userInfo.isActive()) {
            log.warn("User {} is inactive", userId);
            throw new IllegalArgumentException("User is inactive");
        }
        if (userInfo.isBlacklisted()) {
            log.warn("User {} is blacklisted", userId);
            throw new IllegalArgumentException("User is blacklisted");
        }
    }

    private void validateHotel(String hotelId) {
        HotelInfo hotelInfo = externalServiceClient.getHotelInfo(hotelId);
        if (hotelInfo == null || !hotelInfo.isOperational()) {
            log.warn("Hotel {} is not operational", hotelId);
            throw new IllegalArgumentException("Hotel is not operational");
        }

        // Check reviews exactly like in monolith
        boolean isTrusted = externalServiceClient.isHotelTrusted(hotelId);
        if (!isTrusted) {
            log.warn("Hotel {} is not trusted", hotelId);
            throw new IllegalArgumentException("Hotel is not trusted based on reviews");
        }

        if (hotelInfo.isFullyBooked()) {
            log.warn("Hotel {} is fully booked", hotelId);
            throw new IllegalArgumentException("Hotel is fully booked");
        }
    }

    private double resolveBasePrice(String userId) {
        UserInfo userInfo = externalServiceClient.getUserInfo(userId);
        if (userInfo != null && userInfo.getStatus() != null) {
            boolean isVip = "VIP".equalsIgnoreCase(userInfo.getStatus());
            log.debug("User {} has status '{}', base price is {}", userId, userInfo.getStatus(), isVip ? 80.0 : 100.0);
            return isVip ? 80.0 : 100.0;
        } else {
            log.debug("User {} has unknown status, default base price 100.0", userId);
            return 100.0;
        }
    }

    private double resolvePromoDiscount(String promoCode, String userId) {
        if (promoCode == null) return 0.0;

        PromoCodeInfo promo = externalServiceClient.validatePromoCode(promoCode, userId);
        if (promo == null || !promo.isActive()) {
            log.info("Promo code '{}' is invalid or not applicable for user {}", promoCode, userId);
            return 0.0;
        }

        // In monolith, promo.getDiscount() returns absolute discount amount
        double discountAmount = promo.getDiscount() != null ? promo.getDiscount().doubleValue() : 0.0;
        log.debug("Promo code '{}' applied with discount {}", promoCode, discountAmount);
        return discountAmount;
    }


    private void publishBookingCreatedEvent(Booking booking) {
        BookingCreatedEvent event = BookingCreatedEvent.builder()
                .bookingId(booking.getId().toString())
                .userId(booking.getUserId())
                .hotelId(booking.getHotelId())
                .promoCode(booking.getPromoCode())
                .discountPercent(booking.getDiscountPercent())
                .price(booking.getPrice())
                .createdAt(booking.getCreatedAt())
                .eventId(UUID.randomUUID().toString())
                .eventTimestamp(LocalDateTime.now())
                .build();

        eventPublisherService.publishBookingCreatedEvent(event);
    }
}

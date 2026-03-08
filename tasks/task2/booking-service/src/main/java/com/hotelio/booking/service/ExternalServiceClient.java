package com.hotelio.booking.service;

import com.hotelio.booking.dto.HotelInfo;
import com.hotelio.booking.dto.PromoCodeInfo;
import com.hotelio.booking.dto.UserInfo;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
@Slf4j
public class ExternalServiceClient {

    private final RestTemplate restTemplate;

    @Value("${external.monolith.base-url}")
    private String monolithBaseUrl;

    @CircuitBreaker(name = "user-service", fallbackMethod = "getUserInfoFallback")
    @Retry(name = "user-service")
    public UserInfo getUserInfo(String userId) {
        log.debug("Fetching user info for userId: {}", userId);

        String url = monolithBaseUrl + "/users/" + userId;
        ResponseEntity<UserInfo> response = restTemplate.getForEntity(url, UserInfo.class);

        if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
            return response.getBody();
        }

        throw new RuntimeException("Failed to fetch user info for userId: " + userId);
    }

    @CircuitBreaker(name = "hotel-service", fallbackMethod = "getHotelInfoFallback")
    @Retry(name = "hotel-service")
    public HotelInfo getHotelInfo(String hotelId) {
        log.debug("Fetching hotel info for hotelId: {}", hotelId);

        String url = monolithBaseUrl + "/hotels/" + hotelId;
        ResponseEntity<HotelInfo> response = restTemplate.getForEntity(url, HotelInfo.class);

        if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
            return response.getBody();
        }

        throw new RuntimeException("Failed to fetch hotel info for hotelId: " + hotelId);
    }

    @CircuitBreaker(name = "promocode-service", fallbackMethod = "validatePromoCodeFallback")
    @Retry(name = "promocode-service")
    public PromoCodeInfo validatePromoCode(String promoCode, String userId) {
        if (promoCode == null || promoCode.trim().isEmpty()) {
            return null;
        }

        log.debug("Validating promo code: {} for userId: {}", promoCode, userId);

        String url = monolithBaseUrl + "/promos/validate?code=" + promoCode + "&userId=" + userId;
        ResponseEntity<PromoCodeInfo> response = restTemplate.postForEntity(url, null, PromoCodeInfo.class);

        if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
            PromoCodeInfo promoInfo = response.getBody();
            // In monolith, the discount field contains absolute discount amount
            // The external service should already return the correct discount amount
            return promoInfo;
        }

        return null; // Invalid promo code
    }

    @CircuitBreaker(name = "review-service", fallbackMethod = "isHotelTrustedFallback")
    @Retry(name = "review-service")
    public boolean isHotelTrusted(String hotelId) {
        log.debug("Checking if hotel is trusted: {}", hotelId);

        // Use the same endpoint pattern as monolith uses internally
        String url = monolithBaseUrl + "/api/reviews/trusted/" + hotelId;
        ResponseEntity<Boolean> response = restTemplate.getForEntity(url, Boolean.class);

        if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
            return response.getBody();
        }

        return true; // Default to trusted if service is unavailable
    }

    // Fallback methods
    public UserInfo getUserInfoFallback(String userId, Exception ex) {
        log.warn("Fallback triggered for getUserInfo with userId: {}, error: {}", userId, ex.getMessage());
        return UserInfo.builder()
                .id(userId)
                .status("STANDARD") // Default non-VIP status
                .active(true)
                .blacklisted(false)
                .vip(false)
                .build();
    }

    public HotelInfo getHotelInfoFallback(String hotelId, Exception ex) {
        log.warn("Fallback triggered for getHotelInfo with hotelId: {}, error: {}", hotelId, ex.getMessage());
        return HotelInfo.builder()
                .id(hotelId)
                .name("Unknown Hotel")
                .operational(true)
                .fullyBooked(false)
                .pricePerNight(BigDecimal.valueOf(100.0))
                .build();
    }

    public PromoCodeInfo validatePromoCodeFallback(String promoCode, String userId, Exception ex) {
        log.warn("Fallback triggered for validatePromoCode with code: {}, userId: {}, error: {}", 
                promoCode, userId, ex.getMessage());
        return null; // No discount in case of failure
    }

    public boolean isHotelTrustedFallback(String hotelId, Exception ex) {
        log.warn("Fallback triggered for isHotelTrusted with hotelId: {}, error: {}", hotelId, ex.getMessage());
        return true; // Default to trusted
    }
}

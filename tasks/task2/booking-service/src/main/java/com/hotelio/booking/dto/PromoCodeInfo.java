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
public class PromoCodeInfo {
    private String code;
    private BigDecimal discountPercent;
    private BigDecimal discount; // Absolute discount amount from monolith

        public boolean isActive() {
            return active;
        }
    private boolean active;
    private boolean vipOnly;
}

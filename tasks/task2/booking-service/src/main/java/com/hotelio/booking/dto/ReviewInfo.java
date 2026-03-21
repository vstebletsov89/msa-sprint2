package com.hotelio.booking.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReviewInfo {
    private String hotelId;
    private double averageRating;
    private boolean trusted;

}

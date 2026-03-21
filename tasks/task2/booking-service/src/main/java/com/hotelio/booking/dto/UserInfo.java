package com.hotelio.booking.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserInfo {
    private String id;
    private String status;
    private boolean blacklisted;
    private boolean active;
    private boolean vip;

    public boolean isActive() {
        return active;
    }

    public boolean isBlacklisted() {
        return blacklisted;
    }

    public boolean isVip() {
        return vip;
    }
}

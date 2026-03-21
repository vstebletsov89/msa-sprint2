package com.hotelio.history.repository;

import com.hotelio.history.entity.BookingHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BookingHistoryRepository extends JpaRepository<BookingHistory, UUID> {

    Optional<BookingHistory> findByEventId(String eventId);

    @Query("SELECT bh FROM BookingHistory bh WHERE bh.userId = :userId ORDER BY bh.bookingCreatedAt DESC")
    List<BookingHistory> findByUserIdOrderByBookingCreatedAtDesc(@Param("userId") String userId);

    @Query("SELECT bh FROM BookingHistory bh WHERE bh.hotelId = :hotelId ORDER BY bh.bookingCreatedAt DESC")
    List<BookingHistory> findByHotelIdOrderByBookingCreatedAtDesc(@Param("hotelId") String hotelId);

    @Query("SELECT COUNT(bh) FROM BookingHistory bh WHERE bh.bookingCreatedAt BETWEEN :startDate AND :endDate")
    long countBookingsByDateRange(@Param("startDate") LocalDateTime startDate, @Param("endDate") LocalDateTime endDate);

    @Query("SELECT COUNT(bh) FROM BookingHistory bh WHERE bh.userId = :userId")
    long countByUserId(@Param("userId") String userId);

    @Query("SELECT COUNT(bh) FROM BookingHistory bh WHERE bh.hotelId = :hotelId")
    long countByHotelId(@Param("hotelId") String hotelId);

    @Query("SELECT SUM(bh.price) FROM BookingHistory bh WHERE bh.bookingCreatedAt BETWEEN :startDate AND :endDate")
    BigDecimal sumRevenueByDateRange(@Param("startDate") LocalDateTime startDate, @Param("endDate") LocalDateTime endDate);
}

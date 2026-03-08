package com.hotelio.booking.repository;

import com.hotelio.booking.entity.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface BookingRepository extends JpaRepository<Booking, UUID> {

    @Query("SELECT b FROM Booking b WHERE b.userId = :userId ORDER BY b.createdAt DESC")
    List<Booking> findByUserIdOrderByCreatedAtDesc(@Param("userId") String userId);

    @Query("SELECT COUNT(b) FROM Booking b WHERE b.userId = :userId")
    long countByUserId(@Param("userId") String userId);

    @Query("SELECT COUNT(b) FROM Booking b WHERE b.hotelId = :hotelId")
    long countByHotelId(@Param("hotelId") String hotelId);
}

package com.hotelio.history.repository;

import com.hotelio.history.entity.BookingStatistics;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BookingStatisticsRepository extends JpaRepository<BookingStatistics, UUID> {

    Optional<BookingStatistics> findByDateAndUserIdAndHotelIdIsNull(LocalDate date, String userId);

    Optional<BookingStatistics> findByDateAndHotelIdAndUserIdIsNull(LocalDate date, String hotelId);

    Optional<BookingStatistics> findByDateAndUserIdIsNullAndHotelIdIsNull(LocalDate date);

    @Query("SELECT bs FROM BookingStatistics bs WHERE bs.date BETWEEN :startDate AND :endDate AND bs.userId IS NULL AND bs.hotelId IS NULL ORDER BY bs.date DESC")
    List<BookingStatistics> findDailyStatistics(@Param("startDate") LocalDate startDate, @Param("endDate") LocalDate endDate);

    @Query("SELECT bs FROM BookingStatistics bs WHERE bs.date BETWEEN :startDate AND :endDate AND bs.userId = :userId AND bs.hotelId IS NULL ORDER BY bs.date DESC")
    List<BookingStatistics> findUserStatistics(@Param("startDate") LocalDate startDate, @Param("endDate") LocalDate endDate, @Param("userId") String userId);

    @Query("SELECT bs FROM BookingStatistics bs WHERE bs.date BETWEEN :startDate AND :endDate AND bs.hotelId = :hotelId AND bs.userId IS NULL ORDER BY bs.date DESC")
    List<BookingStatistics> findHotelStatistics(@Param("startDate") LocalDate startDate, @Param("endDate") LocalDate endDate, @Param("hotelId") String hotelId);
}

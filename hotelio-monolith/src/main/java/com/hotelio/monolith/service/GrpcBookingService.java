package com.hotelio.monolith.service;

import com.hotelio.monolith.entity.Booking;
import com.hotelio.monolith.repository.BookingRepository;
import com.hotelio.proto.booking.BookingRequest;
import com.hotelio.proto.booking.BookingResponse;
import com.hotelio.proto.booking.BookingServiceGrpc;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Primary
@Service
public class GrpcBookingService extends BookingService {

    private static final Logger logger = LoggerFactory.getLogger(GrpcBookingService.class);

    private final BookingServiceGrpc.BookingServiceBlockingStub stub;
    private final BookingRepository bookingRepository;

    public GrpcBookingService(
            BookingServiceGrpc.BookingServiceBlockingStub stub,
            BookingRepository bookingRepository,
            PromoCodeService promoCodeService,
            ReviewService reviewService,
            AppUserService userService,
            HotelService hotelService
    ) {
        super(bookingRepository, promoCodeService, reviewService, userService, hotelService);
        this.stub = stub;
        this.bookingRepository = bookingRepository;

        logger.info("Using GRPC BookingService");
    }

    /**
     * GET /api/bookings — читаем локальную БД монолита
     */
    @Override
    public List<Booking> listAll(String userId) {
        logger.info("GrpcBookingService.listAll called with userId={}", userId);
        return userId != null
                ? bookingRepository.findByUserId(userId)
                : bookingRepository.findAll();
    }

    /**
     * POST /api/bookings — отправляем в booking-service через gRPC
     */
    @Override
    public Booking createBooking(String userId, String hotelId, String promoCode) {

        logger.info("GrpcBookingService.createBooking: userId={}, hotelId={}, promoCode={}",
                userId, hotelId, promoCode);

        BookingRequest request = BookingRequest.newBuilder()
                .setUserId(userId)
                .setHotelId(hotelId)
                .setPromoCode(promoCode != null ? promoCode : "")
                .build();

        BookingResponse response = stub.createBooking(request);

        return map(response);
    }

    private Booking map(BookingResponse response) {

        Booking booking = new Booking();

        booking.setId(Math.abs(response.getId().hashCode()) * 1L);
        booking.setUserId(response.getUserId());
        booking.setHotelId(response.getHotelId());

        booking.setPromoCode(
                response.getPromoCode().isEmpty() ? null : response.getPromoCode()
        );

        booking.setDiscountPercent(response.getDiscountPercent());
        booking.setPrice(response.getPrice());

        booking.setCreatedAt(
                Instant.parse(response.getCreatedAt() + "Z")
        );

        return booking;
    }
}
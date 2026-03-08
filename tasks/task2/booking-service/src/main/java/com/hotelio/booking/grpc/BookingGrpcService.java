package com.hotelio.booking.grpc;

import com.hotelio.booking.entity.Booking;
import com.hotelio.booking.service.BookingBusinessService;
import com.hotelio.proto.booking.*;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.devh.boot.grpc.server.service.GrpcService;

import java.time.format.DateTimeFormatter;
import java.util.List;

@GrpcService
@RequiredArgsConstructor
@Slf4j
public class BookingGrpcService extends BookingServiceGrpc.BookingServiceImplBase {

    private final BookingBusinessService bookingBusinessService;
    private static final DateTimeFormatter ISO_FORMATTER = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    @Override
    public void createBooking(BookingRequest request, StreamObserver<BookingResponse> responseObserver) {
        try {
            log.info("Received createBooking request for userId: {}, hotelId: {}", 
                    request.getUserId(), request.getHotelId());

            // Validate request
            validateCreateBookingRequest(request);

            // Create booking
            Booking booking = bookingBusinessService.createBooking(
                    request.getUserId(),
                    request.getHotelId(),
                    request.getPromoCode().isEmpty() ? null : request.getPromoCode()
            );

            // Build response
            BookingResponse response = BookingResponse.newBuilder()
                    .setId(booking.getId().toString())
                    .setUserId(booking.getUserId())
                    .setHotelId(booking.getHotelId())
                    .setPromoCode(booking.getPromoCode() != null ? booking.getPromoCode() : "")
                    .setDiscountPercent(booking.getDiscountPercent().doubleValue())
                    .setPrice(booking.getPrice().doubleValue())
                    .setCreatedAt(booking.getCreatedAt().format(ISO_FORMATTER))
                    .build();

            responseObserver.onNext(response);
            responseObserver.onCompleted();

            log.info("Successfully created booking with ID: {}", booking.getId());

        } catch (IllegalArgumentException e) {
            log.warn("Invalid booking request: {}", e.getMessage());
            responseObserver.onError(Status.INVALID_ARGUMENT
                    .withDescription(e.getMessage())
                    .asRuntimeException());
        } catch (Exception e) {
            log.error("Error creating booking", e);
            responseObserver.onError(Status.INTERNAL
                    .withDescription("Internal server error")
                    .asRuntimeException());
        }
    }

    @Override
    public void listBookings(BookingListRequest request, StreamObserver<BookingListResponse> responseObserver) {
        try {
            log.info("Received listBookings request for userId: {}", request.getUserId());

            // Validate request
            validateListBookingsRequest(request);

            // Get bookings
            List<Booking> bookings = bookingBusinessService.getBookingsByUserId(request.getUserId());

            // Build response
            BookingListResponse.Builder responseBuilder = BookingListResponse.newBuilder();

            for (Booking booking : bookings) {
                BookingResponse bookingResponse = BookingResponse.newBuilder()
                        .setId(booking.getId().toString())
                        .setUserId(booking.getUserId())
                        .setHotelId(booking.getHotelId())
                        .setPromoCode(booking.getPromoCode() != null ? booking.getPromoCode() : "")
                        .setDiscountPercent(booking.getDiscountPercent().doubleValue())
                        .setPrice(booking.getPrice().doubleValue())
                        .setCreatedAt(booking.getCreatedAt().format(ISO_FORMATTER))
                        .build();

                responseBuilder.addBookings(bookingResponse);
            }

            responseObserver.onNext(responseBuilder.build());
            responseObserver.onCompleted();

            log.info("Successfully returned {} bookings for userId: {}", bookings.size(), request.getUserId());

        } catch (IllegalArgumentException e) {
            log.warn("Invalid list bookings request: {}", e.getMessage());
            responseObserver.onError(Status.INVALID_ARGUMENT
                    .withDescription(e.getMessage())
                    .asRuntimeException());
        } catch (Exception e) {
            log.error("Error listing bookings", e);
            responseObserver.onError(Status.INTERNAL
                    .withDescription("Internal server error")
                    .asRuntimeException());
        }
    }

    private void validateCreateBookingRequest(BookingRequest request) {
        if (request.getUserId() == null || request.getUserId().trim().isEmpty()) {
            throw new IllegalArgumentException("User ID is required");
        }
        if (request.getHotelId() == null || request.getHotelId().trim().isEmpty()) {
            throw new IllegalArgumentException("Hotel ID is required");
        }
    }

    private void validateListBookingsRequest(BookingListRequest request) {
        if (request.getUserId() == null || request.getUserId().trim().isEmpty()) {
            throw new IllegalArgumentException("User ID is required");
        }
    }
}

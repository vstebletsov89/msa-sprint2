FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY main.go .
RUN go build -o booking-service main.go

FROM alpine:3.20

RUN apk add --no-cache curl

WORKDIR /app

COPY --from=builder /app/booking-service ./booking-service

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD curl --fail http://localhost:8080/health || exit 1

CMD ["./booking-service"]
FROM eclipse-temurin:21-jre-jammy
# Force Docker to not use cache for this layer and beyond  
ARG CACHE_BUST=1

WORKDIR /app

# Copy jar with a specific timestamp to break cache
COPY target/booking-history-service-1.0.0.jar app.jar

EXPOSE 8081

# Add timestamp to ensure fresh startup logs
ENV BUILD_TIME=${CACHE_BUST}
ENV JAVA_OPTS="-Dfile.encoding=UTF-8"
ENTRYPOINT ["java", "-jar", "app.jar"]


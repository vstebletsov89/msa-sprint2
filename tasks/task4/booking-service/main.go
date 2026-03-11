package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

type statusResponse struct {
	Status          string `json:"status"`
	Service         string `json:"service"`
	FeatureXEnabled bool   `json:"featureXEnabled"`
}

func main() {
	enableFeatureX := os.Getenv("ENABLE_FEATURE_X") == "true"

	mux := http.NewServeMux()

	mux.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("pong"))
	})

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, statusResponse{
			Status:          "UP",
			Service:         "booking-service",
			FeatureXEnabled: enableFeatureX,
		})
	})

	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, statusResponse{
			Status:          "READY",
			Service:         "booking-service",
			FeatureXEnabled: enableFeatureX,
		})
	})

	mux.HandleFunc("/feature", func(w http.ResponseWriter, r *http.Request) {
		if !enableFeatureX {
			http.Error(w, "Feature X is disabled", http.StatusNotFound)
			return
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"message": "Feature X is enabled",
			"enabled": true,
		})
	})

	log.Println("booking-service is running on :8080")
	log.Printf("ENABLE_FEATURE_X=%v", enableFeatureX)

	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	log.Fatal(server.ListenAndServe())
}

func writeJSON(w http.ResponseWriter, statusCode int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(payload)
}
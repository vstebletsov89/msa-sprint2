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
	Version         string `json:"version"`
	FeatureXEnabled bool   `json:"featureXEnabled"`
}

func main() {
	enableFeatureX := os.Getenv("ENABLE_FEATURE_X") == "true"
	version := os.Getenv("SERVICE_VERSION")
	if version == "" {
		version = "v1"
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Header().Set("X-Service-Version", version)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("pong from " + version))
	})

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, statusResponse{
			Status:          "UP",
			Service:         "booking-service",
			Version:         version,
			FeatureXEnabled: enableFeatureX,
		})
	})

	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, statusResponse{
			Status:          "READY",
			Service:         "booking-service",
			Version:         version,
			FeatureXEnabled: enableFeatureX,
		})
	})

	mux.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{
			"version":         version,
			"featureXEnabled": enableFeatureX,
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
			"version": version,
		})
	})

	log.Printf("booking-service %s is running on :8080", version)
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
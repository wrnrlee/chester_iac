// Command trigger-service is a minimal Cloud Run HTTP service that starts
// the Valheim GCE instance on request.
//
// Adapted from this repo's example_trigger_code (a Minecraft
// "shell-as-a-service" starter): same idea and the same
// gcloud-CLI-in-a-container Dockerfile pattern, but simplified - the
// Valheim instance's own startup-script brings the game server up
// automatically on boot, so this service only needs to call
// `gcloud compute instances start` and doesn't need to SSH in and run
// anything itself.
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
)

func main() {
	http.HandleFunc("/", startHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func startHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	instance := os.Getenv("INSTANCE_NAME")
	zone := os.Getenv("ZONE")
	if instance == "" || zone == "" {
		http.Error(w, "server misconfigured: INSTANCE_NAME/ZONE not set", http.StatusInternalServerError)
		return
	}

	cmd := exec.CommandContext(r.Context(), "gcloud", "compute", "instances", "start", instance, "--zone", zone, "--quiet")
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("start failed: %v\n%s", err, out)
		http.Error(w, "failed to start the Valheim server - check Cloud Run logs", http.StatusInternalServerError)
		return
	}

	log.Printf("start requested for %s: %s", instance, out)
	fmt.Fprintf(w, "Starting the Valheim server (%s)... it should be joinable within about a minute.\n", instance)
}

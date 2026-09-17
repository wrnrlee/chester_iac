# Build the Go binary.
FROM golang:1.21-bookworm AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY main.go ./
RUN go build -mod=readonly -v -o server

# Run it in a small image that also has the gcloud CLI, since the binary
# shells out to `gcloud compute instances start`.
FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:slim
WORKDIR /app
COPY --from=builder /app/server /app/server
CMD ["/app/server"]

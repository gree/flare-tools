# Multi-stage build for flare-tools
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build binaries
RUN make build

# Final stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

# Create non-root user
RUN addgroup -g 1001 flare && \
    adduser -D -s /bin/sh -u 1001 -G flare flare

# Set working directory
WORKDIR /home/flare

# Copy binaries from builder stage
COPY --from=builder /app/build/bin/flare-admin /usr/local/bin/
COPY --from=builder /app/build/bin/flare-stats /usr/local/bin/

# Change ownership
RUN chown -R flare:flare /home/flare

# Switch to non-root user
USER flare

# Set default command
CMD ["flare-admin", "--help"]
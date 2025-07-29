# Multi-stage build for flare-tools (Rust)
FROM rust:1.75-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make musl-dev

# Set working directory
WORKDIR /app

# Copy Cargo files
COPY Cargo.toml Cargo.lock ./

# Copy source code
COPY src/ ./src/
COPY tests/ ./tests/

# Build binaries in release mode
RUN cargo build --release

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
COPY --from=builder /app/target/release/flare-admin /usr/local/bin/
COPY --from=builder /app/target/release/flare-stats /usr/local/bin/
COPY --from=builder /app/target/release/kubectl-flare /usr/local/bin/

# Change ownership
RUN chown -R flare:flare /home/flare

# Switch to non-root user
USER flare

# Set default command
CMD ["flare-admin", "--help"]
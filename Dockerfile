# Multi-stage build for flare-tools (Rust)
FROM --platform=linux/amd64 rust:1.81-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make musl-dev

# Add musl target for static linking
RUN rustup target add x86_64-unknown-linux-musl

# Set working directory
WORKDIR /app

# Copy Cargo files  
COPY Cargo.toml ./

# Copy source code
COPY src/ ./src/
COPY tests/ ./tests/

# Build static binaries with musl target
ENV RUSTFLAGS='-C target-feature=+crt-static'
RUN cargo build --release --target x86_64-unknown-linux-musl

# Final stage - minimal Alpine with static binaries
FROM --platform=linux/amd64 alpine:latest

# Create non-root user
RUN addgroup -g 1001 flare && \
    adduser -D -s /bin/sh -u 1001 -G flare flare

# Set working directory
WORKDIR /home/flare

# Copy static binaries from builder stage
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/flare-admin /usr/local/bin/
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/flare-stats /usr/local/bin/
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/kubectl-flare /usr/local/bin/
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/flare-cluster-repl /usr/local/bin/

# Change ownership
RUN chown -R flare:flare /home/flare

# Switch to non-root user
USER flare

# Set default command
CMD ["flare-admin", "--help"]
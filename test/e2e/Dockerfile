FROM ubuntu:22.04

# Copy pre-built Linux binaries
COPY build/flare-admin-linux /usr/local/bin/flare-admin
COPY build/flare-stats-linux /usr/local/bin/flare-stats

# Make them executable
RUN chmod +x /usr/local/bin/flare-admin /usr/local/bin/flare-stats

# Install any dependencies needed for testing
RUN apt-get update && apt-get install -y \
    netcat \
    telnet \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy test files
COPY . .

# Run tests
CMD ["go", "test", "-v", "./test/e2e"]
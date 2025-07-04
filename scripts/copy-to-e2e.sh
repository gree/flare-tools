#!/bin/bash

# Build Linux binaries if not already built
echo "Building Linux binaries..."
GOOS=linux GOARCH=amd64 go build -o build/flare-admin-linux cmd/flare-admin/main.go
GOOS=linux GOARCH=amd64 go build -o build/flare-stats-linux cmd/flare-stats/main.go

# Copy to Kubernetes pods
echo "Copying binaries to flare pods..."
for pod in $(kubectl get pods -l app=flared -o jsonpath='{.items[*].metadata.name}'); do
    echo "Copying to pod: $pod"
    kubectl cp build/flare-admin-linux $pod:/usr/local/bin/flare-admin
    kubectl cp build/flare-stats-linux $pod:/usr/local/bin/flare-stats
    kubectl exec $pod -- chmod +x /usr/local/bin/flare-admin /usr/local/bin/flare-stats
done

# Also copy to index server
echo "Copying to index server..."
kubectl cp build/flare-admin-linux index-0:/usr/local/bin/flare-admin
kubectl cp build/flare-stats-linux index-0:/usr/local/bin/flare-stats
kubectl exec index-0 -- chmod +x /usr/local/bin/flare-admin /usr/local/bin/flare-stats

echo "Binaries copied successfully!"

# Test the binaries
echo "Testing flare-admin in container..."
kubectl exec index-0 -- flare-admin -i localhost -p 13300 list
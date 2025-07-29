# flare cluster for k8s

This repository provides k8s settings for flare.

# Install

1. Download kvs-flare_1.3.4-1+jammy1_amd64.deb from CD server.
2. Put kvs-flare_1.3.4-1+jammy1_amd64.deb in this directory.
3. Run `make images`
4. Run `kubectl apply -k ./base`


# Offline Docker Registry with Local TLS & Cosign (PoC)

This PoC sets up a **fully offline Docker Registry** with:

- **Local TLS** using your own private **CA**
- **No authentication** (for simplicity in air‑gapped labs)
- Optional **Cosign** signing/verification (also offline)

## Why TLS _and_ Cosign?

| Layer                  | Tool                   | Purpose                                                    |
| ---------------------- | ---------------------- | ---------------------------------------------------------- |
| **Transport Security** | TLS (CA + Certificate) | Ensure the client talks to the _real registry_             |
| **Content Integrity**  | Cosign                 | Ensure the _image was not modified_ and is _signed by you_ |

## Additional Components

- **Portainer** (optional): Web UI for Docker management, accessible at `http://<REG_HOST>:9000`
- **Hello World Image**: Sample Dockerfile in `hello-world-image/` for testing the PoC

## Quick Start

```bash
# 1) Place these files in an empty folder on the registry host
# 2) Run the setup script (defaults: registry.local, 127.0.0.1, 5000)
chmod +x setup_registry.sh
./setup_registry.sh <REG_HOST> <REG_IP> <REG_PORT>
# Example:
# ./setup_registry.sh registry.local 10.0.0.5 5000
```

The script will:

1. Create directories (`certs`, `config`, `data`)
2. Generate a **private CA** and a **server certificate** with SAN = hostname + IP
3. Write `docker-compose.yml` and `config/config.yml`
4. Start `registry:2.8.3` with **TLS enabled** and **delete allowed**
5. Install the CA into Docker trust (Linux: `/etc/docker/certs.d/<host:port>/ca.crt`)
6. **Install Cosign** automatically if possible (Linux online), or print offline steps

> Docker Desktop (macOS): import `certs/ca.crt` into the OS trust and copy it to `~/.docker/certs.d/<host:port>/ca.crt`, then restart Docker Desktop.

---

## Installing Cosign

### A) Linux (online, automated by script)

The setup script will try to download Cosign from GitHub Releases using:

```
COSIGN_VERSION=v2.2.4   # override by exporting this env var before running
```

It detects `amd64` or `arm64` and installs Cosign to `/usr/local/bin/cosign` using `curl` or `wget`.

### B) Linux (offline)

1. On an internet-connected machine, download Cosign binary that matches your target CPU/OS from GitHub Releases:  
   `https://github.com/sigstore/cosign/releases/download/<VERSION>/cosign-linux-amd64` (or `arm64`).
2. Transfer the file via USB to the registry host.
3. Install:
   ```bash
   chmod +x cosign-linux-amd64
   sudo mv cosign-linux-amd64 /usr/local/bin/cosign
   cosign version
   ```

### C) macOS

- **Homebrew**: `brew install cosign`
- **Offline**: download the Darwin binary from GitHub Releases and place it in `/usr/local/bin/cosign` (or `/opt/homebrew/bin` on Apple Silicon).

---

## Testing the Registry

### Local Hello World Image

Build and push the sample hello-world nginx image included in this repository:

```bash
# 1) Build the hello-world image
cd hello-world-image
docker build -t <REG_HOST>:<REG_PORT>/hello-world:latest .

# 2) Push to your local registry
docker push <REG_HOST>:<REG_PORT>/hello-world:latest

# 3) Remove local copy
docker image rm <REG_HOST>:<REG_PORT>/hello-world:latest

# 4) Pull from registry
docker pull <REG_HOST>:<REG_PORT>/hello-world:latest

# 5) Run and verify (access via browser at http://localhost:8080)
docker run --rm -d -p 8080:80 --name hello-world <REG_HOST>:<REG_PORT>/hello-world:latest

# 6) Stop the container when done
docker stop hello-world
```

Open your browser at `http://<REG_IP>:8080` to see the message:

![Hello World sample](png/test_1.png)

## Cosign (Offline)

Sign and verify your images using Cosign without internet access:

```bash
# Generate key pair (first time only)
export COSIGN_PASSWORD='changeme'
cosign generate-key-pair --output-key cosign.key --output-pub cosign.pub

# Sign the hello-world image
cosign sign --key cosign.key --tlog-upload=false <REG_HOST>:<REG_PORT>/hello-world:latest

# Verify the signature
cosign verify --key cosign.pub <REG_HOST>:<REG_PORT>/hello-world:latest

# Or sign/verify the alpine test image
cosign sign --key cosign.key --tlog-upload=false <REG_HOST>:<REG_PORT>/alpine:test
cosign verify --key cosign.pub <REG_HOST>:<REG_PORT>/alpine:test
```

Cosign stores signatures as OCI artifacts in the same registry; no internet or Rekor is required.

> **Security Note**: Keep `cosign.key` secure and back it up. The public key `cosign.pub` can be shared for verification.

## Managing the Registry with Portainer

Access Portainer web interface at `http://localhost:9000` to:

- View and manage containers (registry, portainer)
- Monitor resource usage and logs
- Inspect registry volumes and networks
- Manage Docker images in the registry

On first access, you'll need to create an admin account.

## Troubleshooting

| Symptom                                     | Cause                              | Fix                                                                                                                                  |
| ------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `x509: certificate is valid for ...`        | Host/IP mismatch with SAN          | Use the same `<REG_HOST>`/`<REG_IP>` used during cert generation **and** create `/etc/docker/certs.d/<host:port>/ca.crt` accordingly |
| `server gave HTTP response to HTTPS client` | Using HTTP by mistake              | Always use `https://` (TLS is enabled)                                                                                               |
| `TLS handshake timeout`                     | Firewall blocking port             | Ensure **TCP 5000** open between client and server                                                                                   |
| `cosign verify` fails                       | Missing CA in system trust for TLS | Install `certs/ca.crt` into the OS trust store and Docker certs.d path                                                               |
| Health check failing for registry           | Registry not fully started         | Wait 10s (start_period), check logs: `docker logs local-registry`                                                                    |
| Cannot access Portainer UI                  | Port conflict or service down      | Check if port 9000 is free: `lsof -i :9000`, verify: `docker ps`                                                                     |

## Cleanup

```bash
# Stop all services
docker compose down

# Remove all data for fresh start (optional)
rm -rf ./registry-data ./portainer-data

# Remove certificates (optional - requires re-running setup script)
rm -rf ./certs

# Remove cosign keys (optional)
rm -f cosign.key cosign.pub
```

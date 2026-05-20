# Self-Hosted Cloud VDI
## A Comprehensive Project Report

**Author:** Abhay Kumar  
**Project Type:** Cloud Infrastructure Learning Project  
**Date:** May 2026  
**Stack:** AWS EC2 · Docker · Webtop · Cloudflare Tunnel · Linux · Kali Tools

---

## Table of Contents

1. Project Overview
2. Architecture
3. Core Concepts Deep Dive
4. Technology Stack
5. Implementation — Step by Step
6. Security Measures
7. Challenges & Solutions
8. Key Learnings
9. Future Improvements
10. Conclusion

---

## 1. Project Overview

### What Was Built

A fully functional, browser-accessible Virtual Desktop Infrastructure (VDI) hosted on AWS EC2, running Ubuntu XFCE as a containerized desktop environment, secured with password authentication and exposed globally via Cloudflare Tunnel — all at zero cost.

### What Is a VDI?

A Virtual Desktop Infrastructure (VDI) is a technology that hosts desktop environments on a centralized server. Instead of running a desktop OS on your local machine, the desktop runs on a remote server and is streamed to your browser or client over a network connection.

**Enterprise VDI vs This Project:**

| Feature | Enterprise VDI (Citrix/VMware) | This Project |
|---|---|---|
| Cost | Thousands of dollars | Free |
| Access | Proprietary client | Any browser |
| Hosting | On-premise or private cloud | AWS Free Tier |
| Desktop | Windows/Linux | Ubuntu XFCE |
| Scalability | Hundreds of users | Personal use |

### Project Goals

- Host a Linux desktop environment accessible from any device, anywhere in the world
- Learn cloud infrastructure concepts hands-on
- Build a cybersecurity learning environment with Kali Linux tools
- Implement the entire stack for free using AWS Free Tier and Cloudflare

### Final Outcome

```
Any Device (Phone/Laptop/Tablet)
           ↓  HTTPS
https://perry-send-safer-shoes.trycloudflare.com
           ↓
   Cloudflare Global Network
           ↓  Encrypted Tunnel
   AWS EC2 t3.micro (Mumbai)
           ↓
   Docker Container (Webtop)
           ↓
   Ubuntu XFCE Desktop + Kali Tools
```

---

## 2. Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     USER DEVICES                        │
│  MacBook  │  iPhone  │  Android  │  Any Browser        │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTPS Request
                      ▼
┌─────────────────────────────────────────────────────────┐
│              CLOUDFLARE NETWORK                         │
│  Global CDN + DDoS Protection + SSL Termination        │
│  URL: *.trycloudflare.com                              │
└─────────────────────┬───────────────────────────────────┘
                      │ Encrypted Tunnel (QUIC/HTTP2)
                      ▼
┌─────────────────────────────────────────────────────────┐
│           AWS EC2 t3.micro (ap-south-1)                 │
│  OS: Ubuntu 26.04 LTS                                  │
│  RAM: 1GB + 2GB Swap                                   │
│  Disk: 20GB EBS                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │          DOCKER ENGINE                           │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │         WEBTOP CONTAINER                   │ │  │
│  │  │  Image: linuxserver/webtop:ubuntu-xfce    │ │  │
│  │  │  Port: 3001 (HTTPS)                       │ │  │
│  │  │  ┌──────────────────────────────────────┐ │ │  │
│  │  │  │  Ubuntu XFCE Desktop Environment    │ │ │  │
│  │  │  │  KasmVNC (Browser Streaming)        │ │ │  │
│  │  │  │  Kali Linux Security Tools          │ │ │  │
│  │  │  │  nmap, nikto, netcat, whois, dig    │ │ │  │
│  │  │  └──────────────────────────────────────┘ │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  │                                                  │  │
│  │  Volume: ./config:/config (persistent storage)  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  cloudflared (systemd service) ← always running        │
└─────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```
1. User opens browser → types Cloudflare URL
2. DNS resolves URL → Cloudflare edge server
3. Cloudflare → finds registered tunnel for this domain
4. Cloudflare → sends request through encrypted tunnel to EC2
5. cloudflared daemon on EC2 → receives request
6. cloudflared → forwards to localhost:3001 (Webtop container)
7. Webtop → authenticates user (password check)
8. Webtop → streams desktop via KasmVNC (WebRTC/WebSockets)
9. User → sees and interacts with Linux desktop in browser
```

---

## 3. Core Concepts Deep Dive

### 3.1 CPU Architecture: x86 vs ARM

Every piece of software ultimately compiles down to machine code — binary instructions that the CPU executes. The format of these instructions is defined by the CPU's **Instruction Set Architecture (ISA)**.

**x86 (CISC — Complex Instruction Set Computing)**
- Developed by Intel in 1978
- Philosophy: powerful, complex instructions — one instruction can do many operations
- Powers most traditional desktops, laptops, and servers
- Higher power consumption due to complex transistor design
- Our AWS EC2 instance uses x86_64 (64-bit x86)

**ARM (RISC — Reduced Instruction Set Computing)**
- Developed in 1985 by Acorn Computers
- Philosophy: simple, efficient instructions — each does exactly one thing
- Powers all smartphones, Apple M-series chips, Oracle Cloud free tier
- Much more power efficient
- Requires more instructions to accomplish the same task, but each executes faster

**Why This Matters for Our Project:**
```
Software compilation pipeline:
Python/Java/Go code
        ↓
    Compiler
        ↓
Machine code (ISA-specific binary)
        ↓
    CPU executes
```

An x86 binary cannot run on ARM natively. This is why Docker images are published as multi-arch — separate binaries for each architecture packaged under the same tag name.

When we ran `cloudflared --version` and got "Exec format error", that was because we downloaded the ARM64 binary for an x86_64 machine. The CPU literally could not parse the instruction format.

---

### 3.2 Cloud Computing & Virtual Machines

**What is Cloud Computing?**
Cloud providers like AWS maintain massive physical servers in data centers worldwide. Using a hypervisor (like KVM — Kernel-based Virtual Machine), they slice one physical machine into many isolated Virtual Machines. You rent one slice.

**Hypervisor Types:**
- Type 1 (Bare Metal): runs directly on hardware (AWS uses this — Nitro hypervisor)
- Type 2 (Hosted): runs on top of an OS (VirtualBox, VMware Workstation)

**AWS EC2 (Elastic Compute Cloud):**
EC2 is AWS's VM service. "Elastic" means you can resize it anytime. Each VM is called an "instance."

**Instance Types:**
```
t3.micro = our instance
│
├── Family: t3 (burstable performance)
├── Size: micro (smallest)
├── vCPU: 2
├── RAM: 1 GiB
└── Free tier: 750 hours/month for 12 months
```

**AMI (Amazon Machine Image):**
The OS template for your VM. Same concept as a Docker image — a blueprint. We used Ubuntu 26.04 LTS.

**EBS (Elastic Block Store):**
Persistent disk storage for EC2 instances. We expanded from 8GB to 20GB (within the 30GB free tier limit). EBS volumes persist even when the instance is stopped.

**Regions and Availability Zones:**
AWS has data centers worldwide organized into Regions (ap-south-1 = Mumbai) and Availability Zones (isolated data centers within a region). We chose Mumbai for lowest latency from India.

---

### 3.3 IAM — Identity and Access Management

**The Problem:**
When you create an AWS account, you get a root user with unlimited access to everything — billing, deleting the entire account, etc. Using root for daily work is dangerous.

**The Solution: IAM**
IAM lets you create sub-users with specific, limited permissions.

```
Root Account (master key — lock it away)
        ↓ creates
IAM User: ak-admin
        ↓ has only
AmazonEC2FullAccess + IAMReadOnlyAccess + IAMUserChangePassword
```

**Principle of Least Privilege:**
Every user/service should have only the minimum permissions needed to do its job. This is a core security principle in cloud and enterprise environments.

**Policies:**
JSON documents that define permissions. AWS provides managed policies (pre-built) or you can write custom ones.

```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*"
}
```

---

### 3.4 SSH — Secure Shell

SSH is a cryptographic network protocol for securely operating network services over an unsecured network. It replaced older protocols like Telnet that sent data in plain text.

**How SSH Key Authentication Works:**

```
Key Generation:
Private Key (stays on your Mac) ←→ Public Key (stored on server)

Connection Process:
1. Client says "I want to connect, here's my public key identifier"
2. Server generates a random challenge encrypted with your public key
3. Only your private key can decrypt this challenge
4. Client decrypts and sends back the answer
5. Server verifies → connection established
6. No password ever sent over the network
```

**Why Key-Based Auth is More Secure Than Passwords:**
- Password can be brute-forced
- Password can be intercepted if connection is compromised
- Private key never leaves your machine
- Mathematical impossibility to derive private key from public key

**The .pem File:**
PEM (Privacy Enhanced Mail) is a Base64 encoded format for storing cryptographic keys. AWS generates the key pair and gives you the private key as a .pem file — once only.

**The chmod 400 Command:**
```bash
chmod 400 my-vdi-key.pem
```
This sets the file permissions to read-only for owner only. SSH refuses to use a key file that is accessible by other users — a security requirement.

**SCP (Secure Copy Protocol):**
Built on top of SSH, SCP transfers files between machines with the same security guarantees as SSH. We used it to transfer docker-compose.yml, init.sh, and cloudflared.service from Mac to EC2.

---

### 3.5 Linux Fundamentals

**Linux File System Hierarchy:**
```
/                    ← root of entire filesystem
├── /etc/            ← system configuration files
│   ├── /etc/systemd/  ← systemd service definitions
│   └── /etc/apt/    ← apt package manager config
├── /home/ubuntu/    ← home directory for ubuntu user
├── /usr/local/bin/  ← user-installed binaries (cloudflared lives here)
├── /var/            ← variable data (logs, databases)
└── /tmp/            ← temporary files
```

**Package Management with apt:**
Ubuntu uses apt (Advanced Package Tool) to manage software installation.

```bash
apt update          # refresh package list from repositories
apt install nmap    # download and install nmap
apt remove nmap     # uninstall nmap
apt upgrade         # upgrade all installed packages
```

**Repositories:**
Servers that host software packages. Ubuntu has its own repos; we added Kali Linux's repo to access security tools.

```bash
# Add GPG key (cryptographic trust)
curl -fsSL https://archive.kali.org/archive-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/kali.gpg

# Add repository source
echo "deb http://http.kali.org/kali kali-rolling main contrib non-free" > /etc/apt/sources.list.d/kali.list
```

**GPG (GNU Privacy Guard):**
Cryptographic signature system. Every package from Kali's repo is signed with their private key. Your system verifies the signature using their public key (the .gpg file) before installing — prevents installing tampered packages.

**sudo:**
"Superuser Do" — run a command with root (administrator) privileges. AWS's ubuntu user has passwordless sudo configured via /etc/sudoers.

**systemd:**
The init system and service manager for modern Linux. It's the first process that starts when Linux boots (PID 1) and manages all other services.

```bash
systemctl enable cloudflared   # start at boot
systemctl start cloudflared    # start now
systemctl status cloudflared   # check status
systemctl stop cloudflared     # stop
journalctl -u cloudflared      # view logs
```

**Swap Space:**
When RAM is full, the OS can use disk space as "slow RAM." We added 2GB swap because t3.micro only has 1GB RAM which was insufficient for the desktop environment.

```bash
fallocate -l 2G /swapfile    # create 2GB file
chmod 600 /swapfile           # secure it
mkswap /swapfile              # format as swap
swapon /swapfile              # activate
```

**disk management:**
```bash
lsblk                         # list block devices
df -h /                       # disk usage
growpart /dev/nvme0n1 1       # extend partition
resize2fs /dev/nvme0n1p1      # extend filesystem
```

---

### 3.6 Docker & Containerization

**The Core Problem Docker Solves:**
"It works on my machine but not on the server" — caused by different OS versions, library versions, environment variables, and file paths between development and production environments.

**Docker's Solution:**
Ship the entire environment along with the code, not just the code.

**Virtual Machine vs Container:**

```
Virtual Machine:                Container:
┌──────────────┐               ┌──────────────┐
│   App        │               │   App        │
│   Libraries  │               │   Libraries  │
│   Guest OS   │               └──────────────┘
│   Hypervisor │               ┌──────────────┐
│   Host OS    │               │  Docker      │
│   Hardware   │               │  Host OS     │
└──────────────┘               │  Hardware    │
                               └──────────────┘
Size: GBs                      Size: MBs
Boot: Minutes                  Boot: Seconds
Isolation: Full OS             Isolation: Process-level
```

**Key Docker Concepts:**

*Image:* A read-only template — like a class in OOP. Defines the environment but isn't running.

*Container:* A running instance of an image — like an object created from a class. Gets its own writable layer on top of the image.

*Layer:* Each instruction in a Dockerfile creates a new layer. Layers are cached and shared between images, making builds fast and storage efficient.

```
Layer 5: Copy application code
Layer 4: Install Python packages
Layer 3: Install system dependencies  
Layer 2: Set environment variables
Layer 1: Ubuntu 22.04 base OS
```

*Volume:* A persistent storage mechanism. Maps a directory on the host to a directory in the container. Data survives container deletion.

```yaml
volumes:
  - ./config:/config
# Host path  : Container path
```

*Port Binding:* Containers are isolated by default. Port binding exposes a container port to the host.

```yaml
ports:
  - "3001:3001"
# Host port : Container port
```

**Docker Compose:**
A tool for defining and running multi-container applications via a YAML file. Instead of long `docker run` commands, you define everything declaratively.

```yaml
services:
  my-vdi:
    image: lscr.io/linuxserver/webtop:ubuntu-xfce
    container_name: my-vdi
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Kolkata
      - PASSWORD=yourpassword
    volumes:
      - ./config:/config
      - ./init.sh:/custom-cont-init.d/init.sh
    ports:
      - "3000:3000"
      - "3001:3001"
    shm_size: "1gb"
    cap_add:
      - NET_RAW
      - NET_ADMIN
    restart: unless-stopped
```

**Linux Capabilities:**
Docker strips dangerous Linux capabilities from containers by default for security. `NET_RAW` (raw socket access) is one such capability — required by nmap for SYN scanning. We explicitly granted it via `cap_add`.

**Container Lifecycle:**
```
Image → Created → Running → Paused → Stopped → Deleted
```
`restart: unless-stopped` means the container automatically restarts if it crashes or the host reboots, unless you explicitly stop it.

---

### 3.7 Networking Concepts

**IP Addresses:**
- **Private IP (172.31.40.116):** Internal AWS network address, not reachable from internet
- **Public IP (65.2.152.128):** Internet-facing address assigned by AWS, changes on stop/start
- **Elastic IP:** Static public IP you can reserve in AWS (costs money if unused)

**Ports:**
A port is a virtual endpoint for network communication. A server can run many services simultaneously, each on a different port.

```
65.2.152.128:22    ← SSH
65.2.152.128:3000  ← Webtop HTTP
65.2.152.128:3001  ← Webtop HTTPS
```

**Security Groups:**
AWS's virtual firewall. Controls inbound and outbound traffic at the instance level.

```
Inbound Rules we added:
Port 22   → SSH (our Mac to server)
Port 3000 → Webtop HTTP
Port 3001 → Webtop HTTPS
Source: 0.0.0.0/0 = anywhere
```

**DNS (Domain Name System):**
The internet's phone book. Translates human-readable domain names to IP addresses.

```
User types: perry-send-safer-shoes.trycloudflare.com
DNS query: "what IP is this?"
DNS response: 104.21.x.x (Cloudflare's IP)
Browser connects to Cloudflare
Cloudflare routes to your EC2 via tunnel
```

**TCP vs UDP:**
- TCP (Transmission Control Protocol): reliable, ordered delivery. Used for web, SSH, file transfer.
- UDP (User Datagram Protocol): faster, no guarantee of delivery. Used for video streaming, DNS.

**HTTPS and TLS:**
HTTP over TLS (Transport Layer Security). Encrypts all communication between browser and server. Our Webtop container uses a self-signed TLS certificate — hence the "Not Secure" warning in browser.

---

### 3.8 Cloudflare Tunnel

**The Problem:**
Our EC2's public IP (65.2.152.128) changes on restart. Port numbers in URLs look unprofessional. Opening ports publicly exposes the server to internet scanners and attacks.

**How Cloudflare Tunnel Solves This:**

```
Traditional (Port Forwarding):
Internet → Port 3001 → EC2 (IP exposed, port exposed)

Cloudflare Tunnel:
Internet → Cloudflare → Encrypted Tunnel → EC2 (nothing exposed)
```

The tunnel is an outbound connection from EC2 to Cloudflare — like a reverse SSH tunnel. The EC2 initiates the connection, so no inbound ports need to be open.

**cloudflared binary:**
The Cloudflare tunnel daemon. Runs on EC2, maintains persistent connection to Cloudflare's network, and forwards requests to local services.

**Quick Tunnel vs Named Tunnel:**
- Quick Tunnel: no account needed, random URL, no uptime guarantee (what we used)
- Named Tunnel: requires Cloudflare account, permanent URL, production-grade reliability

**QUIC Protocol:**
Cloudflare Tunnel uses QUIC (Quick UDP Internet Connections) — a modern transport protocol developed by Google, now an IETF standard. Faster than TCP for tunnel connections because it eliminates head-of-line blocking.

---

### 3.9 Security Tools (Kali Linux)

**nmap (Network Mapper):**
The most important reconnaissance tool in cybersecurity. Discovers hosts, open ports, running services, and OS fingerprints.

```bash
nmap -sT localhost      # TCP Connect scan (no raw socket needed)
nmap -sV 192.168.1.1   # Service version detection
nmap -A target.com      # Aggressive scan (OS, version, scripts)
nmap -p 1-65535 target  # Scan all ports
```

Scan types:
- SYN scan (-sS): half-open, stealthy, requires NET_RAW
- TCP Connect (-sT): full handshake, no special privileges
- UDP scan (-sU): scans UDP ports

**nikto:**
Web server vulnerability scanner. Checks for dangerous files, outdated server software, and security misconfigurations.

**netcat:**
"The Swiss Army knife of networking." Can open raw TCP/UDP connections, listen on ports, transfer files, create backdoors (in CTF contexts).

**whois:**
Queries domain registration databases to find ownership information about domains and IP addresses.

**dnsutils (dig, nslookup):**
DNS lookup tools. Query DNS servers directly to understand how a domain resolves.

---

## 4. Technology Stack

| Component | Technology | Purpose |
|---|---|---|
| Cloud Platform | AWS EC2 t3.micro | Virtual server hosting |
| OS (Server) | Ubuntu 26.04 LTS | Server operating system |
| Containerization | Docker + Docker Compose | Container management |
| VDI Image | LinuxServer Webtop | Browser-based desktop streaming |
| Desktop OS | Ubuntu XFCE | Desktop environment |
| Desktop Streaming | KasmVNC / Selkies | WebRTC-based screen streaming |
| Security Tools | Kali Linux repo | Penetration testing tools |
| Tunnel | Cloudflare Tunnel | Secure public access |
| Init System | systemd | Service management |
| Storage | AWS EBS (20GB) | Persistent disk |
| Memory | 1GB RAM + 2GB Swap | Runtime memory |
| Authentication | Webtop PASSWORD env | Access control |

---

## 5. Implementation — Step by Step

### Phase 1: Local Development (MacBook M5)

**Step 1: Install Docker Desktop**
Downloaded Docker Desktop for Apple Silicon (ARM64). Docker Desktop on Mac runs a lightweight Linux VM internally since Docker requires a Linux kernel.

**Step 2: Run hello-world**
```bash
docker run hello-world
```
Verified Docker installation. Learned image pulling, container creation, and lifecycle.

**Step 3: Run Webtop locally**
```bash
docker run -d \
  --name my-vdi \
  -p 3000:3000 \
  -p 3001:3001 \
  -v ~/Documents/projects/webtop-parrot:/config \
  --shm-size="1gb" \
  --cap-add=NET_RAW \
  --cap-add=NET_ADMIN \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:ubuntu-xfce
```

**Step 4: Create Docker Compose setup**
Moved from `docker run` to `docker-compose.yml` for declarative, reproducible configuration.

**Step 5: Create init.sh auto-install script**
```bash
#!/bin/bash
curl -fsSL https://archive.kali.org/archive-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/kali.gpg
echo "deb http://http.kali.org/kali kali-rolling main contrib non-free" > /etc/apt/sources.list.d/kali.list
apt update
apt install -y nmap nikto netcat-openbsd whois dnsutils wget
```

Mounted via Docker volume into `/custom-cont-init.d/` — LinuxServer's auto-run directory.

**Step 6: Verified nmap works**
```bash
nmap -sT localhost
# Result: ports 3000, 3001, 8082 open
```

---

### Phase 2: AWS Setup

**Step 1: Create AWS Account**
Root account created at aws.amazon.com.

**Step 2: Create IAM User**
- Username: ak-admin
- Policies: AmazonEC2FullAccess, IAMReadOnlyAccess, IAMUserChangePassword
- Console access enabled

**Step 3: Launch EC2 Instance**
- Region: ap-south-1 (Mumbai)
- AMI: Ubuntu 26.04 LTS
- Instance type: t3.micro (free tier)
- Key pair: my-vdi-key.pem (RSA, downloaded once)
- Security group: SSH (22), HTTP (3000), HTTPS (3001) open

**Step 4: SSH into server**
```bash
chmod 400 my-vdi-key.pem
ssh -i my-vdi-key.pem ubuntu@65.2.152.128
```

**Step 5: Install Docker**
```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker
```

**Step 6: Transfer project files**
```bash
scp -i my-vdi-key.pem docker-compose.yml init.sh ubuntu@65.2.152.128:~/
```

**Step 7: Expand disk**
Default 8GB was insufficient. Expanded EBS to 20GB via AWS Console, then:
```bash
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

**Step 8: Add swap**
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**Step 9: Deploy VDI**
```bash
sudo docker compose up -d
```

---

### Phase 3: Public Access & Security

**Step 1: Open firewall ports**
AWS Security Group inbound rules:
- Port 3000: Custom TCP, 0.0.0.0/0
- Port 3001: Custom TCP, 0.0.0.0/0

**Step 2: Add password authentication**
Added to docker-compose.yml:
```yaml
environment:
  - PASSWORD=yourpassword
```

**Step 3: Install Cloudflare Tunnel**
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

**Step 4: Create systemd service**
```ini
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
ExecStart=/usr/local/bin/cloudflared tunnel --url https://localhost:3001 --no-tls-verify
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Step 5: Enable service**
```bash
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

**Final URL:**
```
https://perry-send-safer-shoes.trycloudflare.com
```

---

## 6. Security Measures

### Implemented

| Measure | Implementation |
|---|---|
| SSH key authentication | RSA key pair, no password login |
| IAM least privilege | ak-admin has only EC2 and IAM read permissions |
| VDI password | PASSWORD env variable in Webtop |
| Cloudflare Tunnel | No raw IP exposed, DDoS protection |
| HTTPS only | Port 3001 with TLS |
| Docker isolation | Container isolation from host OS |

### Security Best Practices Applied

**Never used root account** for daily operations — IAM user only.

**Private key security** — chmod 400 on .pem file, never committed to git.

**No password SSH** — key-based authentication only.

**Container capabilities** — only added NET_RAW and NET_ADMIN, which are specifically required. Did not use `--privileged` mode.

---

## 7. Challenges & Solutions

### Challenge 1: Oracle Cloud Signup Failure
**Problem:** Oracle Cloud account creation failed repeatedly with generic error, despite correct information.
**Root Cause:** Oracle's fraud detection system flagged the account — a known widespread issue with Indian users.
**Solution:** Pivoted to AWS Free Tier which has a more reliable signup process.

### Challenge 2: Wrong CPU Architecture
**Problem:** Downloaded ARM64 cloudflared binary for x86_64 EC2 instance. Got "Exec format error."
**Root Cause:** Assumed EC2 free tier uses ARM (like Oracle's free tier). AWS t3.micro is x86_64.
**Solution:** Used `uname -m` to identify architecture, downloaded amd64 binary.

### Challenge 3: Disk Space Exhaustion
**Problem:** Docker failed to extract image layers with "no space left on device."
**Root Cause:** Default EC2 8GB disk was insufficient for 1.1GB image + extraction temporary space.
**Solution:** Expanded EBS volume to 20GB via AWS Console (within free 30GB limit), extended partition and filesystem.

### Challenge 4: Out of Memory
**Problem:** VDI was extremely slow and unresponsive. Only 30MB available RAM.
**Root Cause:** Ubuntu XFCE desktop environment requires ~800MB+ RAM. t3.micro has only 1GB.
**Solution:** Added 2GB swap space using a swapfile, made permanent via /etc/fstab.

### Challenge 5: nmap Permission Denied
**Problem:** nmap returned "Operation not permitted" inside container.
**Root Cause:** Docker strips NET_RAW capability by default. nmap needs it for SYN scanning.
**Solution:** Added `--cap-add=NET_RAW` and `--cap-add=NET_ADMIN` to docker-compose.yml.

### Challenge 6: Tool Loss on Container Recreation
**Problem:** Every time the container was recreated, all installed tools (nmap, nikto etc.) disappeared.
**Root Cause:** Installed packages live in the container's writable layer, not the volume. Volumes only save /config.
**Solution:** Created init.sh startup script mounted into `/custom-cont-init.d/` — runs automatically on every container start, reinstalling all tools.

---

## 8. Key Learnings

### Technical Learnings

**Cloud Infrastructure:**
- Cloud VMs are slices of physical hardware managed by a hypervisor
- IAM is fundamental to cloud security — never use root for daily operations
- EBS volumes are independent of EC2 instances — data persists through stops
- Security Groups are stateful firewalls — inbound rules don't require matching outbound rules
- AWS free tier is region-specific — t3.micro is free in some regions, t2.micro in others

**Linux Administration:**
- systemd is the backbone of modern Linux service management
- Swap space can extend effective RAM at the cost of speed
- Linux file permissions are critical for security (SSH key permissions)
- Package managers with signed repos are more secure than downloading binaries
- GPG keys cryptographically verify package authenticity

**Docker:**
- Images are immutable — containers get a writable layer on top
- Volumes persist data independently of container lifecycle
- Docker Compose is the right tool for any multi-config setup
- Container capabilities are a security boundary — grant only what's needed
- Startup scripts in /custom-cont-init.d/ enable reproducible environments

**Networking:**
- Every service needs a port — port conflicts are a common real-world problem
- Public IPs can change — stable access requires DNS or tunnels
- Cloudflare Tunnel creates outbound connections — no inbound ports needed
- HTTPS requires TLS certificates — self-signed certs cause browser warnings

### Soft Learnings

- **Verify before executing** — wrong architecture assumption cost time
- **Research current state** — Docker Hub tags change; always verify they exist
- **Understand constraints first** — 1GB RAM limitation should have been assessed before choosing instance type
- **Infrastructure as Code** — docker-compose.yml and init.sh mean the entire setup is reproducible from two files

---

## 9. Future Improvements

### Short Term

**Permanent Cloudflare URL**
Set up a named Cloudflare Tunnel with a free Cloudflare account for a fixed URL that doesn't change on reboot.

**Stronger Authentication**
Implement Cloudflare Access — Google/GitHub login before reaching the VDI. Zero Trust security model.

**HTTPS with Valid Certificate**
Use Let's Encrypt for a trusted TLS certificate — eliminates browser security warnings.

### Medium Term

**Migrate to Oracle Cloud**
Oracle's always-free tier offers 4 OCPUs and 24GB RAM — far superior to AWS t3.micro for a desktop environment. The migration is simple: copy docker-compose.yml and init.sh to the new server.

**Automated URL notification**
Script that sends the current Cloudflare URL to Telegram/email when it changes after a reboot.

**Persistent swap**
Already implemented via /etc/fstab — survives reboots.

### Long Term

**Custom Domain**
Purchase a domain (~₹500/year) and configure Cloudflare DNS for a professional URL like `vdi.abhaydev.com`.

**GPU Support**
For graphics-intensive security tools (Hashcat for password cracking), explore GPU-enabled instances with Docker GPU passthrough.

**Multi-user Setup**
Use Kasm Workspaces instead of Webtop for proper multi-user, on-demand container provisioning.

---

## 10. Conclusion

This project successfully delivered a fully functional, browser-accessible cloud VDI at zero cost, demonstrating proficiency across multiple domains of modern software infrastructure.

### What Makes This Project Significant

Most developers with one year of experience have written application code but never touched the infrastructure layer beneath it. This project bridges that gap by building the entire stack from scratch — from cloud account setup to containerized desktop deployment to secure public access.

The skills demonstrated span:
- **Cloud computing** (AWS EC2, IAM, EBS, Security Groups)
- **Linux administration** (systemd, package management, disk management, swap)
- **Containerization** (Docker, Docker Compose, volumes, networking)
- **Networking** (SSH, TCP/IP, DNS, HTTPS, tunneling)
- **Security** (least privilege, key-based auth, VPN tunneling)
- **DevOps practices** (Infrastructure as Code, reproducible environments, service management)

### The Bigger Picture

Enterprise VDI solutions (Citrix Virtual Apps, VMware Horizon, AWS WorkSpaces) charge hundreds of dollars per user per month. This project replicates the core functionality — persistent desktop accessible from anywhere — for free, using open-source tools and cloud free tiers.

More importantly, this project serves as a foundation for cybersecurity learning. With Kali Linux tools installed and the VDI accessible from any device, platforms like TryHackMe and HackTheBox can be practiced from a dedicated, isolated environment without affecting the host machine.

---

*Report compiled by Abhay Kumar | May 2026*
*Project Repository: github.com/abhayk2*

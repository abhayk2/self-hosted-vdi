#!/bin/bash

echo "Installing security tools..."

# Add Kali repo key
curl -fsSL https://archive.kali.org/archive-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/kali.gpg

# Add Kali repo
echo "deb http://http.kali.org/kali kali-rolling main contrib non-free" > /etc/apt/sources.list.d/kali.list

# Update and install tools
apt update
apt install -y \
  nmap \
  nikto \
  netcat-openbsd \
  whois \
  dnsutils \
  wget

echo "All tools installed!"
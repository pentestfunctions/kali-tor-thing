#!/bin/bash
# torify-kali-safe.sh
# Configures system-wide Tor routing on a fresh Kali install safely (idempotent)

set -e

echo "[*] Updating system..."
sudo apt update && sudo apt upgrade -y

echo "[*] Installing Tor and necessary tools..."
sudo apt install -y tor iptables iptables-persistent

TORRC="/etc/tor/torrc"
sudo cp $TORRC "${TORRC}.bak"

# Function to ensure a line exists in torrc
ensure_line() {
    local LINE="$1"
    grep -Fxq "$LINE" $TORRC || echo "$LINE" | sudo tee -a $TORRC > /dev/null
}

echo "[*] Configuring Tor..."
ensure_line "ControlPort 9051"
ensure_line "CookieAuthentication 1"
ensure_line "TransPort 9040"
ensure_line "DNSPort 5353"
ensure_line "AutomapHostsOnResolve 1"

echo "[*] Restarting Tor service..."
sudo systemctl enable tor --now
sudo systemctl restart tor

echo "[*] Configuring iptables for system-wide Tor routing..."
# Delete old rules added by this script (tagged with comment TORIFY)
sudo iptables -t nat -S | grep "TORIFY" | while read -r line; do
    sudo iptables -t nat ${line/-A/-D}
done

# Redirect TCP traffic to Tor TransPort (except local)
sudo iptables -t nat -A OUTPUT -m owner ! --uid-owner $(id -u) -p tcp --syn -j REDIRECT --to-ports 9040 -m comment --comment "TORIFY"

# Redirect DNS to Tor DNSPort
sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353 -m comment --comment "TORIFY"

# Save rules
sudo netfilter-persistent save

echo "[*] Setting environment variables for proxy-aware applications..."
grep -qxF 'export http_proxy="socks5://127.0.0.1:9050"' ~/.bashrc || echo 'export http_proxy="socks5://127.0.0.1:9050"' >> ~/.bashrc
grep -qxF 'export https_proxy="socks5://127.0.0.1:9050"' ~/.bashrc || echo 'export https_proxy="socks5://127.0.0.1:9050"' >> ~/.bashrc
source ~/.bashrc

echo "[*] System-wide Tor routing configured safely!"
echo "[*] Reboot recommended."

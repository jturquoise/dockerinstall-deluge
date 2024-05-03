#!/bin/bash
# Script to update the server and install essential packages including Docker and set up Deluge torrent server

# Function to check if a package is installed
is_installed() {
    dpkg -s "$1" &> /dev/null
}

# Function to update system
system_update() {
    echo "Updating system packages..."
    sudo apt-get update -y && sudo apt-get upgrade -y
}

# Function to install a package
install_package() {
    if is_installed "$1"; then
        echo "$1 is already installed."
    else
        echo "$1 is not installed, installing..."
        sudo apt-get install -y "$1"
    fi
}

install_docker() {
    echo "Installing Docker..."
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings

    # Add Docker's GPG key
    local docker_gpg_key_url="https://download.docker.com/linux/debian/gpg"
    local keyring_path="/etc/apt/keyrings/docker.asc"
    sudo curl -fsSL "$docker_gpg_key_url" -o "$keyring_path"
    sudo chmod a+r "$keyring_path"

    # Add the Docker repository
    local repo_url="deb [arch=$(dpkg --print-architecture) signed-by=$keyring_path] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable"
    echo "$repo_url" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    # Install Docker packages
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "Docker installation complete."
}
# Function to set up Deluge using Docker
setup_deluge() {
    echo "Setting up Deluge in Docker..."
    local compose_file="/home/${USER}/torrent-server/docker-compose.yml"
    mkdir -p "$(dirname "$compose_file")"
    cat << EOF > "$compose_file"
---
version: '3.3'
services:
  deluge:
    image: lscr.io/linuxserver/deluge:latest
    container_name: deluge
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - DELUGE_LOGLEVEL=error #optional
    volumes:
      - /path/to/deluge/config:/config
      - /path/to/your/downloads:/downloads
    ports:
      - 8112:8112
      - 6881:6881
      - 6881:6881/udp
      - 58846:58846 #optional
    restart: unless-stopped
EOF
    echo "Deluge setup complete."
}

# Function to install and configure OpenVPN
# Function to install OpenVPN and configure directories
install_openvpn() {
    install_package "openvpn"

    # Ask user for the number of default directories
    echo "Would you like to create some default directories for OpenVPN? (0-5)"
    read -r num_dirs
    if [[ "$num_dirs" =~ ^[0-5]$ ]]; then
        for (( i = 1; i <= num_dirs; i++ )); do
            echo "Enter name for server $i:"
            read -r server_name
            mkdir -p "/etc/openvpn/$server_name"
            echo "Directory /etc/openvpn/$server_name created."
        done
    else
        echo "Invalid number entered. No directories will be created."
    fi

    # Ask user for the number of secure servers
    echo "Would you like to add some secure servers? (0-3)"
    read -r num_secure_dirs
    if [[ "$num_secure_dirs" =~ ^[0-3]$ ]]; then
        for (( i = 1; i <= num_secure_dirs; i++ )); do
            echo "Enter name for secure server $i:"
            read -r secure_server_name
            mkdir -p "/etc/openvpn/secure/$secure_server_name"
            echo "Secure directory /etc/openvpn/secure/$secure_server_name created."
        done
    else
        echo "Invalid number entered. No secure directories will be created."
    fi
}

# Function to create a utility script in /usr/bin
create_pubip_script() {
    local script_path="/usr/bin/pubip"

    # Create the script file
    cat << 'EOF' > "$script_path"
#!/bin/bash
# Check if curl is installed
if ! command -v curl &> /dev/null
then
    echo "Curl is not installed. Please install curl to proceed."
    exit 1
fi
curl https://ipinfo.io/ip ; echo
EOF

    # Make the script executable
    chmod +x "$script_path"
    echo "The ipinfo script has been installed in /usr/bin/pubip."
}


# Main execution starts here
system_update
install_package "curl"

# Docker Installation
install_docker

# Setting up Deluge using Docker
setup_deluge

# Testing Docker installation
echo "Testing Docker installation..."
sudo docker run hello-world
echo "Installation complete. Dolphin time, baby!"

# Installing OpenVPN
install_openvpn

# Pubip Installation
create_pubip_script
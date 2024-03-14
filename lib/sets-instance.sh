#!/bin/bash

ARCHITECTURE=$(uname -m)
SYSTEM_UUID=$(dmidecode -s system-uuid)
DESTINATION_DIR="/tmp"
CONTAINER_NAME="sets-instance"
URL="https://auth.setscharts.app/v1/api/local-instance/$SYSTEM_UUID"

if [ "$EUID" -ne 0 ]; then
    echo "This script needs to be run with sudo privileges."
    exit 1
fi

if [ "$ARCHITECTURE" == "x86_64" ]; then
    DOCKER_IMAGE="rick00/sets-editor-arm:v0.5"
    FRPC_URL=https://bt-dev-storage.s3.ap-south-1.amazonaws.com/frpc-amd64
elif [ "$ARCHITECTURE" == "aarch64" ]; then
    DOCKER_IMAGE="rick00/sets-editor-arm:v0.6"
    FRPC_URL=https://bt-dev-storage.s3.ap-south-1.amazonaws.com/frpc-arm64
else
    echo "Unsupported architecture: $ARCHITECTURE"
    exit 1
fi

cpu_name=$(lscpu | grep "Model name" | awk -F':' '{print $2}' | sed 's/^[ \t]*//')
gpu_name=$(lspci | grep -i vga | awk -F':' '{print $3}' | sed 's/^[ \t]*//')
ram_size=$(free -h | awk '/^Mem:/ {print $2}' | sed 's/^[ \t]*//')
host_name=$(hostname)
type="local"
SYSTEM_INFO="{ \"name\": \"$host_name\", \"type\": \"$type\", \"CPU\": \"$cpu_name\", \"GPU\": \"$gpu_name\", \"RAM\": \"$ram_size\" }"

echo "
███████╗███████╗████████╗███████╗
██╔════╝██╔════╝╚══██╔══╝██╔════╝
███████╗█████╗     ██║   ███████╗
╚════██║██╔══╝     ██║   ╚════██║
███████║███████╗   ██║   ███████║
╚══════╝╚══════╝   ╚═╝   ╚══════╝
"
echo -e "───────────────────────────────────"
echo -e "| Local-instance Setup Wizard v0.1 |"
echo -e "───────────────────────────────────\n"

echo -ne "🚀 Installing Necessary Software...\n"

apt update -yqq &> /dev/null && apt upgrade -yqq &> /dev/null
apt install jq ca-certificates curl gnupg -yqq &> /dev/null

if command -v docker &> /dev/null; then
    if docker ps --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
        echo -e "✅ Local-instance up and running..\n"
        exit 1
    elif docker ps -a --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
        docker start "$CONTAINER_NAME" &> /dev/null
        echo -e "✅ Local-instance up and running..\n"
        exit 1
    fi
else
    mkdir -p "/etc/apt/keyrings/"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update -yqq &> /dev/null
    apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin jq -yqq &> /dev/null
fi

docker pull $DOCKER_IMAGE &> /dev/null
echo -e "✅ Completed.\n"

echo -e "────────────────────────────────\n"

while true; do
    read -p "📧 Enter Sets Email: " email </dev/tty
    read -s -p "🔐 Enter password: " pass </dev/tty
    url="https://auth.setscharts.app/v1/api/user/login"
    json_data='{
        "loginId": "'"$email"'",
        "password": "'"$pass"'",
        "applicationId": "30e74f33-f9b0-4e2c-b98a-c4845f6543be"
    }'
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "$json_data" "$url")

    TOKEN=$(echo "$response" | jq -r '.token')
    if [ -z "$TOKEN" ]; then
        echo "Error: Authentication failed."
        exit 0
    else
        echo -e "\n👤 Logged in as $(echo "$response" | jq -r '.user.fullName')\n"
        break
    fi
done


echo -e "────────────────────────────────\n"
echo -e "🔧 Setting up local-instance..."

curl -sS -o "/usr/bin/frpc" -L "$FRPC_URL" > /dev/null 2>&1
chmod +x "/usr/bin/frpc"

mkdir -p "/etc/frp"

response_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$URL")

if [ "$response_code" -eq 404 ]; then
    post_response=$(curl -X POST -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "$URL" -d "$SYSTEM_INFO")
    echo "$post_response" > "/etc/frp/frpc.json"
else
    if [ "$response_code" -eq 200 ]; then
        curl -s -H "Authorization: Bearer $TOKEN" "$URL"  > /etc/frp/frpc.json
    fi
fi


# Specify the service file path
SERVICE_FILE="/etc/systemd/system/frpc.service"

cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=Frp Server Service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/bin/frpc -c /etc/frp/frpc.json
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload >/dev/null 2>&1

# Enable and start the service
systemctl enable frpc.service >/dev/null 2>&1
systemctl start frpc.service >/dev/null 2>&1



docker run -d -p 80:80 -p 3333:3333 -e USER_ID=$(echo "$response" | jq -r '.user.registrations[0].username') --name $CONTAINER_NAME $DOCKER_IMAGE >/dev/null 2>&1

# Create a systemd service file using a heredoc
bash -c "cat > /etc/systemd/system/sets-instance.service" <<EOF
[Unit]
Description=Sets Local-instance
Requires=docker.service
After=docker.service

[Service]
Restart=always
User=root
ExecStart=/usr/bin/docker start -a $CONTAINER_NAME
ExecStop=/usr/bin/docker stop -t 2 $CONTAINER_NAME

[Install]
WantedBy=default.target
EOF

# Reload systemd
systemctl daemon-reload >/dev/null 2>&1

# Enable and start the service
systemctl enable sets-instance.service >/dev/null 2>&1

if docker ps --format '{{.Names}}' | grep -wq $CONTAINER_NAME; then
    echo -e "✅ Done! (⌐■_■) Your Local Instance is Ready!\n"
    exit 1
fi
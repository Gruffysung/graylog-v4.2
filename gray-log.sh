#!/bin/bash

# ตรวจสอบว่ารันด้วยสิทธิ์ root หรือไม่
if [ "$(id -u)" -ne 0 ]; then
    echo "กรุณารันสคริปต์นี้ด้วยสิทธิ์ root หรือใช้ sudo"
    exit 1
fi

# อัปเดตระบบ
sudo apt update && sudo apt upgrade -y

# ติดตั้งแพ็กเกจที่จำเป็น
sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common curl

# ติดตั้ง Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# ติดตั้ง Docker Compose
sudo curl -SL https://github.com/docker/compose/releases/download/v2.33.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# ตรวจสอบการติดตั้ง Docker
docker -v
if [ $? -ne 0 ]; then
    echo "Docker ติดตั้งไม่สำเร็จ"
    exit 1
fi

docker-compose version
if [ $? -ne 0 ]; then
    echo "Docker Compose ติดตั้งไม่สำเร็จ"
    exit 1
fi

# สร้างโฟลเดอร์และเตรียมไฟล์ docker-compose.yml
mkdir -p ~/docker-graylog-v4.2
cd ~/docker-graylog-v4.2
cat > docker-compose.yml <<EOL
version: '3'

services:
  mongodb:
    image: mongo:5.0
    container_name: mongo
    volumes:
      - /mongo_data:/data/db
    networks:
      - graylog

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch-7.10.2
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - /es_data:/usr/share/elasticsearch/data
    networks:
      - graylog

  graylog:
    image: graylog/graylog:4.2
    container_name: graylog
    environment:
      - GRAYLOG_PASSWORD_SECRET=mysecret
      - GRAYLOG_ROOT_PASSWORD_SHA2=$(echo -n "admin" | sha256sum | awk '{print $1}')
      - GRAYLOG_HTTP_EXTERNAL_URI=http://127.0.0.1:9000/
    volumes:
      - /graylog_journal:/usr/share/graylog/data/journal
    depends_on:
      - mongodb
      - elasticsearch
    networks:
      - graylog
    ports:
      - "9000:9000"
      - "1514:1514"
      - "5044:5044"
      - "12201:12201/udp"

networks:
  graylog:
    driver: bridge
EOL

# กำหนดค่าหน่วยความจำสำหรับ Elasticsearch
sysctl -n vm.max_map_count | grep -q "262144" || {
    sudo sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
}

# กำหนดสิทธิ์โฟลเดอร์
sudo usermod -aG docker $USER
newgrp docker
sudo mkdir -p /mongo_data /es_data /graylog_journal
sudo chmod 777 -R /mongo_data /es_data /graylog_journal

# รัน Graylog
sudo docker-compose up -d

# ตรวจสอบสถานะ Container
sleep 10
docker ps

echo "Graylog พร้อมใช้งานที่: http://$(hostname -I | awk '{print $1}'):9000"

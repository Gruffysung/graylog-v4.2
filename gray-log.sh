#!/bin/bash

# Upgrade and install dependencies
echo "Updating package lists..."
sudo apt update 

# Install Docker
echo "Installing Docker..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common


curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null


sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io


sudo systemctl enable docker
sudo systemctl start docker

# install Docker Successfully
echo "Docker installed successfully."
docker --version
if ! command -v docker-compose &> /dev/null
then
    echo "docker-compose could not be found, installing..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi
docker-compose --version

# Create directory Graylog
echo "Setting up Graylog..."
mkdir -p ~/graylog && cd ~/graylog

# Dowload Graylog docker-compose.yml
cat <<EOF >docker-compose.yml
services:
  # MongoDB
      - ./mongo_data:/data/db
    image: mongo:4.2
    restart: always
    networks:
      - graylog
    volumes:
      - /mongo_data:/data/db
      - ./es_data:/usr/share/elasticsearch/data
  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.2
    restart: always
    volumes:
      - /es_data:/usr/share/elasticsearch/data
    environment:
      - http.host=0.0.0.0
      - transport.host=localhost
      - network.host=0.0.0.0
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    mem_limit: 1g
    networks:
      - ./graylog_journal:/usr/share/graylog/data/journal

  # Graylog
  graylog:
    image: graylog/graylog:4.2
    volumes:
      - /graylog_journal:/usr/share/graylog/data/journal
    environment:
      # CHANGE ME (must be at least 16 characters)! Base64
      - GRAYLOG_PASSWORD_SECRET=c2VjcnVpdHlwZWVyYW51dA==
      # Password: admin
      - GRAYLOG_ROOT_PASSWORD_SHA2=8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918
      - GRAYLOG_HTTP_EXTERNAL_URI=http://localhost:9000/
      - TZ=Asia/Bangkok
      - GRAYLOG_ROOT_TIMEZONE=Asia/Bangkok
    networks:
      - graylog
    links:
      - mongodb:mongo
      - elasticsearch
    restart: always
    depends_on:
      - mongodb
      - elasticsearch
    ports:
      # Graylog web interface and REST API
      - 9000:9000
      # Syslog TCP & UDP
      - 1514:1514
      - 1514:1514/udp
      # GELF TCP & UDP
      - 12201:12201
      - 12201:12201/udp

# Volumes
volumes:
  mongo_data:
    driver: local
  es_data:
    driver: local
  graylog_journal:
    driver: local

# Networks
networks:
  graylog:
    driver: bridge
EOF

# Run Graylog
docker-compose up -d

# check Graylog running
docker ps

echo "Graylog installation complete. Access it at http://127.0.0.1:9000 with user 'admin' and password 'admin'."

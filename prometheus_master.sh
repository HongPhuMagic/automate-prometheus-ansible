# "chmod +x [script name].sh"  allows file to be executable 
# "./[script name].sh" to execute the script
# decloration of the dialect we're using (bash)  ->    "which bash" to see the location of bash


# shebang line first (sharp + bang)
#! /usr/bin.bash


##########################
# Master server (optional)
##########################

function master_setup() {
	read -p "New user to add: " USER
	sudo adduser $USER
	sudo usermod -aG sudo $USER
}


######################
# Initial Server setup
######################

function server_setup() {
	sudo ufw allow OpenSSH
	sudo ufw enable

	sudo ufw allow ssh
	sudo ufw allow proto tcp from any to any port 80,443
        sudo ufw status
}

####################
# Nginx installation
####################

function nginx_setup() {
	sudo apt update
	sudo apt upgrade
	sudo apt install ssh
	sudo apt install docker -y
	sudo apt install curl
	sudo apt install nginx

	sudo ufw allow 'Nginx HTTP'
	sudo ufw status
	systemctl status nginx
}

#########################
# Prometheus installation
#########################

function prome_setup() {
	# Create service users
	sudo useradd --no-create-home --shell /bin/false prometheus
	sudo useradd --no-create-home --shell /bin/false node_exporter

	sudo mkdir /etc/prometheus
	sudo mkdir /var/lib/prometheus

	sudo chown prometheus:prometheus /etc/prometheus
	sudo chown prometheus:prometheus /var/lib/prometheus

	# Downloading Prometheus
	cd ~
	curl -LO https://github.com/prometheus/prometheus/releases/download/v2.22.0/prometheus-2.22.0.linux-amd64.tar.gz
	tar xvf prometheus-2.22.0.linux-amd64.tar.gz

	# Copy two binaries to /usr/local/bin directory
	sudo cp prometheus-2.22.0.linux-amd64/prometheus /usr/local/bin/
	sudo cp prometheus-2.22.0.linux-amd64/promtool /usr/local/bin/

	# Set user and group ownership to prometheus user created
	sudo chown prometheus:prometheus /usr/local/bin/prometheus
	sudo chown prometheus:prometheus /usr/local/bin/promtool

	# Copy consoles and console_libraries to directories to /etc/prometheus
	sudo cp -r prometheus-2.22.0.linux-amd64/consoles /etc/prometheus
	sudo cp -r prometheus-2.22.0.linux-amd64/console_libraries /etc/prometheus

	# Set user and group ownership on the directories to the prometheus user
	sudo chown -R prometheus:prometheus /etc/prometheus/consoles
	sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries

	# Remove leftover files from home directory
	rm -rf prometheus-2.22.0.linux-amd64.tar.gz prometheus-2.22.0.linux-amd64

	# Prometheus configuration file
	sudo bash -c "cat <<EOF >  /etc/prometheus/prometheus.yml
        global:
          scrape_interval: 15s

        scrape_configs:
          - job_name: 'prometheus'
            scrape_interval: 5s
            static_configs:
              - targets: ['localhost:9090']
	  - job_name: 'node_exporter'
            scape_interval: 5s
            static_configs:
              - targets: ['localhost:9100']
	EOF"

        # Set user and group ownership on the configuration file to prometheus user
        sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

        # Service file tells systemd to run Prometheus as the prometheus user w/config file create/given and
        # store data in /var/lib/prometheus directory
	sudo bash -c "cat <<EOF > /etc/systemd/system/prometheus.service
	[Unit]
	Description=Prometheus
	Wants=network-online.target
	After=network-online.target

	[Service]
	User=prometheus
	Group=prometheus
	Type=simple
	ExecStart=/usr/local/bin/prometheus \
		--config.file /etc/prometheus/prometheus.yml \
		--storage.tsdb.path /var/lib/prometheus/ \
		--web.console.templates=/etc/prometheus/consoles \
		--web.console.libraries=/etc/prometheus/console_libraries

	[Install]
	WantedBy=multi-user.target
	EOF"

	sudo systemctl daemon-reload
	sudo systemctl start prometheus

	# Enable service to start on boot
	sudo systemctl enable prometheus
}


function node_exporter_setup(){
	# Download Node exporter and unpack
	cd ~
	curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz
	tar xvf node_exporter-1.0.1.linux-amd64.tar.gz

	# Cope binary to /usr/local/bin directory and set the user and group ownership to node_exporter user created
	sudo cp node_exporter-1.0.1.linux-amd64/node_exporter /usr/local/bin
	sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

	# Remove leftover files from homedirectory
	rm -rf node_exporter-1.0.1.linux-amd64.tar.gz node_exporter-1.0.1.linux-amd64

	# Serivce file tells systemd to run Node Exporter as the node_exporter user w/ default set of collectors
	sudo bash -c "cat <<EOF > /etc/systemd/system/node_exporter.service
	[Unit]
	Description=Node Exporter
	Wants=network-online.target
	After=network-online.target

	[Service]
	User=node_exporter
	Group=node_exporter
	Type=simple
	ExecStart=/usr/local/bin/node_exporter

	[Install]
	WantedBy=multi-user.target
	EOF"

        sudo systemctl daemon-reload
        sudo systemctl start node_exporter

        # Enable service to start on boot
        sudo systemctl enable node_exporter
	sudo systemctl restart prometheus
}


function grafana_setup(){
	# Install grafana via .deb package (manual updates)
	sudo apt-get install -y adduser libfontconfig1
	wget https://dl.grafana.com/oss/release/grafana_7.3.1_amd64.deb
	sudo dpkg -i grafana<edition>_<version>_amd64.deb

	# Starting grafana server via systemd
	sudo systemctl daemon-reload
	sudo systemctl start grafana-server

	# Enable service to start on boot
	sudo systemctl enable grafana-server.service
}


echo "Setting up"
server_setup
nginx_setup
prome_setup
node_exporter_setup
grafana_setup
echo "Finished"

















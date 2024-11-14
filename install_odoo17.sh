#!/bin/bash

# Use /home/ubuntu directory for the installation
export HOME=/home/ubuntu

# Update the system
echo "Updating the system..."
sudo apt-get update -y

# Install Python and required libraries
echo "Installing Python and required libraries..."
sudo apt-get install -y python3-pip python3-dev python3-venv libxml2-dev libxslt1-dev zlib1g-dev \
    libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev \
    libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev

# Install NPM and CSS plugins
echo "Installing NPM and CSS plugins..."
sudo apt-get install -y npm
sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo npm install -g less less-plugin-clean-css
sudo apt-get install -y node-less

# Install Wkhtmltopdf
echo "Installing Wkhtmltopdf..."
sudo wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.bionic_amd64.deb
sudo dpkg -i wkhtmltox_0.12.6-1.bionic_amd64.deb
sudo apt install -f -y

# Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt-get install -y postgresql
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check PostgreSQL status (optional)
sudo systemctl status postgresql

# Create Odoo user
echo "Creating Odoo user..."
sudo useradd -m -U -r -d /home/odoo17 -s /bin/bash odoo17
sudo passwd odoo17

# Create PostgreSQL user for Odoo
echo "Creating PostgreSQL user for Odoo..."
sudo su - postgres -c "createuser -s odoo17"

# Install Odoo 17
echo "Installing Odoo 17..."
sudo -u odoo17 -H bash -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 /home/odoo17/odoo17"
sudo -u odoo17 -H bash -c "python3 -m venv /home/odoo17/odoo17-venv"
sudo -u odoo17 -H bash -c "source /home/odoo17/odoo17-venv/bin/activate && pip install --upgrade pip && pip3 install wheel && pip3 install -r /home/odoo17/odoo17/requirements.txt"

# Create custom addons and log directories
echo "Creating custom addons and log directories..."
sudo mkdir /home/odoo17/odoo17-custom-addons
sudo chown -R odoo17:odoo17 /home/odoo17/odoo17-custom-addons
sudo mkdir -p /home/odoo17/logs
sudo touch /home/odoo17/logs/odoo17.log
sudo chown -R odoo17:odoo17 /home/odoo17/logs

# Create Odoo configuration file
echo "Creating Odoo configuration file..."
sudo tee /home/odoo17/odoo17.conf > /dev/null <<EOL
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo17
db_password = False
xmlrpc_port = 8069
logfile = /home/odoo17/logs/odoo17.log
addons_path = /home/odoo17/odoo17/addons,/home/odoo17/odoo17-custom-addons
EOL

# Create systemd service file for Odoo 17
echo "Creating Odoo systemd service file..."
sudo tee /etc/systemd/system/odoo17.service > /dev/null <<EOL
[Unit]
Description=Odoo 17
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo17
PermissionsStartOnly=true
User=odoo17
Group=odoo17
ExecStart=/home/odoo17/odoo17-venv/bin/python3 /home/odoo17/odoo17/odoo-bin -c /home/odoo17/odoo17.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable and start Odoo service
echo "Starting and enabling Odoo service..."
sudo systemctl daemon-reload
sudo systemctl start odoo17
sudo systemctl enable odoo17

# Install Nginx
echo "Installing Nginx..."
sudo apt-get install -y nginx

# Configure Nginx for Odoo
echo "Configuring Nginx for Odoo..."
sudo tee /etc/nginx/nginx.conf/odoo > /dev/null <<EOL

server {
    listen 80;
    server_name 16.171.19.209;

    location / {
        proxy_pass http://16.171.19.209:8069
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Redirect HTTP to HTTPS
    location ~ /.well-known/acme-challenge {
        allow all;
    }
}
EOL
# Test Nginx configuration
sudo nginx -t
# Reload Nginx to apply the configuration
sudo systemctl reload nginx
# Allow Nginx through firewall
echo "Allowing Nginx through the firewall..."
sudo ufw allow 'Nginx Full'
# Check the status of Odoo service
sudo systemctl status odoo17

echo "Odoo installation complete. Access it via http://YourServerIPAddress:8069"

#!/bin/bash

# Use /home/ubuntu directory for the installation
export HOME=/home/ubuntu

# Update the system
echo "Updating the system..."
sudo apt-get update -y

# Install necessary packages including git and unzip
echo "Installing required packages..."
sudo apt-get install -y python3-pip python3-dev python3-venv libxml2-dev libxslt1-dev zlib1g-dev \
    libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev \
    libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev git npm unzip

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

# Create PostgreSQL user for Odoo
echo "Creating PostgreSQL user for Odoo..."
sudo -u postgres psql -c "CREATE USER odoo17 WITH CREATEDB SUPERUSER PASSWORD 'password';"

# Install Odoo 17 (Use the default Ubuntu user instead of odoo17 user)
echo "Installing Odoo 17..."
git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 /home/ubuntu/odoo17
python3 -m venv /home/ubuntu/odoo17-venv
source /home/ubuntu/odoo17-venv/bin/activate
pip install --upgrade pip
pip install wheel
pip install -r /home/ubuntu/odoo17/requirements.txt

# Create custom addons, custom_addons, and log directories
echo "Creating custom addons, custom_addons, and log directories..."
sudo mkdir -p /home/ubuntu/odoo17-custom-addons
sudo mkdir -p /home/ubuntu/odoo17-custom_addons
sudo chown -R ubuntu:ubuntu /home/ubuntu/odoo17-custom-addons /home/ubuntu/odoo17-custom_addons
sudo mkdir -p /home/ubuntu/logs
sudo touch /home/ubuntu/logs/odoo17.log
sudo chown -R ubuntu:ubuntu /home/ubuntu/logs

# Extract custom_addons.zip to the custom_addons directory
echo "Extracting custom_addons.zip..."
if [ -f /home/ubuntu/custom_addons.zip ]; then
    sudo unzip /home/ubuntu/custom_addons.zip -d /home/ubuntu/odoo17-custom_addons
    sudo chown -R ubuntu:ubuntu /home/ubuntu/odoo17-custom_addons
else
    echo "custom_addons.zip file not found in /home/ubuntu."
fi

# Create Odoo configuration file in /home/ubuntu/etc/odoo17.conf
echo "Creating Odoo configuration file..."
sudo mkdir -p /home/ubuntu/etc
sudo tee /home/ubuntu/etc/odoo17.conf > /dev/null <<EOL
[options]
admin_passwd = admin
db_host = False
db_port = 5432
db_user = odoo17
db_name = False
db_password = False
list_db = True
http_port = 8069
xmlrpc_port = 8069
logfile = /home/ubuntu/logs/odoo17.log
addons_path = /home/ubuntu/odoo17/addons,/home/ubuntu/odoo17-custom-addons,/home/ubuntu/odoo17-custom_addons
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
User=ubuntu
Group=ubuntu
ExecStart=/home/ubuntu/odoo17-venv/bin/python3 /home/ubuntu/odoo17/odoo-bin -c /home/ubuntu/etc/odoo17.conf
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

# Modify the main Nginx configuration file
echo "Modifying /etc/nginx/nginx.conf for Odoo..."
sudo tee -a /etc/nginx/nginx.conf > /dev/null <<EOL
server {
    listen 80;
    server_name 13.60.16.13;  # Replace with your server's IP or domain

    location / {
        proxy_pass http://localhost:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ~ /.well-known/acme-challenge {
        allow all;
    }
}
EOL

# Test Nginx configuration and reload
sudo nginx -t
sudo systemctl reload nginx
sudo ufw allow 'Nginx Full'

# Set permissions and ownership for Odoo directories
echo "Setting permissions and ownership for Odoo directories..."
sudo mkdir -p /var/lib/odoo
sudo chown -R ubuntu:ubuntu /var/lib/odoo
sudo chmod 700 /var/lib/odoo

# Tail Odoo log and check service status
echo "Checking Odoo logs and service status..."
if [ -f /home/ubuntu/logs/odoo17.log ]; then
    tail -n 50 /home/ubuntu/logs/odoo17.log
else
    echo "Log file not found."
fi
sudo systemctl restart odoo17
sudo systemctl status odoo17

echo "Odoo installation complete. Access it via http://YourServerIPAddress:8069"

# Create odoo_start.sh script
echo "Creating odoo_start.sh script..."
sudo tee /home/ubuntu/odoo_start.sh > /dev/null <<EOL
#!/bin/bash
# Start Odoo using the virtual environment and configuration file
source /home/ubuntu/odoo17-venv/bin/activate
python3 /home/ubuntu/odoo17/odoo-bin -c /home/ubuntu/etc/odoo17.conf
EOL

# Make odoo_start.sh executable
sudo chmod +x /home/ubuntu/odoo_start.sh

echo "The odoo_start.sh script has been created and is located at /home/ubuntu/odoo_start.sh."

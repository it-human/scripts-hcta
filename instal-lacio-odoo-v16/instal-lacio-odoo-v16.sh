#!/bin/bash

# Atura el script en cas d'error
set -e

# Funció per generar una contrasenya aleatòria de 16 caràcters
function generate_random_password {
  echo "$(tr -dc 'A-Za-z0-9!@#$%^&*()_+=-' < /dev/urandom | head -c 16)"
}

# Funció per demanar dades obligatòries
function prompt_required {
  local prompt_text=$1
  local default_value=$2
  read -p "$prompt_text [$default_value]: " input_value
  echo ${input_value:-$default_value}
}

# Funció per demanar dades amb validació "s/n"
function prompt_yes_no {
  local prompt_text=$1
  local default_value=$2
  read -p "$prompt_text (s/n) [$default_value]: " input_value
  input_value=${input_value:-$default_value}
  while [[ ! "$input_value" =~ ^[sSnN]$ ]]; do
    read -p "$prompt_text (s/n) [$default_value]: " input_value
    input_value=${input_value:-$default_value}
  done
  echo "$input_value"
}

# Demanar el nom de la instància
instance_name=$(prompt_required "Introdueix el nom de la instància de Lightsail")

# Generar valors per defecte
static_ip=$(prompt_required "Introdueix la IP estàtica de la instància")
custom_domain=$(prompt_required "Introdueix el nom de domini" "example.com")
custom_domain="intranet.$custom_domain"
db_name_default="${instance_name}_db"
db_user_default="${instance_name}_user"
master_password_default=$(generate_random_password)
db_password_default=$(generate_random_password)
admin_password_default=$(generate_random_password)

master_password=$(prompt_required "Introdueix la contrasenya de Master Password" "$master_password_default")
db_name=$(prompt_required "Introdueix el nom de la base de dades" "$db_name_default")
db_user=$(prompt_required "Introdueix el nom d'usuari de la base de dades" "$db_user_default")
db_password=$(prompt_required "Introdueix la contrasenya de l'usuari de la base de dades" "$db_password_default")
admin_email=$(prompt_required "Introdueix el correu electrònic de l'administrador" "it@humancta.org")
admin_password=$(prompt_required "Introdueix la contrasenya de l'administrador" "$admin_password_default")
admin_language=$(prompt_required "Introdueix l'idioma" "Català")
admin_country=$(prompt_required "Introdueix el país" "Espanya")
install_demo_data=$(prompt_yes_no "Vols instal·lar dades de mostra?" "n")

demo_data="False"
if [[ "$install_demo_data" == "s" || "$install_demo_data" == "S" ]]; then
  demo_data="True"
fi

# Comprovar i esborrar la base de dades i l'usuari si ja existeixen
sudo su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname = '$db_name'\"" | grep -q 1 && \
  sudo su - postgres -c "psql -c 'DROP DATABASE $db_name;'"

sudo su - postgres -c "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname = '$db_user'\"" | grep -q 1 && \
  sudo su - postgres -c "psql -c 'DROP ROLE $db_user;'"

# Crear base de dades i usuari
sudo su - postgres -c "psql -c \"CREATE DATABASE $db_name;\""
sudo su - postgres -c "createuser -p 5432 -s $db_user"
sudo su - postgres -c "psql -c \"ALTER USER $db_user WITH PASSWORD '$db_password';\""

# Crear fitxer de configuració d'Odoo
sudo bash -c "cat <<EOL > /etc/odoo.conf
[options]
admin_passwd = $master_password
db_host = 127.0.0.1
db_port = 5432
db_user = $db_user
db_password = $db_password
db_name = $db_name
addons_path = /opt/odoo/odoo-server/addons,/opt/odoo/odoo-server/custom_addons
logfile = /var/log/odoo/odoo-server.log
log_level = debug
admin_email = $admin_email
admin_country = $admin_country
admin_language = $admin_language
demo_data = $demo_data
instance_name = $instance_name
static_ip = $static_ip
port = 8069
EOL"

# Crear servei d'Odoo
sudo bash -c "cat <<EOL > /etc/systemd/system/odoo-server.service
[Unit]
Description=Odoo Service
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/odoo-server/venv/bin/python3 /opt/odoo/odoo-server/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOL"

# Reiniciar els serveis
sudo systemctl daemon-reload
sudo systemctl restart odoo-server
sudo systemctl enable odoo-server

echo "Instal\u00b7laci\u00f3 d'Odoo completada correctament!"

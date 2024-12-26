#!/bin/bash

# Colors per als missatges
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # Reset

# Funció per revisar i eliminar components que no són del sistema operatiu d'Ubuntu
function clean_non_system_components {
  echo ""
  echo -e "${BLUE}Revisant i eliminant components no essencials...${NC}"

  # Revisar i eliminar bases de dades PostgreSQL
  if sudo -u postgres psql -c "\l" > /dev/null 2>&1; then
    echo -e "${BLUE}Eliminant bases de dades PostgreSQL...${NC}"
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS odoo_db;" || true
    sudo -u postgres psql -c "DROP USER IF EXISTS odoo_user;" || true
  else
    echo -e "${GREEN}No s'ha trobat cap instància de PostgreSQL.${NC}"
  fi

  # Revisar i eliminar PostgreSQL completament
  if dpkg -l | grep -q postgresql; then
    echo -e "${BLUE}Eliminant PostgreSQL...${NC}"
    sudo systemctl stop postgresql
    sudo apt purge postgresql* -y
    sudo rm -rf /etc/postgresql /var/lib/postgresql /var/log/postgresql
  else
    echo -e "${GREEN}PostgreSQL no està instal·lat.${NC}"
  fi

  # Revisar i eliminar usuaris i grups d'Odoo
  if id "odoo" &>/dev/null; then
    echo -e "${BLUE}Eliminant usuaris i grups d'Odoo...${NC}"
    sudo deluser --remove-home odoo || true
    sudo delgroup odoo || true
  else
    echo -e "${GREEN}No s'ha trobat l'usuari o grup d'Odoo.${NC}"
  fi

  # Revisar i eliminar directoris relacionats amb Odoo
  if [ -d "/opt/odoo" ] || [ -f "/etc/odoo.conf" ]; then
    echo -e "${BLUE}Eliminant directoris d'Odoo...${NC}"
    sudo rm -rf /opt/odoo /var/log/odoo /etc/odoo.conf
  else
    echo -e "${GREEN}No s'han trobat directoris o fitxers d'Odoo.${NC}"
  fi

  # Netejar paquets no essencials
  echo -e "${BLUE}Eliminant paquets no essencials...${NC}"
  sudo apt --fix-broken install -y
  sudo apt autoremove -y
  sudo apt autoclean

  # Eliminar fitxers sobrants
  echo -e "${BLUE}Eliminant fitxers sobrants...${NC}"
  sudo find / -type f \( -name "*.deb" -o -name "*.sh" \) \
  -not -path "/snap/*" -not -path "/proc/*" -not -path "/sys/*" -not -path "/dev/*" \
  -exec rm -f {} + 2>/dev/null || true
  echo -e "${GREEN}Components no essencials eliminats.${NC}"
}

# Cridar la funció de neteja
clean_non_system_components

# Funció per demanar dades obligatòries amb valor per defecte
function prompt_required {
  local prompt_text=$1
  local default_value=$2
  # Mostrar el prompt amb el valor per defecte preomplert al camp editable
  read -e -i "$default_value" -p "$prompt_text: " input_value
  # Retornar el valor introduït o, si està buit, el valor per defecte
  echo "${input_value:-$default_value}"
}


# Funció per demanar dades obligatòries sense valor per defecte
function prompt_required_no_default {
  local prompt_text=$1
  local default_value
  # Mostrar el text del prompt amb el valor per defecte entre claudàtors
  read -p "$prompt_text: " input_value
  # Retornar el valor introduït o, si està buit, el valor per defecte
  echo "${input_value:-$default_value}"
}

# Funció per demanar dades amb validació "s/n"
function prompt_yes_no {
  local prompt_text=$1
  local default_value=$2
  read -p "$prompt_text [${default_value}]: " input_value
  input_value=${input_value:-$default_value}
  echo "$input_value"
}

# Funció per generar una contrasenya aleatòria de 16 caràcters
function generate_random_password {
  echo "$(tr -dc 'A-Za-z0-9!@#$%^&*()_+=-' < /dev/urandom | head -c 16)"
}

# Funció per validar domini
function validate_domain {
  local domain=$1
  if [[ $domain =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
    return 0 # Domini vàlid
  else
    return 1 # Domini no vàlid
  fi
}

# Funció per validar IP
function validate_ip {
  local ip=$1
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 0 # IP vàlida
  else
    return 1 # IP no vàlida
  fi
}

# Configurar SSL amb Let's Encrypt
function configure_ssl {
  echo ""
  echo -e "${BLUE}Configurant SSL amb Let's Encrypt...${NC}"

  # Instal·lar Certbot
  sudo apt install certbot python3-certbot-nginx -y

  # Generar certificat SSL per al domini
  sudo certbot --nginx --non-interactive --agree-tos -m "$admin_email" -d "$custom_domain"

  # Verificar si el certificat s'ha generat correctament
  if sudo certbot certificates | grep -q "$custom_domain"; then
    echo -e "${GREEN}SSL configurat correctament per al domini $custom_domain.${NC}"
  else
    echo -e "${RED}Hi ha hagut un problema configurant SSL per al domini $custom_domain.${NC}"
    exit 1
  fi
}

# Funció per instal·lar mòduls bàsics en Odoo
function install_basic_modules {
  echo ""
  echo -e "${BLUE}Instal·lant mòduls bàsics a Odoo...${NC}"

  # Instal·lar els mòduls utilitzant la interfície XML-RPC d'Odoo
  modules=("crm" "sales" "purchase" "stock" "account" "mail" "project" "website")
  
  for module in "${modules[@]}"; do
    echo -e "${BLUE}Instal·lant mòdul: ${YELLOW}$module${NC}"
    sudo su - odoo -c "/opt/odoo/odoo-server/venv/bin/python3 /opt/odoo/odoo-server/odoo-bin -c /etc/odoo.conf --xmlrpc-port=8069 -d $db_name -u $module"
  done

  echo -e "${GREEN}Tots els mòduls bàsics s'han instal·lat correctament.${NC}"
}

# Demanar el nom de la instància abans de tot
echo ""
instance_name=$(prompt_required_no_default "Introdueix el nom de la instància de Lightsail")

# Generar valors per defecte per la base de dades i l'usuari basat en el nom de la instància
db_name_default="${instance_name}_db"
db_user_default="${instance_name}_user"

# Generar contrasenyes aleatòries per defecte
master_password_default=$(generate_random_password)
db_password_default=$(generate_random_password)
admin_password_default=$(generate_random_password)

# Demanar IP i validar
while true; do
  static_ip=$(prompt_required_no_default "Introdueix la IP estàtica de la instància")
  if validate_ip "$static_ip"; then
    break
  else
    echo -e "${RED}La IP introduïda no és vàlida. Torna-ho a intentar.${NC}"
  fi
done

# Demanar domini i validar
while true; do
  custom_domain=$(prompt_required_no_default "Introdueix el nom de domini (per exemple, example.com)")
  if validate_domain "$custom_domain"; then
  custom_domain="intranet.$custom_domain"
    break
  else
    echo -e "${RED}El domini introduït no és vàlid. Torna-ho a intentar.${NC}"
  fi
done

# Demanar la resta de paràmetres amb els valors per defecte calculats
master_password=$(prompt_required "Introdueix la contrasenya de Master Password" "$master_password_default")
db_name=$(prompt_required "Introdueix el nom de la base de dades" "$db_name_default")
db_user=$(prompt_required "Introdueix el nom d'usuari de la base de dades" "$db_user_default")
db_password=$(prompt_required "Introdueix la contrasenya de l'usuari de la base de dades" "$db_password_default")
admin_email=$(prompt_required "Introdueix el correu electrònic de l'administrador" "it@humancta.org")
admin_password=$(prompt_required "Introdueix la contrasenya de l'administrador" "$admin_password_default")

# Demanar idioma i país amb valors per defecte
admin_language=$(prompt_required "Introdueix l'idioma" "Català")
admin_country=$(prompt_required "Introdueix el país" "Espanya")

# Dades de mostra per defecte NO
install_demo_data=$(prompt_yes_no "Vols instal·lar dades de mostra? (s/n)" "n")

# Convertir la resposta de "s" o "n" en booleà per la configuració
if [[ "$install_demo_data" == "s" || "$install_demo_data" == "S" ]]; then
  demo_data="True"
else
  demo_data="False"
fi

# Funció per mostrar els valors seleccionats
function mostrar_valors {
  echo -e ""
  echo -e "${BLUE}Configuració seleccionada:${NC}"
  echo -e "  Nom de la instància de Lightsail: ${YELLOW}$instance_name${NC}"
  echo -e "  IP estàtica de la instància: ${YELLOW}$static_ip${NC}"
  echo -e "  Nom de domini: ${YELLOW}$custom_domain${NC}"
  echo -e "  Master Password: ${YELLOW}$master_password${NC}"
  echo -e "  Nom de la base de dades: ${YELLOW}$db_name${NC}"
  echo -e "  Usuari de la base de dades: ${YELLOW}$db_user${NC}"
  echo -e "  Contrasenya de la base de dades: ${YELLOW}$db_password${NC}"
  echo -e "  Correu electrònic de l'administrador: ${YELLOW}$admin_email${NC}"
  echo -e "  Contrasenya de l'administrador: ${YELLOW}$admin_password${NC}"
  echo -e "  Idioma: ${YELLOW}$admin_language${NC}"
  echo -e "  País: ${YELLOW}$admin_country${NC}"
  echo -e "  Instal·lació de dades de mostra: ${YELLOW}$demo_data${NC}"
  echo -e "  Mòduls bàsics instal·lats:"

  # Llista dels mòduls bàsics instal·lats
  modules=("crm" "sales" "purchase" "stock" "account" "mail" "project" "website")
  for module in "${modules[@]}"; do
    echo -e "    - ${YELLOW}$module${NC}"
  done
}

mostrar_valors

# Confirmar els valors abans de continuar
echo ""
default_confirm="s" # Valor per defecte
read -p "Vols continuar amb aquests valors? (s/n) [$default_confirm]: " confirm

# Si l'usuari prem només Enter, utilitza 's', si escriu qualsevol altra cosa, utilitza 'n'
confirm=${confirm:-$default_confirm}
if [[ $confirm != "s" ]]; then
  echo -e "${RED}Instal·lació cancel·lada.${NC}"
  exit 1
fi

# Actualitzar el servidor
echo ""
echo -e "${BLUE}Actualitzant el servidor...${NC}"
sudo apt update -y && sudo apt upgrade -y

# Instal·lació de seguretat SSH i Fail2ban
echo ""
echo -e "${BLUE}Instal·lant seguretat SSH i Fail2ban...${NC}"
sudo apt-get install openssh-server fail2ban -y

# Instal·lació de llibreries necessàries
echo ""
echo -e "${BLUE}Instal·lant llibreries necessàries...${NC}"
sudo apt update
sudo apt install -y vim curl wget gpg git gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates build-essential python3 python3-pip python3-dev python3-venv python3-wheel libfreetype6-dev libxml2-dev libzip-dev libsasl2-dev python3-setuptools libjpeg-dev zlib1g-dev libpq-dev libxslt1-dev libldap2-dev libtiff5-dev libopenjp2-7-dev fontconfig fontconfig-config fonts-dejavu-core fonts-dejavu-mono libfontconfig1 libfontenc1 libjpeg-turbo8 libxrender1 x11-common xfonts-75dpi xfonts-base xfonts-encodings xfonts-utils ssl-cert


# Instal·lació de Node.js i NPM
echo ""
echo -e "${BLUE}Instal·lant Node.js i NPM...${NC}"
sudo apt install nodejs npm node-less xfonts-75dpi xfonts-base fontconfig -y
sudo npm install -g rtlcss

# Instal·lació de Wkhtmltopdf
echo ""
echo -e "${BLUE}Instal·lant dependències per Wkhtmltopdf...${NC}"
sudo apt-get install -y fontconfig libjpeg-turbo8 libxrender1 xfonts-75dpi xfonts-base
echo -e "${BLUE}Instal·lant Wkhtmltopdf...${NC}"
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_amd64.deb || true
sudo apt-get install -f -y
sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_amd64.deb || true

# Instal·lació de PostgreSQL 14
echo ""
echo -e "${BLUE}Instal·lant PostgreSQL 14...${NC}"
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt update
sudo apt --fix-broken install -y
sudo apt -y install postgresql-14 postgresql-client-14

# Creació de la base de dades i usuari PostgreSQL per Odoo
echo ""
echo -e "${BLUE}Creant base de dades i usuari PostgreSQL per Odoo...${NC}"
sudo su - postgres -c "psql -c \"CREATE DATABASE $db_name;\""
sudo su - postgres -c "createuser -p 5432 -s $db_user"
sudo su - postgres -c "psql -c \"ALTER USER $db_user WITH PASSWORD '$db_password';\""

# Configurar autenticació PostgreSQL
echo ""
echo -e "${BLUE}Configurant autenticació PostgreSQL...${NC}"
sudo bash -c "echo 'local   all             all                                     md5' >> /etc/postgresql/14/main/pg_hba.conf"
sudo systemctl restart postgresql

# Creació de l'usuari Odoo13.36.135.74
echo ""
echo -e "${BLUE}Creant usuari Odoo al sistema...${NC}"
sudo adduser --system --group --home=/opt/odoo --shell=/bin/bash odoo

# Clonar el repositori Odoo 16
echo ""
echo -e "${BLUE}Clonant el repositori Odoo 16...${NC}"
sudo su - odoo -c "git clone https://github.com/odoo/odoo.git --depth 1 --branch 16.0 --single-branch /opt/odoo/odoo-server"

# Crear entorn virtual de Python
echo ""
echo -e "${BLUE}Creant entorn virtual de Python...${NC}"
sudo su - odoo -c "python3 -m venv /opt/odoo/odoo-server/venv"
sudo su - odoo -c "/opt/odoo/odoo-server/venv/bin/pip install wheel"
sudo su - odoo -c "/opt/odoo/odoo-server/venv/bin/pip install -r /opt/odoo/odoo-server/requirements.txt"

# Crear directori de logs
echo ""
echo -e "${BLUE}Creant directori de logs...${NC}"
sudo mkdir /var/log/odoo
sudo touch /var/log/odoo/odoo-server.log
sudo chown odoo:odoo /var/log/odoo -R
sudo chmod 777 /var/log/odoo

# Crear fitxer de configuració d'Odoo
echo ""
echo -e "${BLUE}Creant fitxer de configuració d'Odoo...${NC}"
sudo bash -c "cat > /etc/odoo.conf"
<<EOL
[options]
admin_passwd = $master_password
db_host = 127.0.0.1
db_port = 5432
db_user = $db_user
db_password = $db_password
db_name = $db_name
addons_path = /opt/odoo/odoo-server/addons,/opt/odoo/odoo-server/server-tools,/opt/odoo/odoo-server/custom_addons
logfile = /var/log/odoo/odoo-server.log
log_level  = debug
admin_email = $admin_email
admin_country = $admin_country
admin_language = $admin_language
demo_data = $demo_data
instance_name = $instance_name
static_ip = $static_ip
port = 8069
EOL
sudo chown odoo:odoo /etc/odoo.conf

# Crear servei d'Odoo
echo ""
echo -e "${BLUE}Creant servei d'Odoo...${NC}"
sudo bash -c "cat > /etc/systemd/system/odoo-server.service"
<<EOL
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
EOL

# Iniciar i habilitar el servei
echo ""
echo -e "${BLUE}Iniciant i habilitant el servei d'Odoo...${NC}"
sudo systemctl daemon-reload
sudo systemctl start odoo-server
sudo systemctl enable odoo-server

# Instal·lar mòduls bàsics
install_basic_modules

# Instal·lació de Nginx
echo ""
echo -e "${BLUE}Instal·lant Nginx...${NC}"
sudo apt install nginx -y

# Configuració de Nginx
echo ""
echo -e "${BLUE}Configurant Nginx per Odoo...${NC}"
sudo bash -c "cat > /etc/nginx/sites-available/$custom_domain"
<<EOL
upstream odoo16 {
    server 127.0.0.1:8069;
}

server {
    listen 80;
    server_name $custom_domain;

    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    location / {
        proxy_pass http://odoo16;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOL

# Activar configuració Nginx
echo ""
echo -e "${BLUE}Activant configuració Nginx...${NC}"
sudo ln -s /etc/nginx/sites-available/$custom_domain /etc/nginx/sites-enabled/
sudo nginx -t

# Configurar SSL
configure_ssl

# Reiniciar Nginx per aplicar els canvis
sudo systemctl restart nginx

# Funció per esborrar fitxers .deb i .sh
function delete_deb_and_sh_files {
  echo ""
  echo -e "${BLUE}Cercant i esborrant fitxers .deb i .sh al directori arrel...${NC}"

  # Busca i elimina fitxers .deb i .sh
  sudo find / -type f \( -name "*.deb" -o -name "*.sh" \) -exec rm -f {} +

  echo -e "${GREEN}Tots els fitxers .deb i .sh han estat eliminats del directori arrel.${NC}"
}

# Esborrar fitxers .deb i .sh
delete_deb_and_sh_files

# Test d'accés a Odoo
function test_odoo_access {
  echo ""
  echo -e "${BLUE}Verificant l'accés a Odoo...${NC}"

  # Comprovar accés per IP
  if curl -s -o /dev/null -w "%{http_code}" "https://$static_ip:8069" | grep -q "200"; then
    echo -e "${GREEN}Accés correcte mitjançant la IP: ${YELLOW}https://$static_ip:8069${NC}"
  else
    echo -e "${RED}No s'ha pogut accedir a Odoo mitjançant la IP: ${YELLOW}https://$static_ip:8069${NC}"
  fi

  # Comprovar accés pel domini
  if curl -s -o /dev/null -w "%{http_code}" "https://$custom_domain" | grep -q "200"; then
    echo -e "${GREEN}Accés correcte mitjançant el domini: ${YELLOW}https://$custom_domain${NC}"
  else
    echo -e "${RED}No s'ha pogut accedir a Odoo mitjançant el domini: ${YELLOW}https://$custom_domain${NC}"
  fi
}

# Cridar el test d'accés
test_odoo_access

# Mostrar les variables i el missatge final
mostrar_valors
echo ""
echo -e "${BLUE}Instal·lació d'Odoo completada correctament!${NC}"
echo ""
echo -e "${BLUE}Creeu el següent registre al Keeweb:${NC}"
echo -e "  Nom del registre: ${YELLOW}$instance_name${NC}"
echo -e "  Web: ${YELLOW}$custom_domain${NC}"
echo -e "  IP estàtica: ${YELLOW}$static_ip${NC}"
echo -e "  Master Password: ${YELLOW}$master_password${NC}"
echo -e "  Nom de la base de dades: ${YELLOW}$db_name${NC}"
echo -e "  Usuari de la base de dades: ${YELLOW}$db_user${NC}"
echo -e "  Contrasenya de la base de dades: ${YELLOW}$db_password${NC}"
echo -e "  Correu electrònic de l'administrador: ${YELLOW}$admin_email${NC}"
echo -e "  Contrasenya de l'administrador: ${YELLOW}$admin_password${NC}"
echo ""
echo -e "${BLUE}Accedeix a Odoo mitjançant el domini: ${YELLOW}https://$custom_domain${NC} o ${YELLOW}https://$static_ip:8069${NC}"

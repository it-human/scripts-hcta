#!/bin/bash

# Aquest script automatitza la instal·lació d'Odoo 16 amb PostgreSQL 14 en una instància d'AWS (com Lightsail).
# Inclou configuració de seguretat, Nginx, selecció de mòduls d'Odoo, i opcionalment mòduls de tercers i Server Tools.
#
# Explicació detallada del que fa l'script:
#
# 1. **Recollida de dades**:
#    - Demana la informació necessària per configurar Odoo i la base de dades: IP estàtica, contrasenyes, correu electrònic, etc.
#    - Genera contrasenyes aleatòries de 16 caràcters per a:
#        - **Master Password**
#        - **Contrasenya de la base de dades**
#        - **Contrasenya de l'administrador**
#    - Demana a l'usuari l'**idioma** i el **país** amb valors per defecte preestablerts (Català i Spain) i posa per defecte el correu de l'administrador 'it@humancta.org'.

#    - **El nom de la base de dades i l'usuari es generen automàticament a partir del nom de la instància introduïda**.
#    - Pregunta si es volen instal·lar dades de mostra (resposta per defecte: n).
# 
# 2. **Selecció de mòduls**:
#    - Mostra una llista de mòduls predeterminats d'Odoo (CRM, Comptabilitat, Inventari, etc.) i permet escollir quins es volen instal·lar (resposta per defecte: s).
#    - Els **Server Tools** també es poden seleccionar mitjançant la mateixa opció (resposta per defecte: s).
#
# 3. **Instal·lació de mòduls i Server Tools**:
#    - Crea carpetes per a cada mòdul i Server Tool seleccionat, i copia els fitxers corresponents dins les carpetes individuals dins `/opt/odoo/odoo-server/addons` i `/opt/odoo/odoo-server/addons/server-tools`.
#
# 4. **Actualització del servidor**:
#    - Actualitza el sistema amb `sudo apt update -y && sudo apt upgrade -y`.
#
# 5. **Instal·lació de llibreries i dependències**:
#    - Instal·la les llibreries necessàries (Python, Git, Node.js, Wkhtmltopdf) per fer funcionar Odoo.
#
# 6. **Instal·lació de PostgreSQL**:
#    - Instal·la PostgreSQL 14 i crea l'usuari i base de dades necessària per Odoo.
#
# 7. **Creació de l'usuari Odoo**:
#    - Crea un usuari dedicat d'Odoo per a una millor seguretat i aïllament dels processos.
#
# 8. **Configuració de l'arxiu `odoo.conf`**:
#    - Configura les rutes d'addons, la base de dades, contrasenyes, **logs**, i altres opcions d'Odoo dins l'arxiu `/etc/odoo.conf`.
#    - Els **logs** es registren a `/var/log/odoo/odoo-server.log`. El nivell de logs es pot ajustar mitjançant el paràmetre `log_level` (`debug`, `info`, `warning`, `error`).
#    - Es pot configurar la rotació dels **logs** amb eines com `logrotate`.
#
# 9. **Creació del servei d'Odoo**:
#    - Configura Odoo com un servei del sistema mitjançant `systemd`, per assegurar que s'executa automàticament.
#
# 10. **Configuració de Nginx**:
#    - Instal·la Nginx i el configura com a servidor intermediari que redirigeix les peticions HTTP a Odoo.
#
# 11. **Instal·lació automàtica dels mòduls seleccionats**:
#    - Instal·la tots els mòduls i Server Tools seleccionats a la base de dades d'Odoo i informa si la instal·lació ha estat correcta.
#
# 12. **Missatge final amb dades importants i suggeriment per Keeweb**:
#    - Mostra un missatge final amb totes les dades de configuració (IP, base de dades, contrasenyes) i recomana guardar-les en un gestor de contrasenyes com Keeweb.

# Funció per generar una contrasenya aleatòria de 16 caràcters
function generate_random_password {
  echo "$(tr -dc 'A-Za-z0-9!@#$%^&*()_+=-' < /dev/urandom | head -c 16)"
}

# Funció per demanar dades obligatòries
function prompt_required {
  local prompt_text=$1
  local default_value=$2
  read -p "$prompt_text: $default_value " input_value
  echo ${input_value:-$default_value}
}

# Funció per demanar dades amb validació "s/n", amb resposta per defecte a "s"
function prompt_yes_no {
  local prompt_text=$1
  local default_value=$2
  read -p "$prompt_text (s/n): $default_value " input_value
  input_value=${input_value:-$default_value}
  while [[ ! "$input_value" =~ ^[sSnN]$ ]]; do
    read -p "$prompt_text (s/n): $default_value " input_value
    input_value=${input_value:-$default_value}
  done
  echo "$input_value"
}

# Demanar el nom de la instància abans de tot
instance_name=$(prompt_required "Introdueix el nom de la instància de Lightsail")

# Generar valors per defecte per la base de dades i l'usuari basat en el nom de la instància
db_name_default="${instance_name}_db"
db_user_default="${instance_name}_user"

# Generar contrasenyes aleatòries per defecte
master_password_default=$(generate_random_password)
db_password_default=$(generate_random_password)
admin_password_default=$(generate_random_password)

# Demanar la resta de paràmetres amb els valors per defecte calculats
static_ip=$(prompt_required "Introdueix la IP estàtica de la instància")
custom_domain=$(prompt_required "Introdueix el nom de domini (per exemple, example.com)")
master_password=$(prompt_required "Introdueix la contrasenya de Master Password" "$master_password_default")
db_name=$(prompt_required "Introdueix el nom de la base de dades" "$db_name_default")
db_user=$(prompt_required "Introdueix el nom d'usuari de la base de dades" "$db_user_default")
db_password=$(prompt_required "Introdueix la contrasenya de l'usuari de la base de dades" "$db_password_default")
admin_email=$(prompt_required "Introdueix el correu electrònic de l'administrador" "it@humancta.org") #correu per defecte it@humancta.org
admin_password=$(prompt_required "Introdueix la contrasenya de l'administrador" "$admin_password_default")

# Demanar idioma i país amb valors per defecte
admin_language=$(prompt_required "Introdueix l'idioma" "Català")  # Idioma per defecte Català
admin_country=$(prompt_reqired "Introdueix el país" "Spain")     # País per defecte Spain

install_demo_data=$(prompt_yes_no "Vols instal·lar dades de mostra? (s/n)" "n")  # Dades de mostra per defecte NO

# Convertir la resposta de "s" o "n" en booleà per la configuració
if [[ "$install_demo_data" == "s" || "$install_demo_data" == "S" ]]; then
  demo_data="True"
else
  demo_data="False"
fi

# Llista completa de mòduls d'Odoo 16 per defecte amb noms en català
default_modules=(
  "sales_management (Gestió de vendes)"
  "crm (Gestió de clients)"
  "account (Comptabilitat)"
  "purchase (Compres)"
  "inventory (Inventari)"
  "project (Projectes)"
  "hr (Recursos humans)"
  "website (Lloc web)"
  "mail (Correu)"
  "calendar (Calendari)"
  "contacts (Contactes)"
  "point_of_sale (Punt de venda)"
  "mrp (Manufactura)"
  "stock (Gestió d'inventaris)"
  "sale (Gestió de comandes)"
  "fleet (Gestió de flotes)"
  "hr_holidays (Gestió de vacances)"
  "hr_expense (Despeses)"
  "website_sale (E-commerce)"
  "sale_management (Gestió de vendes)"
  "l10n_generic_coa (Pla general comptable)"
  "account_accountant (Comptabilitat avançada)"
  "account_asset (Gestió d'actius)"
  "hr_recruitment (Reclutament)"
  "maintenance (Manteniment)"
  "mrp_account (Comptabilitat de manufactura)"
  "website_crm (Gestió de clients en línia)"
  "event (Gestió d'esdeveniments)"
  "website_event (Esdeveniments al lloc web)"
  "website_blog (Blog del lloc web)"
)

# Llista de Server Tools disponibles
server_tools_modules=(
  "base_setup (Configuració de base)"
  "base_automation (Automatització)"
  "auditlog (Registre d'auditories)"
  "cron (Gestió de tasques programades)"
  "dbfilter_from_header (Filtre de base de dades per capçalera)"
)

# Arrays per guardar mòduls seleccionats
selected_default_modules=()
selected_server_tools=()

# Selecció dels mòduls predeterminats d'Odoo
echo "Selecciona els mòduls d'Odoo que vols instal·lar (s/n per a cadascun, 's' per defecte):"

# Llista tots els mòduls amb 's' per defecte
for module in "${default_modules[@]}"; do
  read -p "$module (s/n) [s]: " choice
  choice=${choice:-s}  # 's' és per defecte
  if [[ "$choice" == "s" || "$choice" == "S" ]]; then
    module_name=$(echo $module | cut -d' ' -f1)  # Nom del mòdul sense descripció
    selected_default_modules+=("$module_name")   # Afegeix el mòdul seleccionat
  fi
done

# Selecció dels Server Tools
echo "Selecciona els Server Tools que vols instal·lar (s/n per a cadascun, 's' per defecte):"

# Llista tots els Server Tools amb 's' per defecte
for tool in "${server_tools_modules[@]}"; do
  read -p "$tool (s/n) [s]: " choice
  choice=${choice:-s}  # 's' és per defecte
  if [[ "$choice" == "s" || "$choice" == "S" ]]; then
    tool_name=$(echo $tool | cut -d' ' -f1)  # Nom del tool sense descripció
    selected_server_tools+=("$tool_name")    # Afegeix el tool seleccionat
  fi
done

# Confirmació final dels mòduls i Server Tools seleccionats
echo "Mòduls per defecte seleccionats per a la instal·lació:"
for module in "${selected_default_modules[@]}"; do
  echo "- $module"
done

echo ""
echo "Server Tools seleccionats per a la instal·lació:"
for tool in "${selected_server_tools[@]}"; do
  echo "- $tool"
done

read -p "Vols continuar amb aquests mòduls seleccionats? (s/n) [s]: " confirm_modules
confirm_modules=${confirm_modules:-s}
if [[ $confirm_modules != "s" ]]; then
  echo "Instal·lació cancel·lada."
  exit 1
fi


# Mostrar els valors seleccionats
function mostrar_valors {
  echo "Configuració seleccionada:"
  echo "  Nom de la instància de Lightsail: $instance_name"
  echo "  IP estàtica de la instància: $static_ip"
  echo "  Nom de domini: $custom_domain"
  echo "  Master Password: $master_password"
  echo "  Nom de la base de dades: $db_name"
  echo "  Usuari de la base de dades: $db_user"
  echo "  Contrasenya de la base de dades: $db_password"
  echo "  Correu electrònic de l'administrador: $admin_email"
  echo "  Contrasenya de l'administrador: $admin_password"
  echo "  Idioma: $admin_language"
  echo "  País: $admin_country"
  echo "  Instal·lació de dades de mostra: $demo_data"
  echo "  Mòduls per defecte seleccionats: ${selected_default_modules[*]}"
  echo "  Server Tools seleccionats: ${selected_server_tools[*]}"
  echo
}

# Confirmar els valors abans de continuar
mostrar_valors

read -p "Vols continuar amb aquests valors? (s/n): " confirm
if [[ $confirm != "s" ]]; then
  echo "Instal·lació cancel·lada."
  exit 1
fi

# Actualitzar el servidor
echo "Actualitzant el servidor..."
sudo apt update -y && sudo apt upgrade -y

# Instal·lació de seguretat SSH i Fail2ban
echo "Instal·lant seguretat SSH i Fail2ban..."
sudo apt-get install openssh-server fail2ban -y

# Instal·lació de llibreries necessàries
echo "Instal·lant llibreries necessàries..."
sudo apt install vim curl wget gpg git gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates -y
sudo apt install build-essential wget git python3 python3-pip python3-dev python3-venv python3-wheel libfreetype6-dev libxml2-dev libzip-dev libsasl2-dev python3-setuptools libjpeg-dev zlib1g-dev libpq-dev libxslt1-dev libldap2-dev libtiff5-dev libopenjp2-7-dev -y

# Instal·lació de Node.js i NPM
echo "Instal·lant Node.js i NPM..."
sudo apt install nodejs npm node-less xfonts-75dpi xfonts-base fontconfig -y
sudo npm install -g rtlcss

# Instal·lació de Wkhtmltopdf
echo "Instal·lant Wkhtmltopdf..."
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_amd64.deb
sudo apt-get install -f -y

# Instal·lació de PostgreSQL 14
echo "Instal·lant PostgreSQL 14..."
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt update
sudo apt -y install postgresql-14 postgresql-client-14

# Creació de la base de dades i usuari PostgreSQL per Odoo
echo "Creant base de dades i usuari PostgreSQL per Odoo..."
sudo su - postgres -c "psql -c \"CREATE DATABASE $db_name;\""
sudo su - postgres -c "createuser -p 5432 -s $db_user"
sudo su - postgres -c "psql -c \"ALTER USER $db_user WITH PASSWORD '$db_password';\""

# Configurar autenticació PostgreSQL
echo "Configurant autenticació PostgreSQL..."
sudo bash -c "echo 'local   all             all                                     md5' >> /etc/postgresql/14/main/pg_hba.conf"
sudo systemctl restart postgresql

# Creació de l'usuari Odoo
echo "Creant usuari Odoo al sistema..."
sudo adduser --system --group --home=/opt/odoo --shell=/bin/bash odoo

# Clonar el repositori Odoo 16
echo "Clonant el repositori Odoo 16..."
sudo su - odoo -c "git clone https://github.com/odoo/odoo.git --depth 1 --branch 16.0 --single-branch /opt/odoo/odoo-server"

# Crear entorn virtual de Python
echo "Creant entorn virtual de Python..."
sudo su - odoo -c "python3 -m venv /opt/odoo/odoo-server/venv"
sudo su - odoo -c "/opt/odoo/odoo-server/venv/bin/pip install wheel"
sudo su - odoo -c "/opt/odoo/odoo-server/venv/bin/pip install -r /opt/odoo/odoo-server/requirements.txt"

# Crear carpetes separades per cada mòdul dins d'addons i copiar els arxius
echo "Creant carpetes per a cada mòdul dins d'addons..."
for module in "${selected_default_modules[@]}"; do
  sudo mkdir -p /opt/odoo/odoo-server/addons/$module
  echo "Carpeta creada per a $module dins /opt/odoo/odoo-server/addons"
  # Copiar els arxius de cada mòdul dins la carpeta corresponent
  sudo cp -r /opt/odoo/odoo-server/odoo/addons/$module/* /opt/odoo/odoo-server/addons/$module/
  echo "Arxius copiats a /opt/odoo/odoo-server/addons/$module"
done

# Crear carpetes per Server Tools dins de server-tools
echo "Creant carpetes per als Server Tools dins server-tools..."
for tool in "${selected_server_tools[@]}"; do
  sudo mkdir -p /opt/odoo/odoo-server/server-tools/$tool
  echo "Carpeta creada per a $tool dins /opt/odoo/odoo-server/server-tools"
done

# Exemple per clonar un mòdul de tercers dins custom_addons:
# Substitueix "third_party_module" pel nom del mòdul de tercers que vulguis clonar.
# sudo mkdir -p /opt/odoo/odoo-server/custom_addons/third_party_module
# sudo su - odoo -c "git clone https://github.com/third_party_repo/third_party_module.git /opt/odoo/odoo-server/custom_addons/third_party_module"
# Nota: Substitueix "third_party_module" pel nom correcte del mòdul de tercers.

# Crear directori de logs
echo "Creant directori de logs..."
sudo mkdir /var/log/odoo
sudo touch /var/log/odoo/odoo-server.log
sudo chown odoo:odoo /var/log/odoo -R
sudo chmod 777 /var/log/odoo

# Crear fitxer de configuració d'Odoo
echo "Creant fitxer de configuració d'Odoo..."
sudo bash -c "cat > /etc/odoo.conf" <<EOL
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
echo "Creant servei d'Odoo..."
sudo bash -c "cat > /etc/systemd/system/odoo-server.service" <<EOL
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
echo "Iniciant i habilitant el servei d'Odoo..."
sudo systemctl daemon-reload
sudo systemctl start odoo-server
sudo systemctl enable odoo-server

# Instal·lació de Nginx
echo "Instal·lant Nginx..."
sudo apt install nginx -y

# Configuració de Nginx
echo "Configurant Nginx per Odoo..."
sudo bash -c "cat > /etc/nginx/sites-available/$custom_domain" <<EOL
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
echo "Activant configuració Nginx..."
sudo ln -s /etc/nginx/sites-available/$custom_domain /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Mostrar les variables i el missatge final
mostrar_valors
echo "Instal·lació d'Odoo completada correctament!"
echo
echo "Creeu el següent registre al Keeweb:"
echo "Nom del registre: $instance_name"
echo "Web: $custom_domain"
echo "IP estàtica: $static_ip"
echo "Master Password: $master_password"
echo "Nom de la base de dades: $db_name"
echo "Usuari de la base de dades: $db_user"
echo "Contrasenya de la base de dades: $db_password"
echo "Correu electrònic de l'administrador: $admin_email"
echo "Contrasenya de l'administrador: $admin_password"
echo
echo "Accedeix a Odoo mitjançant el domini: http://$custom_domain o http://$static_ip:8069"


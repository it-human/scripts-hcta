#!/bin/bash

# Colors per als missatges
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # Reset

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

# Funció per descarregar fitxers amb reintents
function wget_with_retries {
  local url=$1         # URL del fitxer a descarregar
  local output=$2      # Nom del fitxer de sortida
  local retry_limit=5  # Nombre màxim de reintents
  local retry_count=0

  while [ $retry_count -lt $retry_limit ]; do
    echo -e "${BLUE}Intentant descarregar $url (Intent $((retry_count + 1))/$retry_limit)...${NC}"
    wget -O "$output" "$url"

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Descarregat correctament: $url.${NC}"
      return 0
    else
      echo -e "${YELLOW}Error descarregant $url. Reintentant en 5 segons...${NC}"
      sleep 5
      retry_count=$((retry_count + 1))
    fi
  done

  echo -e "${RED}No s'ha pogut descarregar $url després de $retry_limit intents.${NC}"
  return 1
}


# Funció per clonar repositoris amb reintents
function clone_repository_with_retries {
  local repo_url=$1       # URL del repositori
  local target_dir=$2     # Directori de destí
  local branch_name=$3    # Nom de la branca a clonar
  local retry_limit=5     # Nombre màxim de reintents

  echo -e "${BLUE}Clonant el repositori: ${YELLOW}$repo_url${NC} a ${YELLOW}$target_dir${NC}..."

  local retry_count=0
  sudo rm -rf "$target_dir"  # Eliminar el directori existent si cal

  while [ $retry_count -lt $retry_limit ]; do
    echo -e "${BLUE}Intentant clonar el repositori (Intent $((retry_count + 1))/$retry_limit)...${NC}"
    sudo su - odoo -c "git clone $repo_url --depth 1 --branch $branch_name --single-branch $target_dir"

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Repositori clonat correctament: ${YELLOW}$repo_url${NC}."
      return 0
    else
      echo -e "${YELLOW}Error al clonar el repositori. Reintentant en 5 segons...${NC}"
      sleep 5
      retry_count=$((retry_count + 1))
    fi
  done

  echo -e "${RED}No s'ha pogut clonar el repositori després de $retry_limit intents: $repo_url.${NC}"
  return 1
}


# Funció per executar curl amb reintents
function curl_with_retries {
  local url=$1         # URL a descarregar
  local output=$2      # Fitxer de sortida
  local retry_limit=5  # Nombre màxim de reintents
  local retry_count=0

  while [ $retry_count -lt $retry_limit ]; do
    echo -e "${BLUE}Intentant descarregar $url (Intent $((retry_count + 1))/$retry_limit)...${NC}"
    curl -fsSL "$url" -o "$output"

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Descarregat correctament: $url.${NC}"
      return 0
    else
      echo -e "${YELLOW}Error descarregant $url. Reintentant en 5 segons...${NC}"
      sleep 5
      retry_count=$((retry_count + 1))
    fi
  done

  echo -e "${RED}No s'ha pogut descarregar $url després de $retry_limit intents.${NC}"
  return 1
}


# Demanar el nom de la instància abans de tot
echo ""
instance_name=$(prompt_required_no_default "Introdueix el nom de la instància de Lightsail")

# Generar valors per defecte per la base de dades i l'usuari basat en el nom de la instància
# Assignar valors per defecte i convertir a minúscules
db_name_default=$(echo "${instance_name//[-]/_}_db" | tr '[:upper:]' '[:lower:]')
db_user_default=$(echo "${instance_name//[-]/_}_user" | tr '[:upper:]' '[:lower:]')


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
  
  
  # Funció per descarregar fitxers amb reintents
function wget_with_retries {
  local url=$1         # URL del fitxer a descarregar
  local output=$2      # Nom del fitxer de sortida
  local retry_limit=5  # Nombre màxim de reintents
  local retry_count=0

  while [ $retry_count -lt $retry_limit ]; do
    echo -e "${BLUE}Intentant descarregar $url (Intent $((retry_count + 1))/$retry_limit)...${NC}"
    wget -O "$output" "$url"

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Descarregat correctament: $url.${NC}"
      return 0
    else
      echo -e "${YELLOW}Error descarregant $url. Reintentant en 5 segons...${NC}"
      sleep 5
      retry_count=$((retry_count + 1))
    fi
  done

  echo -e "${RED}No s'ha pogut descarregar $url després de $retry_limit intents.${NC}"
  return 1
}
  echo -e "  Idioma: ${YELLOW}$admin_language${NC}"
  echo -e "  País: ${YELLOW}$admin_country${NC}"
  echo -e "  Instal·lació de dades de mostra: ${YELLOW}$demo_data${NC}"
  echo -e "  Mòduls bàsics instal·lats:"
  # Llista dels mòduls bàsics instal·lats
  modules=("crm" "sales" "purchase" "stock" "account" "mail" "project" "website")
  for module in "${modules[@]}"; do
    echo -e "    - ${YELLOW}$module${NC}"
  done

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

  if sudo apt update -y && sudo apt upgrade -y; then
    echo -e "${GREEN}El servidor s'ha actualitzat correctament.${NC}"
  else
    echo -e "${RED}Error durant l'actualització del servidor.${NC}"
    exit 1
  fi


# Instal·lació de seguretat SSH i Fail2ban
echo ""
echo -e "${BLUE}Instal·lant seguretat SSH i Fail2ban...${NC}"

  # Instal·lar els paquets
  if sudo apt-get install -y openssh-server fail2ban; then
    echo -e "${GREEN}SSH i Fail2ban s'han instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error durant la instal·lació de SSH o Fail2ban.${NC}"
    exit 1
  fi

  # Activar el servei SSH
  echo ""
  echo -e "${BLUE}Activant el servei SSH...${NC}"
  if sudo systemctl enable ssh && sudo systemctl start ssh; then
    echo -e "${GREEN}El servei SSH s'ha activat i iniciat correctament.${NC}"
  else
    echo -e "${RED}Error activant o iniciant el servei SSH.${NC}"
    exit 1
  fi

  # Configurar Fail2ban
  echo ""
  echo -e "${BLUE}Configurant Fail2ban...${NC}"
  sudo systemctl enable fail2ban
  sudo systemctl start fail2ban
  if sudo systemctl status fail2ban | grep -q "active (running)"; then
    echo -e "${GREEN}Fail2ban s'ha configurat correctament.${NC}"
  else
    echo -e "${RED}Error configurant Fail2ban.${NC}"
    exit 1
  fi


# Instal·lació de Wkhtmltopdf
echo ""
echo -e "${BLUE}Instal·lant dependències per Wkhtmltopdf...${NC}"
  if sudo apt-get install -y fontconfig libjpeg-turbo8 libxrender1 xfonts-75dpi xfonts-base; then
    echo -e "${GREEN}Les dependències per Wkhtmltopdf s'han instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error durant la instal·lació de les dependències per Wkhtmltopdf.${NC}"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}Instal·lant Wkhtmltopdf...${NC}"
  if wget_with_retries "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb" "wkhtmltox_0.12.6.1-2.jammy_amd64.deb"; then
    echo -e "${GREEN}Wkhtmltopdf descarregat correctament.${NC}"
  else
    echo -e "${RED}Error durant la descàrrega de Wkhtmltopdf.${NC}"
    exit 1
  fi

  if sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_amd64.deb || sudo apt-get install -f -y || sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_amd64.deb; then
    echo -e "${GREEN}Wkhtmltopdf s'ha instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error durant la instal·lació de Wkhtmltopdf.${NC}"
    exit 1
  fi

  # Elimina el fitxer .deb per netejar
  rm -f wkhtmltox_0.12.6.1-2.jammy_amd64.deb
  echo -e "${GREEN}Fitxer d'instal·lació Wkhtmltopdf eliminat.${NC}"


# Instal·lació de llibreries necessàries
echo ""
echo -e "${BLUE}Instal·lant llibreries necessàries...${NC}"
sudo apt update
  if sudo apt install -y vim curl wget gpg git gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates build-essential python3 python3-pip python3-dev python3-venv python3-wheel libfreetype6-dev libxml2-dev libzip-dev libsasl2-dev python3-setuptools libjpeg-dev zlib1g-dev libpq-dev libxslt1-dev libldap2-dev libtiff5-dev libopenjp2-7-dev fontconfig fonts-dejavu-core fonts-dejavu-mono libfontconfig1 libfontenc1 libjpeg-turbo8 libxrender1 x11-common xfonts-75dpi xfonts-base xfonts-encodings xfonts-utils ssl-cert; then
    echo -e "${GREEN}Les llibreries s'han instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error durant la instal·lació de les llibreries.${NC}"
    exit 1
  fi


# Instal·lació de Node.js 18.x i NPM
echo ""
echo -e "${BLUE}Instal·lant Node.js i NPM (versió 18.x)...${NC}"

  # Descarregar l'script setup_18.x amb reintents
  if curl_with_retries "https://deb.nodesource.com/setup_18.x" "/tmp/setup_18.x"; then
    # Executar l'script de configuració si la descàrrega és correcta
    sudo -E bash /tmp/setup_18.x
    echo -e "${GREEN}Configuració de Node.js completada.${NC}"
    # Esborrar el fitxer temporal
    rm -f /tmp/setup_18.x
  else
    echo -e "${RED}Error: No s'ha pogut descarregar l'script de configuració de Node.js.${NC}"
    exit 1
  fi

  # Instal·lar Node.js i NPM
  if sudo apt-get install -y nodejs; then
    echo -e "${GREEN}Node.js instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error instal·lant Node.js.${NC}"
    exit 1
  fi

  # Actualitzar NPM a la versió 9
  if sudo npm install -g npm@9; then
    echo -e "${GREEN}NPM actualitzat a la versió 9 correctament.${NC}"
  else
    echo -e "${RED}Error actualitzant NPM.${NC}"
    exit 1
  fi

  # Instal·lar dependències addicionals
  echo ""
  echo -e "${BLUE}Instal·lant dependències addicionals...${NC}"
  if sudo apt-get install -y xfonts-75dpi xfonts-base fontconfig; then
    echo -e "${GREEN}Dependències instal·lades correctament.${NC}"
  else
    echo -e "${RED}Error instal·lant dependències.${NC}"
    exit 1
  fi

  # Instal·lar paquets globals amb NPM
  echo ""
  echo -e "${BLUE}Instal·lant paquets globals amb NPM...${NC}"
  if sudo npm install -g rtlcss less; then
    echo -e "${GREEN}Paquets globals instal·lats correctament.${NC}"
  else
    echo -e "${RED}Error instal·lant paquets globals amb NPM.${NC}"
    exit 1
  fi

  # Netejar el sistema
  echo ""
  echo -e "${BLUE}Netejant el sistema...${NC}"
  sudo apt autoremove -y
  echo -e "${GREEN}Neteja completada.${NC}"


# Instal·lació de PostgreSQL 14
echo ""
echo -e "${BLUE}Instal·lant PostgreSQL 14...${NC}"

  # Afegir la clau GPG per al repositori
  # Camí de destinació
  output_file="/usr/share/keyrings/postgresql-keyring.gpg"

  # Verifica si el directori existeix
  if [ ! -d "$(dirname "$output_file")" ]; then
    echo -e "${YELLOW}Creant directori per al fitxer de claus: $(dirname "$output_file")${NC}"
    sudo mkdir -p "$(dirname "$output_file")"
  fi
  # Assegura els permisos del directori
  sudo chmod 755 "$(dirname "$output_file")"

  # Descarregar clau GPG amb reintents i moure a la ubicació correcta
  if curl_with_retries "https://www.postgresql.org/media/keys/ACCC4CF8.asc" "/tmp/postgresql-keyring.gpg"; then
      sudo mv /tmp/postgresql-keyring.gpg /usr/share/keyrings/postgresql-keyring.gpg
      echo -e "${GREEN}Clau GPG de PostgreSQL descarregada i instal·lada correctament.${NC}"
  else
      echo -e "${RED}Error: No s'ha pogut descarregar la clau GPG de PostgreSQL.${NC}"
      exit 1
  fi

  # Afegir el repositori de PostgreSQL
  if echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list; then
    echo -e "${GREEN}Repositori de PostgreSQL afegit correctament.${NC}"
  else
    echo -e "${RED}Error afegint el repositori de PostgreSQL.${NC}"
    exit 1
  fi

  # Actualitzar els repositoris
  if sudo apt update; then
    echo -e "${GREEN}Repositoris actualitzats correctament.${NC}"
  else
    echo -e "${RED}Error actualitzant els repositoris.${NC}"
    exit 1
  fi

  # Instal·lar PostgreSQL 14
  if sudo apt -y install postgresql-14 postgresql-client-14; then
    echo -e "${GREEN}PostgreSQL 14 instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error instal·lant PostgreSQL 14.${NC}"
    exit 1
  fi


# Creació de la base de dades i usuari PostgreSQL per Odoo
echo ""
echo -e "${BLUE}Creant base de dades i usuari PostgreSQL per Odoo...${NC}"

  # Comprovar si la base de dades existeix
  db_exists=$(sudo su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname = '$db_name';\"")
  if [ "$db_exists" == "1" ]; then
    echo -e "${YELLOW}La base de dades $db_name existeix. Eliminant-la...${NC}"
    sudo su - postgres -c "psql -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db_name';\""
    sudo su - postgres -c "psql -c \"DROP DATABASE $db_name;\""
  else
    echo -e "${GREEN}La base de dades $db_name no existeix. Continuant...${NC}"
  fi

  # Comprovar si l'usuari existeix
  user_exists=$(sudo su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname = '$db_user';\"")
  if [ "$user_exists" == "1" ]; then
    echo -e "${YELLOW}L'usuari $db_user existeix. Eliminant-lo...${NC}"
    sudo su - postgres -c "psql -c \"DROP USER $db_user;\""
  else
    echo -e "${GREEN}L'usuari $db_user no existeix. Continuant...${NC}"
  fi

  # Crear la base de dades i l'usuari
  echo -e "${BLUE}Creant la base de dades i l'usuari...${NC}"
  sudo su - postgres -c "psql -c \"CREATE DATABASE $db_name;\""
  sudo su - postgres -c "psql -c \"CREATE USER $db_user WITH PASSWORD '$db_password';\""
  sudo su - postgres -c "psql -c \"ALTER USER $db_user WITH SUPERUSER;\""

echo -e "${GREEN}Base de dades $db_name i usuari $db_user creats correctament.${NC}"


# Configurar autenticació PostgreSQL
echo ""
echo -e "${BLUE}Configurant autenticació PostgreSQL...${NC}"

  # Afegir línia de configuració al fitxer pg_hba.conf
  sudo bash -c "echo 'local   all             all                                     md5' >> /etc/postgresql/14/main/pg_hba.conf"

  # Reiniciar el servei PostgreSQL
  if sudo systemctl restart postgresql; then
    echo -e "${GREEN}Configuració d'autenticació de PostgreSQL aplicada correctament i servei reiniciat.${NC}"
  else
    echo -e "${RED}Error en aplicar la configuració d'autenticació de PostgreSQL o en reiniciar el servei.${NC}"
    exit 1
  fi


# Creació de l'usuari Odoo
echo ""
echo -e "${BLUE}Creant usuari Odoo al sistema...${NC}"

# Comprovar si l'usuari ja existeix
  if id "odoo" &>/dev/null; then
    echo -e "${YELLOW}L'usuari «odoo» ja existeix. Saltant aquest pas.${NC}"
  else
    sudo adduser --system --group --home=/opt/odoo --shell=/bin/bash odoo
    echo -e "${GREEN}Usuari «odoo» creat correctament.${NC}"
  fi
  # Comprovar si el directori ja existeix
  if [ -d "/opt/odoo" ]; then
    echo -e "${YELLOW}El directori /opt/odoo ja existeix. Saltant aquest pas.${NC}"
  else
    sudo mkdir -p /opt/odoo
    sudo chown odoo:odoo /opt/odoo
    echo -e "${GREEN}Directori /opt/odoo creat correctament.${NC}"
  fi


# Clonar el repositori Odoo 16
#  echo ""
#  echo -e "${BLUE}Clonant el repositori Odoo 16...${NC}"
#  clone_repository_with_retries "https://github.com/odoo/odoo.git" "/opt/odoo/odoo-server" "16.0"


# Crear entorn virtual de Python
echo ""
echo -e "${BLUE}Creant entorn virtual de Python...${NC}"

  # Crear entorn virtual
  if sudo su - odoo -c "python3 -m venv /opt/odoo/odoo-server/venv"; then
    echo -e "${GREEN}Entorn virtual de Python creat correctament.${NC}"
  else
    echo -e "${RED}Error en crear l'entorn virtual de Python.${NC}"
    exit 1
  fi

  # Instal·lar wheel
  if sudo su - odoo -c "/opt/odoo/odoo-server/venv/bin/pip install wheel"; then
    echo -e "${GREEN}Paquet 'wheel' instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error en instal·lar el paquet 'wheel'.${NC}"
    exit 1
  fi

  # Instal·lar paquets des de requirements.txt
  if sudo su - odoo -c "/opt/odoo/odoo-server/venv/bin/pip install -r /opt/odoo/odoo-server/requirements.txt"; then
    echo -e "${GREEN}Tots els paquets de 'requirements.txt' instal·lats correctament.${NC}"
  else
    echo -e "${RED}Error en instal·lar els paquets de 'requirements.txt'.${NC}"
    exit 1
  fi


# Crear directori de logs
echo ""
echo -e "${BLUE}Creant directori de logs...${NC}"

  # Crear el directori de logs
  if sudo mkdir -p /var/log/odoo; then
    echo -e "${GREEN}Directori de logs creat correctament.${NC}"
  else
    echo -e "${RED}Error en crear el directori de logs.${NC}"
    exit 1
  fi

  # Crear el fitxer de log
  if sudo touch /var/log/odoo/odoo-server.log; then
    echo -e "${GREEN}Fitxer de log creat correctament.${NC}"
  else
    echo -e "${RED}Error en crear el fitxer de log.${NC}"
    exit 1
  fi

  # Establir permisos i propietari
  if sudo chown odoo:odoo /var/log/odoo -R && sudo chmod 777 /var/log/odoo; then
    echo -e "${GREEN}Permisos i propietari configurats correctament per al directori de logs.${NC}"
  else
    echo -e "${RED}Error en configurar permisos i propietari per al directori de logs.${NC}"
    exit 1
  fi


# Crear fitxer de configuració d'Odoo
echo ""
echo -e "${BLUE}Creant fitxer de configuració d'Odoo...${NC}"

  # Escriure el fitxer de configuració
  if sudo bash -c "cat > /etc/odoo.conf <<EOL
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
EOL";
  then
    echo -e "${GREEN}Fitxer de configuració creat correctament.${NC}"
  else
    echo -e "${RED}Error en crear el fitxer de configuració.${NC}"
    exit 1
  fi

  # Establir permisos per al fitxer de configuració
  if sudo chown odoo:odoo /etc/odoo.conf; then
    echo -e "${GREEN}Permisos configurats correctament per al fitxer de configuració.${NC}"
  else
    echo -e "${RED}Error en configurar els permisos del fitxer de configuració.${NC}"
    exit 1
  fi


# Crear servei d'Odoo
echo ""
echo -e "${BLUE}Creant servei d'Odoo...${NC}"

  # Escriure el fitxer de servei
  if sudo bash -c "cat > /etc/systemd/system/odoo-server.service <<EOL
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
EOL";
  then
    echo -e "${GREEN}Fitxer de servei creat correctament.${NC}"
  else
    echo -e "${RED}Error en crear el fitxer de servei.${NC}"
    exit 1
  fi

  # Reload systemd, iniciar i habilitar el servei
  echo -e "${BLUE}Recarregant systemd i activant el servei...${NC}"
  if sudo systemctl daemon-reload && sudo systemctl start odoo-server && sudo systemctl enable odoo-server; then
    echo -e "${GREEN}Servei d'Odoo creat i activat correctament.${NC}"
  else
    echo -e "${RED}Error en activar el servei d'Odoo.${NC}"
    exit 1
  fi


# Iniciar i habilitar el servei
echo ""
echo -e "${BLUE}Iniciant i habilitant el servei d'Odoo...${NC}"

  # Recarregar systemd
  if sudo systemctl daemon-reload; then
    echo -e "${GREEN}Systemd recarregat correctament.${NC}"
  else
    echo -e "${RED}Error en recarregar systemd.${NC}"
    exit 1
  fi

  # Iniciar el servei
  if sudo systemctl start odoo-server; then
    echo -e "${GREEN}El servei d'Odoo s'ha iniciat correctament.${NC}"
  else
    echo -e "${RED}Error en iniciar el servei d'Odoo.${NC}"
    sudo journalctl -xeu odoo-server | tail -n 20
    exit 1
  fi

  # Habilitar el servei
  if sudo systemctl enable odoo-server; then
    echo -e "${GREEN}El servei d'Odoo s'ha habilitat correctament per arrencar amb el sistema.${NC}"
  else
    echo -e "${RED}Error en habilitar el servei d'Odoo.${NC}"
    exit 1
  fi


# Instal·lar mòduls bàsics
  #for module in "${modules[@]}"; do
  #  echo -e "${BLUE}Clonant el mòdul: ${YELLOW}$module${NC}"
  # clone_repository_with_retries "https://github.com/odoo/odoo.git" "/opt/odoo/odoo-server/addons/$module" "16.0"
  # done


# Instal·lació de Nginx
echo ""
echo -e "${BLUE}Instal·lant Nginx...${NC}"

  # Eliminar instal·lació prèvia de Nginx
  echo ""
  echo -e "${BLUE}Comprovant si hi ha una instal·lació prèvia de Nginx...${NC}"
  if dpkg -l | grep -q nginx; then
    echo -e "${YELLOW}S'ha detectat una instal·lació prèvia de Nginx. Eliminant-la...${NC}"
    sudo systemctl stop nginx || true
    sudo apt purge -y nginx* || true
    sudo rm -rf /etc/nginx /var/log/nginx /var/lib/nginx
    echo -e "${GREEN}Instal·lació prèvia de Nginx eliminada correctament.${NC}"
  else
    echo -e "${GREEN}No s'ha detectat cap instal·lació prèvia de Nginx.${NC}"
  fi

  # Instal·lar Nginx
  if sudo apt install -y nginx; then
    echo -e "${GREEN}Nginx instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error en instal·lar Nginx.${NC}"
    exit 1
  fi

  # Comprovar l'estat del servei Nginx
  if sudo systemctl status nginx > /dev/null 2>&1; then
    echo -e "${GREEN}El servei Nginx està actiu i en funcionament.${NC}"
  else
    echo -e "${YELLOW}Nginx està instal·lat però no s'ha pogut iniciar automàticament. Intentant iniciar-lo...${NC}"
    if sudo systemctl start nginx; then
      echo -e "${GREEN}Nginx iniciat manualment amb èxit.${NC}"
    else
      echo -e "${RED}Error en iniciar el servei Nginx. Comprova els registres amb 'journalctl -xeu nginx'.${NC}"
      exit 1
    fi
  fi


# Configuració de Nginx
echo ""
echo -e "${BLUE}Configurant Nginx per Odoo...${NC}"

  # Comprovar i eliminar configuracions anteriors si existeixen
  if [ -f /etc/nginx/sites-available/$custom_domain ]; then
    echo -e "${YELLOW}El fitxer /etc/nginx/sites-available/$custom_domain ja existeix. Eliminant-lo...${NC}"
    sudo rm -f /etc/nginx/sites-available/$custom_domain
    echo -e "${GREEN}Fitxer /etc/nginx/sites-available/$custom_domain eliminat correctament.${NC}"
  else
    echo -e "${YELLOW}El fitxer /etc/nginx/sites-available/$custom_domain no existeix.${NC}"
  fi

  if [ -L /etc/nginx/sites-enabled/$custom_domain ]; then
    echo -e "${YELLOW}L'enllaç simbòlic /etc/nginx/sites-enabled/$custom_domain ja existeix. Eliminant-lo...${NC}"
    sudo rm -f /etc/nginx/sites-enabled/$custom_domain
    echo -e "${GREEN}Enllaç simbòlic /etc/nginx/sites-enabled/$custom_domain eliminat correctament.${NC}"
  else
    echo -e "${YELLOW}L'enllaç simbòlic /etc/nginx/sites-enabled/$custom_domain no existeix.${NC}"
  fi


# Crear el nou fitxer de configuració
echo -e "${BLUE}Creant el fitxer de configuració per a $custom_domain...${NC}"
if sudo bash -c "cat > /etc/nginx/sites-available/$custom_domain <<EOL
  upstream odoo16 {
    server 127.0.0.1:8069;
  }

  upstream odoochat {
      server 127.0.0.1:8072;
  }

  server {
      listen 80;
      server_name $custom_domain;

      access_log /var/log/nginx/odoo.access.log;
      error_log /var/log/nginx/odoo.error.log;

      # Optimització del buffer
      proxy_buffers 16 64k;
      proxy_buffer_size 128k;

      # Trànsit general
      location / {
          proxy_pass http://odoo16;
          proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
          proxy_redirect off;
          proxy_set_header Host \$host;
          proxy_set_header X-Real-IP \$remote_addr;
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
      }

      # Long polling (per a xats o notificacions en temps real)
      location /longpolling {
          proxy_pass http://odoochat;
      }

      # Recursos estàtics amb memòria cau
      location ~* /web/static/ {
          proxy_cache_valid 200 60m;
          proxy_buffering on;
          expires 864000;
          proxy_pass http://odoo16;
      }
  }
EOL";
  then
    echo -e "${GREEN}Fitxer de configuració creat correctament.${NC}"
  else
    echo -e "${RED}Error en crear el fitxer de configuració per a $custom_domain.${NC}"
    exit 1
  fi

  # Reiniciar Nginx per aplicar els canvis
  echo -e "${BLUE}Reiniciant Nginx per aplicar els canvis...${NC}"
  if sudo systemctl restart nginx; then
    echo -e "${GREEN}Nginx reiniciat correctament.${NC}"
  else
    echo -e "${RED}Error en reiniciar Nginx. Revisa els registres per trobar més informació.${NC}"
    exit 1
  fi

# Activar configuració Nginx
echo ""
echo -e "${BLUE}Activant configuració Nginx per a $custom_domain...${NC}"

  # Verificar si l'enllaç simbòlic ja existeix
  if [ -L "/etc/nginx/sites-enabled/$custom_domain" ]; then
    echo -e "${YELLOW}L'enllaç simbòlic ja existeix per a $custom_domain. No cal crear-lo.${NC}"
  else
    # Crear un nou enllaç simbòlic
    if sudo ln -s "/etc/nginx/sites-available/$custom_domain" "/etc/nginx/sites-enabled/"; then
      echo -e "${GREEN}Configuració Nginx activada correctament per al domini $custom_domain.${NC}"
    else
      echo -e "${RED}Error activant la configuració Nginx per al domini $custom_domain.${NC}"
      exit 1
    fi
  fi


# Verificar configuració de Nginx
echo ""
echo -e "${BLUE}Verificant configuració de Nginx...${NC}"
  if sudo nginx -t; then
    echo -e "${GREEN}La configuració de Nginx és correcta.${NC}"
  else
    echo -e "${RED}Error en la configuració de Nginx. Comprova els logs.${NC}"
    exit 1
  fi


# Configurar SSL amb Let's Encrypt
echo ""
echo -e "${BLUE}Configurant SSL amb Let's Encrypt...${NC}"

  # Instal·lar Certbot
  echo -e "${BLUE}Instal·lant Certbot i el plugin per a Nginx...${NC}"
  if sudo apt install -y certbot python3-certbot-nginx; then
    echo -e "${GREEN}Certbot instal·lat correctament.${NC}"
  else
    echo -e "${RED}Error instal·lant Certbot. Revisa la configuració del sistema.${NC}"
    exit 1
  fi

  # Generar certificat SSL per al domini
  echo -e "${BLUE}Generant certificat SSL per al domini $custom_domain...${NC}"
  if sudo certbot --nginx --non-interactive --agree-tos -m "$admin_email" -d "$custom_domain"; then
    echo -e "${GREEN}SSL configurat correctament per al domini $custom_domain.${NC}"
  else
    echo -e "${RED}Hi ha hagut un problema configurant SSL per al domini $custom_domain. Revisa els logs per obtenir més informació.${NC}"
    exit 1
  fi


# Reiniciar Nginx per aplicar els canvis
echo ""
echo -e "${BLUE}Verificant la configuració de Nginx abans de reiniciar...${NC}"

if sudo nginx -t; then
  echo -e "${GREEN}La configuració de Nginx és vàlida. Reiniciant Nginx...${NC}"
  if sudo systemctl restart nginx; then
    echo -e "${GREEN}Nginx reiniciat correctament.${NC}"
  else
    echo -e "${RED}Error en reiniciar Nginx. Comprova els logs del sistema per més informació.${NC}"
    exit 1
  fi
else
  echo -e "${RED}Error en la configuració de Nginx. No es pot reiniciar.${NC}"
  sudo nginx -t # Mostra els errors de configuració
  exit 1
fi


# Funció per esborrar fitxers .deb i .sh
echo ""
echo -e "${BLUE}Cercant i esborrant fitxers .deb i .sh al directori arrel, excloent ubicacions sensibles...${NC}"

  # Busca i elimina fitxers .deb i .sh fora de directoris crítics
  sudo find / -type f \( -name "*.deb" -o -name "*.sh" \) \
    -not -path "/proc/*" -not -path "/sys/*" -not -path "/dev/*" -not -path "/snap/*" \
    -exec rm -f {} + 2>/dev/null

  # Confirmació d'eliminació
  echo -e "${GREEN}Tots els fitxers .deb i .sh no essencials han estat eliminats.${NC}"


# Test d'accés a Odoo
echo ""
echo -e "${BLUE}Verificant l'accés a Odoo...${NC}"

  # Comprovar accés per IP
  response_code_ip=$(curl -s -o /dev/null -w "%{http_code}" "http://$static_ip:8069")
  if [ "$response_code_ip" -eq 200 ]; then
    echo -e "${GREEN}Accés correcte mitjançant la IP: ${YELLOW}http://$static_ip:8069${NC}"
  else
    echo -e "${RED}No s'ha pogut accedir a Odoo mitjançant la IP: ${YELLOW}http://$static_ip:8069${NC} (Codi HTTP: $response_code_ip)"
  fi

  # Comprovar accés pel domini
  response_code_domain=$(curl -s -o /dev/null -w "%{http_code}" "http://$custom_domain")
  if [ "$response_code_domain" -eq 200 ]; then
    echo -e "${GREEN}Accés correcte mitjançant el domini: ${YELLOW}http://$custom_domain${NC}"
  else
    echo -e "${RED}No s'ha pogut accedir a Odoo mitjançant el domini: ${YELLOW}http://$custom_domain${NC} (Codi HTTP: $response_code_domain)"
  fi


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

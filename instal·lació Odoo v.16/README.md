# 📦 Script per la instal·lació d'Odoo 16

**Script creat per a la instal·lació automàtica d'Odoo v.16 sobre PostgreSQL v.14
<br>
💾 "installacio-odoo_v16-postgres_v14.sh"**
<br><br>  

## 📑 Explicació de l'script:

Aquest script automatitza la instal·lació d'Odoo 16 amb PostgreSQL 14 en una instància d'AWS (com Lightsail). Inclou 
configuració de seguretat, Nginx, selecció de mòduls d'Odoo, i opcionalment mòduls de tercers i Server Tools.
<br><br>

## 📋 Funcionalitats principals de l'script:

### 🔢 1️⃣ Recollida de dades:
   - Demana la informació necessària per configurar Odoo i la base de dades: IP estàtica, contrasenyes, correu electrònic, etc.
   - **Genera contrasenyes aleatòries** de 16 caràcters (majúscules, minúscules, números i caràcters especials per a:
     - 🔑 **Master Password**
     - 🔑 **Contrasenya de la base de dades**
     - 🔑 **Contrasenya de l'administrador**   
   - **Nom de la base de dades i de l'usuari generats automàticament** a partir del nom de la instància.
   - Demana l'**idioma** (per defecte: Català) i el **país** (per defecte: Spain).
   - Pregunta si es volen instal·lar dades de mostra (per defecte: "no").

### 🔢 2️⃣ Selecció de mòduls:
   - Permet seleccionar mòduls predeterminats d'Odoo (CRM, Comptabilitat, Inventari, etc.).
   - Ofereix seleccionar **Server Tools** addicionals.

### 🔢 3️⃣ Instal·lació de mòduls i Server Tools:
   - Crea carpetes per cada mòdul seleccionat dins de `/opt/odoo/odoo-server/addons`
   - Crea carpetes per cada mòdul personalitzat dins de `/opt/odoo/odoo-server/custom-addons`
   - Crea carpees per cada mòdul seleccionat de Server Tools dins de `/opt/odoo/odoo-server/server-tools`

### 🔢 4️⃣ Actualització del servidor:
   - Actualitza el sistema:
     `sudo apt update -y && sudo apt upgrade -y`

### 🔢 5️⃣ Instal·lació de dependències:
   - Instal·la llibreries necessàries com Python, Git, Node.js, i Wkhtmltopdf.

### 🔢 6️⃣ Configuració de PostgreSQL:
   - Instal·la PostgreSQL 14 i crea un usuari i base de dades per Odoo.

### 🔢 7️⃣ Creació de l'usuari Odoo:
   - Crea un usuari dedicat per a una millor seguretat.

### 🔢 8️⃣ Configuració del fitxer `odoo.conf`:
   - Configura les rutes, base de dades, contrasenyes i logs a `/etc/odoo.conf`
   - Els **logs** es registren a `/var/log/odoo/odoo-server.log` i el nivell es pot ajustar.

### 🔢 9️⃣ Configuració com a servei:
   - Configura Odoo com un servei del sistema amb `systemd`

### 🔢 🔟 Configuració de Nginx:
   - Instal·la Nginx per redirigir les peticions HTTP a Odoo.
<br><br>

# 🌐 Creació d'una Instància Ubuntu 24.04 a AWS Lightsail amb IP Estàtica i Gestió de Claus SSH
<br>

## 🖥️ Com crear una instància a Lightsail

### 🔢 1️⃣ **Accedeix a la consola de Lightsail:**
   - Inicia sessió al teu compte d'AWS i ves a la consola de **Lightsail**: https://lightsail.aws.amazon.com/
   - Les credencials d'accés són al **keeweb** a **AWS 1**

### 🔢 2️⃣ **Crear una nova instància:**
   - Fes clic a **"Create instance"** per iniciar el procés de creació.
   
### 🔢 3️⃣ **Configuració de l'instància:**

   - **Platform**: Selecciona **Linux/Unix**.
   - **Blueprint**: Tria **Ubuntu** com a sistema operatiu.
     - Assegura't de seleccionar la versió **Ubuntu 24.04 LTS** (o la més recent disponible).
   - **Instància Type**: Tria el pla que s'adapti a les teves necessitats. Per a petites aplicacions o proves, pots començar amb la instància més bàsica.
   - **Nom de l'instància**: Dona un nom descriptiu a la teva instància amb la forma `odoo-<nom del client>`), separant 'odoo' amb guió alt i les paraules del nom del client amb guió baix.
   - Exemples: `odoo-Kook`, `odoo-Human_CTA`, `odoo-proves_importants`

### 🔢 4️⃣ **Configuració d'una IP estàtica:**
   - Després de crear la instància, assignarem una **IP estàtica**.
   - Ves al menú **Networking** dins de Lightsail i selecciona **"Attach Static IP"**.
   - Selecciona la instància creada i assigna-li una **IP estàtica** per evitar canvis en l'adreça IP en reiniciar la instància.
   - Posa el nom a la IP estàtica amb al forma `staticIp-odoo-Human_CTA`, `staticIp-odoo-proves`
<br><br>

## 🔑 Gestió de claus SSH

### Generar les claus SSH locals

### 🔢 1️⃣ **Generar una clau SSH localment (si encara no en tens una):**
   
   - A la terminal del teu ordinador local (Linux, macOS, o Windows amb WSL):
     ```bash
     ssh-keygen -t rsa -b 4096 -C "nom_de_l'usuari@exemple.com"
     ```
   - Això generarà una parella de claus **pública** i **privada**. Per defecte, es guardaran a `~/.ssh/id_rsa` (clau privada) i `~/.ssh/id_rsa.pub` (clau pública).

### 🔢 2️⃣ **Carregar la clau SSH a Lightsail:**
   
   - A la consola de Lightsail, ves a **Account > SSH Keys**.
   - Si no tens una clau ja creada, fes clic a **"Upload new key"** i selecciona el fitxer `.pub` generat al pas anterior (`~/.ssh/id_rsa.pub`).
   
   - A partir d'aquest moment, la teva instància creada utilitzarà aquesta clau SSH per autenticar-se.
<br><br>

## 🛠️ Connectar-te a la instància Odoo via SSH des del terminal:

### 🔢 1️⃣ **Obrir una terminal:**
   - A la terminal del teu ordinador, utilitza el següent comandament per connectar-te a la instància d'Ubuntu:
     ```bash
     ssh -i ./path/a/la/teva/clau_privada.pem ubuntu@<IP_ESTÀTICA>
     ```

   - Substitueix `./path/a/la/teva/clau_privada.pem` pel camí a la teva clau SSH privada generada anteriorment, i substitueix `<IP_ESTÀTICA>` per l'adreça IP estàtica assignada a la teva instància.

### 🔢 2️⃣ **Permisos de la clau privada:**
   - Si trobes un error de permisos amb la clau privada, assegura't que només el propietari pugui llegir-la:
     ```bash
     chmod 400 ./path/a/la/teva/clau_privada.pem
     ```
<br>

## 🛠️ Connexió a la instància Odoo via SSH utilitzant Visual Studio Code:

🔗 **Passos per establir la connexió:**

### 🔢 1️⃣ **Obrir Visual Studio Code**:
   - Instal·la l'extensió "Remote - SSH" des del Marketplace de Visual Studio Code.

### 🔢 2️⃣ **Connectar via SSH**:
   - Executa el següent comando per connectar-te a la teva instància Odoo:
     ```bash
     ssh -i ./path/al/teu/arxiu.pem ubuntu@<IP_INSTÀNCIA>
     ```
   - Assegura't de donar permisos adequats al fitxer `.pem` abans de connectar:
     ```bash
     chmod 400 ./path/al/teu/arxiu.pem
     ```
<br>

## ⬇️ Baixar i executar l'script:

### 🔢 1️⃣ **Baixar l'script amb `wget`**:
   - Per baixar l'script utilitza el següent comandament:
     ```bash
     wget https://raw.githubusercontent.com/it-human/scripts-odoo/main/installacio-odoo_v16-postgres_v14.sh
     ```

### 🔢 2️⃣ **Donar permisos d'execució a l'script**:
   - Després de descarregar l'script, cal donar-li permisos d'execució:
     ```bash
     chmod +x installacio-odoo_v16-postgres_v14.sh
     ```

### 🔢 3️⃣ **Executar l'script**:
   - Executa l'script amb:
     ```bash
     ./installacio-odoo_v16-postgres_v14.sh
     ```
<br>

## 🌐 Accés a l'Odoo creat:

### Configuració de la base de dades:

### 🔢 1️⃣ **Accedir a l'Odoo**:
   - Indroduïu la ruta del vostre odoo:
     ```bash
     www.https://<IP estàtica>:8069
     ```
### 🔢 2️⃣ **Configurar la base de dades d'Odoo**:
   - Omple els camps següents:

   - **Master Password**: La contrasenya de mestre generada automàticament per l'script.
   - **Database Name**: El nom de la base de dades seleccionada (o una de nova, si ho prefereixes).
   - **Email**: El correu electrònic de l'administrador.
   - **Password**: La contrasenya d'administrador generada automàticament.
   - **Phone Number**: Aquest camp és opcional, pots deixar-lo en blanc.
   - **Language**: Selecciona l'idioma en el qual vols utilitzar Odoo.
   - **Country**: El país on es troba la teva empresa o organització.
   - **Demo Data**: Si vols instal·lar dades de prova per fer tests, marca aquesta opció.
<br><br>

## 🌍 Configuració de DNS i subdomini a Siteground:

### 🔢 1️⃣ **Accedir al perfil de Siteground**:
   - Inicia sessió al perfil de **Siteground** de Human CTA.

### 🔢 2️⃣ **Crear un subdomini**:
   - A la secció del teu projecte web, afegeix un nou subdomini corresponent a la URL d'Odoo, com per exemple `intranet.<el teu domini>`

### 🔢 3️⃣ **Configuració dels registres DNS**:
   - Per assegurar que el subdomini apunta correctament a la instància d'Odoo, afegeix un registre DNS tipus **A** que apunti l'IP estàtica de la teva instància d'Odoo al subdomini que has creat.

#### Exemple de configuració DNS:
   - **Tipus de registre**: A
   - **Nom**: `intranet.humancta.org`
   - **Valor**: L'adreça IP pública de la instància Odoo (`15.237.133.55`)

### 🔢 4️⃣ **Esperar la propagació**:
   - Els registres DNS poden trigar fins a 48 hores per propagar-se correctament. Després d'aquest període, hauràs de poder accedir a la teva instància d'Odoo utilitzant el subdomini que has creat.
<br><br>

## 🔐 Recomanacions de seguretat:

És **molt important** guardar totes les credencials generades durant el procés d'instal·lació, com la **Master Password**, la **contrasenya de l'administrador** i altres contrasenyes crítiques. Recomanem utilitzar un gestor de contrasenyes com **Keeweb** o altres eines similars per emmagatzemar de forma segura aquestes credencials.
- **Seguretat de les claus**: Mantingues la teva clau privada segura i mai la comparteixis amb ningú. Utilitza només la clau pública per autenticar-te.
- **Backup de les claus**: Guardeu les claus SSH al **Keeweb** juntament amb al resta de dades sensibles.
- **Actualitzacions de seguretat**: No oblidis executar periòdicament `sudo apt update && sudo apt upgrade` per mantenir el sistema actualitzat.
<br><br>

## 🔗 Exemple d'accés final a Odoo:

Un cop la configuració dels DNS i el subdomini estigui completa, podràs accedir a la teva instància d'Odoo utilitzant el subdomini que has configurat. Per exemple, si has creat el subdomini `intranet.<el teu domini>`, podràs accedir a la instància mitjançant:

```bash
https://intranet.<el teu domini>:8069
```

#!/bin/bash

# Solicitar la red al usuario
read -p "Introduce la red que deseas escanear (ej. 192.168.1.0/24): " NETWORK

# Solicitar el usuario que ejecuta el playbook
read -p "Introduce el usuario que ejectuara los Playbooks Unix: " USER_PLAYBOOK

# Solicitar la contraseña del usuario que ejecuta el script
read -sp "Introduce la contraseña para el usuario $USER_PLAYBOOK: " PASSWORD_PLAYBOOK
echo

# Solicitar puerto SSH para Unix, permitiendo solo números
while true; do
    read -p "Introduce el puerto SSH para los servidores Unix: " SSH_PORT
	
    # Verificar si la entrada contiene solo números
    if [[ "$SSH_PORT" =~ ^[0-9]+$ ]]; then
        break  # Salir del bucle si es un número válido
    else
        echo "Error: Por favor, introduce solo números."
    fi
done


# Archivos de salida
OUTPUT_SCAN="servers_scan.txt"
WINDOWS_HOSTS="windows_hosts"
UNIX_HOSTS="unix_hosts"
ENCRYPTED_UNIX_HOSTS="unix_hosts.gpg"

# 1. Escanear la red y detectar sistemas operativos
echo "Escaneando la red $NETWORK en busca de servidores..."
sudo nmap -O $NETWORK -oG $OUTPUT_SCAN

# 2. Filtrar servidores Windows Server
echo "Filtrando servidores Windows Server..."
awk '/Microsoft Windows Server/{print x}; {x=$2}' $OUTPUT_SCAN > $WINDOWS_HOSTS.tmp

# 3. Filtrar servidores Unix (Linux, BSD, etc.)
echo "Filtrando servidores Unix..."
awk '/Linux|Unix|BSD/{print x}; {x=$2}' $OUTPUT_SCAN > $UNIX_HOSTS.tmp

# 4. Añadir configuraciones específicas para Windows la primera vez
if grep -q "\[windows:vars\]" $WINDOWS_HOSTS; then
    echo "La sección [windows:vars] ya existe en el archivo de hosts de Windows."
else
    echo "Añadiendo configuración para Windows en el archivo $WINDOWS_HOSTS."
    echo "[windows:vars]" >> $WINDOWS_HOSTS
    echo "ansible_connection=winrm" >> $WINDOWS_HOSTS
    echo "ansible_winrm_server_cert_validation=ignore" >> $WINDOWS_HOSTS
    echo "ansible_winrm_port=5986" >> $WINDOWS_HOSTS
    echo "ansible_winrm_transport=kerberos" >> $WINDOWS_HOSTS  # Protocolo Kerberos para autenticación
    echo "" >> $WINDOWS_HOSTS  # Añadir salto de línea después de la sección [windows:vars]
fi

# 5. Asegurarse de que el archivo de hosts de Unix exista antes de usarlo
if [ ! -f "$UNIX_HOSTS" ] && [ ! -f "$ENCRYPTED_UNIX_HOSTS" ]; then
    touch $UNIX_HOSTS  # Crear archivo de hosts de Unix si no existe
    echo "Creado el archivo de hosts de Unix vacío: $UNIX_HOSTS"
fi

# 6. Si el archivo encriptado de Unix existe, solicitar contraseña para desencriptarlo
if [ -f "$ENCRYPTED_UNIX_HOSTS" ]; then
    read -sp "Introduce la contraseña para el archivo encriptado de Unix: " DECRYPT_PASSWORD
    echo
    echo "Desencriptando el archivo $ENCRYPTED_UNIX_HOSTS..."
    gpg --batch --yes --decrypt --passphrase "$DECRYPT_PASSWORD" -o $UNIX_HOSTS $ENCRYPTED_UNIX_HOSTS
    if [ $? -ne 0 ]; then
        echo "Error al desencriptar el archivo $ENCRYPTED_UNIX_HOSTS. Abortando ejecución."
        exit 1
    fi
    echo "El archivo de hosts de Unix ha sido desencriptado."
fi

# 7. Añadir configuraciones de conexión específicas para Unix la primera vez
if grep -q "\[unix:vars\]" $UNIX_HOSTS; then
    echo "La sección [unix:vars] ya existe en el archivo de hosts de Unix."
else
    echo "Añadiendo configuración para Unix en el archivo $UNIX_HOSTS."
    echo "[unix:vars]" >> $UNIX_HOSTS
    echo "ansible_user=$USER_PLAYBOOK" >> $UNIX_HOSTS  # Usar el usuario que ejecuta el script
    echo "ansible_password=$PASSWORD_PLAYBOOK" >> $UNIX_HOSTS  # Usar la contraseña proporcionada
	echo "ansible_connection=ssh" >> $UNIX_HOSTS
	echo "ansible_ssh_port=$SSH_PORT" >> $UNIX_HOSTS
    echo "" >> $UNIX_HOSTS  # Añadir salto de línea después de la sección [unix:vars]
	
fi

# 8. Añadir los nuevos hosts de Windows al archivo windows_hosts, debajo de la sección [windows]
# Primero verificar si los hosts de Windows ya están añadidos
echo "Añadiendo servidores Windows al archivo de hosts..."
if ! grep -q "\[windows\]" $WINDOWS_HOSTS; then
    echo "[windows]" >> $WINDOWS_HOSTS
fi

# Añadir solo los nuevos hosts de Windows, evitando duplicados
while read -r HOST; do
    if ! grep -q "$HOST" $WINDOWS_HOSTS; then
        echo "$HOST" >> $WINDOWS_HOSTS
    fi
done < $WINDOWS_HOSTS.tmp

# 9. Añadir los nuevos hosts de Unix al archivo unix_hosts, debajo de la sección [unix]
echo "Añadiendo servidores Unix al archivo de hosts..."

# Solo añadir la sección [unix] si no existe
if ! grep -q "\[unix\]" $UNIX_HOSTS; then
    echo "[unix]" >> $UNIX_HOSTS
fi

# Añadir solo los nuevos hosts de Unix, evitando duplicados
while read -r HOST; do
    if ! grep -q "$HOST" $UNIX_HOSTS; then
        echo "$HOST" >> $UNIX_HOSTS
    fi
done < $UNIX_HOSTS.tmp

# 10. Eliminar archivos temporales
rm $WINDOWS_HOSTS.tmp $UNIX_HOSTS.tmp

# 11. Verificar que los archivos de hosts de Windows y Unix se hayan creado correctamente
if [ ! -f "$WINDOWS_HOSTS" ]; then
    echo "Error: El archivo de hosts de Windows no se ha creado correctamente."
    exit 1
fi

if [ ! -f "$UNIX_HOSTS" ]; then
    echo "Error: El archivo de hosts de Unix no se ha creado correctamente."
    exit 1
fi

# 12. Encriptar el archivo de Unix para que solo root pueda leerlo
echo "Encriptando el archivo de hosts de Unix..."

# Solicitar la contraseña del archivo encriptado Unix
read -sp "Introduce la contraseña para el fichero host de Unix: " PASSWORD_UNIX_HOST
echo

if [ -f "$UNIX_HOSTS" ]; then
    sudo gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase "$PASSWORD_UNIX_HOST" $UNIX_HOSTS
    sudo chown root:root $ENCRYPTED_UNIX_HOSTS
    sudo chmod 600 $ENCRYPTED_UNIX_HOSTS
	sudo rm $UNIX_HOSTS
else
    echo "Error: El archivo de hosts de Unix no existe. Abortando encriptación."
    exit 1
fi

# 13. Confirmación
echo "El archivo de hosts de Windows ha sido creado o actualizado en: $WINDOWS_HOSTS"
echo "Contenido del archivo de hosts de Windows:"
cat $WINDOWS_HOSTS

echo "El archivo de hosts de Unix ha sido creado o actualizado en: $ENCRYPTED_UNIX_HOSTS"
echo "Contenido del archivo de hosts de Unix (encriptado, no legible):"
echo "(Archivo encriptado, no es legible)"

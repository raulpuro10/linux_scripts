#!/bin/bash

# Solicitar el nombre del fichero de hosts a desencriptar
ls
read -p "Introduce el nombre del fichero host a desencriptar (ej. unix_hosts.gpg): " UNIX_HOSTS

# Verificar si el archivo existe
if [[ ! -f "$UNIX_HOSTS" ]]; then
    echo "Error: El archivo '$UNIX_HOSTS' no existe. Abortando."
    exit 1
fi

# Verificar si el archivo está encriptado con GPG (intentar leer la información)
if gpg --list-packets "$UNIX_HOSTS" &>/dev/null; then
    echo "El archivo '$UNIX_HOSTS' está encriptado con GPG."
else
    echo "Error: El archivo '$UNIX_HOSTS' no está encriptado o no es un archivo GPG válido."
    exit 1
fi


# Solicitar la contraseña para el archivo encriptado
read -sp "Introduce la contraseña para el archivo encriptado de Unix: " DECRYPT_PASSWORD
echo

# Solicitar el nombre del playbook a ejecutar
ls
read -p "Introduce el nombre del playbook de Ansible a ejecutar (ej. playbook.yml): " PLAYBOOK

# Verificar que el playbook existe
if [[ ! -f "$PLAYBOOK" ]]; then
    echo "El archivo de playbook '$PLAYBOOK' no existe. Abortando ejecución."
    exit 1
fi

# Crear un archivo temporal para el inventario desencriptado
TEMP_INVENTORY=$(mktemp)

# Desencriptar el archivo de hosts y guardarlo en el archivo temporal
echo "Desencriptando el archivo de inventario..."
gpg --decrypt --batch --yes --passphrase "$DECRYPT_PASSWORD" $UNIX_HOSTS > "$TEMP_INVENTORY"

# Verificar que el archivo de inventario desencriptado se creó correctamente
if [[ ! -f "$TEMP_INVENTORY" ]]; then
    echo "Error al desencriptar el archivo de inventario. Abortando ejecución."
    exit 1
fi

# Ejecutar el playbook con el inventario desencriptado
ansible-playbook -i "$TEMP_INVENTORY" "$PLAYBOOK"

# Eliminar el archivo temporal de inventario
rm "$TEMP_INVENTORY"

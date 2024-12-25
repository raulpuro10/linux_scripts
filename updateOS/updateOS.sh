#!/bin/bash

# Actualizar los índices de paquetes
echo "Actualizando el índice de paquetes..."
sudo apt update -y

# Actualizar los paquetes instalados
echo "Actualizando los paquetes instalados..."
sudo apt upgrade -y

# Realizar una actualización completa del sistema (instalar nuevos paquetes y eliminar obsoletos)
echo "Realizando una actualización completa del sistema..."
sudo apt dist-upgrade -y

# Eliminar paquetes obsoletos
echo "Eliminando paquetes obsoletos..."
sudo apt autoremove -y

# Aplicar actualizaciones de seguridad automáticas (si está habilitado)
echo "Aplicando actualizaciones de seguridad..."
sudo unattended-upgrades --dry-run
sudo unattended-upgrades

# Comprobar si hay actualizaciones del kernel
echo "Comprobando actualizaciones del kernel..."
sudo apt install linux-generic -y

# Comprobar si hay paquetes adicionales que necesitan actualización
echo "Verificando paquetes adicionales..."
sudo apt full-upgrade -y

# Reiniciar el sistema si se actualiza el kernel
echo "Reiniciando el sistema si es necesario..."
sudo reboot


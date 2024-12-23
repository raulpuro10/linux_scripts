#!/bin/bash

### VARIABLES ###
#Day of the week (0 - 7) (*=every day)
DIA_SEMANA=

#Month (1 - 12) (*=every month)
MES=

#Day of the month (1 - 31) (*=todos los dias del mes)
DIA_MES=

#Hour (0 - 23)
HORA=

#Minute (0 - 59)
MINUTO=

#Script to execute (insert full path)
SCRIPT=


### Instalar cron si no lo esta ###
#!/bin/bash

# Verificar si cron está instalado
if ! command -v cron &> /dev/null; then
    echo "Cron no está instalado. Instalando cron..."
    sudo apt update
    sudo apt install -y cron
    sudo systemctl enable cron
    echo "Cron ha sido instalado y habilitado."
else
    echo "Cron ya está instalado."
fi


### CREAR TAREA PROGRAMADA ###

# Almacena las tareas crontab existentes en una variable
current_cron=$(crontab -l 2>/dev/null)

# Nueva tarea programada
new_task="$MINUTO $HORA $DIA_MES $MES $DIA_SEMANA $SCRIPT" 

# Verifica si la nueva tarea ya existe
if echo "$current_cron" | grep -Fxq "$new_task"; then
    echo "La tarea ya está programada. No se agregará nuevamente."
else
    # Si la tarea no existe, la agregamos al crontab
    echo -e "$current_cron\n$new_task" | crontab -
    echo "Nueva tarea agregada al crontab."
fi

crontab -l

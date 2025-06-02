#!/bin/bash

# Puedes necesitar intalar para dispositivos de audio tipo altavoz:
# sudo apt-get install pulseaudio-module-bluetooth
# pulseaudio --start
# sudo systemctl restart bluetooth
# bluetoothctl paired-devices -> puede dar problemas según la versión de bluetoothctl

# Colores para el menú
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Continue program
press_key ()
{
        echo -e "$NC"
        read -rsp $'Press any key to continue...\n' -n1 key
        # Press any key to continue...
}

# Función para verificar estado del servicio Bluetooth
check_bluetooth_service() {

    if systemctl is-active --quiet bluetooth 2>/dev/null; then
        echo -e "${GREEN}Servicio Bluetooth activado (systemd)${NC}"
        return 0
    fi

    # Método 2: Verificar con rfkill
    local rfkill_state
    rfkill_state=$(rfkill list bluetooth 2>/dev/null | grep -c "Soft blocked: no")
    if [ "$rfkill_state" -gt 0 ]; then
        echo -e "${GREEN}Bluetooth desbloqueado (rfkill)${NC}"
        return 0
    fi

    # Método 3: Verificar con hciconfig
    if hciconfig hci0 2>/dev/null | grep -q "UP"; then
        echo -e "${GREEN}Adaptador Bluetooth activo (hciconfig)${NC}"
        return 0
    fi

    # Método 4: Verificar con bluetoothctl
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        echo -e "${GREEN}Bluetooth encendido (bluetoothctl)${NC}"
        return 0
    fi

    # Todos los métodos fallaron
    echo -e "${RED}Bluetooth está completamente desactivado${NC}"
    return 1
}

# Función para encender/apagar Bluetooth
toggle_bluetooth() {
    if systemctl is-active --quiet bluetooth; then
        sudo systemctl stop bluetooth
        echo -e "${RED}Bluetooth detenido${NC}"
    else
        sudo systemctl start bluetooth
        echo -e "${GREEN}Bluetooth iniciado${NC}"
    fi
    sleep 1  # Dar tiempo al cambio
}

# Función para escanear dispositivos
scan_devices() {
    echo -e "${YELLOW}Iniciando escaneo...${NC}"

    # Resetear el adaptador
    sudo hciconfig hci0 down
    sudo hciconfig hci0 up

    # Limpiar caché de descubrimientos anteriores
    sudo rm /var/lib/bluetooth/*/cache/* 2>/dev/null

    # Iniciar escaneo
    echo -e "${GREEN}Por favor, pon los dispositivos en modo descubrible ahora${NC}"
    sudo timeout 10 bluetoothctl scan on &

    # Contador de progreso
    for i in {1..10}; do
        echo -ne "Tiempo restante: $((10-i))s\r"
        sleep 1
    done
    echo

    # Obtener resultados
    local devices
    devices=$(sudo bluetoothctl devices)

    if [ -z "$devices" ]; then
        echo -e "${RED}No se detectaron dispositivos${NC}"

        # Diagnóstico automático
        echo -e "\n${YELLOW}=== Diagnóstico Bluetooth ===${NC}"
        echo "Estado del adaptador:"
        hciconfig hci0 | grep -E 'UP|DOWN'
        echo "Errores del sistema:"
        dmesg | grep -i blue | tail -n 3
        return 1
    else
        echo -e "${GREEN}Dispositivos detectados:${NC}"
        # Mostrar MAC y nombre completo
        echo "$devices" | sed 's/^Device //'
        return 0
    fi
}

pair_device() {
    # Escanear dispositivos y mostrarlos
    echo -e "${YELLOW}Escaneando dispositivos disponibles...${NC}"
    scan_devices || return 1

    # Obtener lista de dispositivos detectados
    local devices
    devices=$(sudo bluetoothctl devices | sed 's/^Device //')

    if [ -z "$devices" ]; then
        echo -e "${RED}No se encontraron dispositivos para emparejar${NC}"
        return 1
    fi

    # Crear arrays de MACs y nombres
    local macs=()
    local names=()
    local counter=1

    echo -e "${GREEN}Dispositivos detectados:${NC}"
    while IFS= read -r device; do
        mac=$(echo "$device" | awk '{print $1}')
        name=$(echo "$device" | cut -d ' ' -f 2-)

        macs+=("$mac")
        names+=("$name")

        echo -e "${YELLOW}$counter.${NC} $name ($mac)"
        ((counter++))
    done <<< "$devices"

    # Pedir selección
    while true; do
        read -p "Seleccione un dispositivo para emparejar (1-$((${#macs[@]}))): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#macs[@]} ]; then
            selected_index=$((choice-1))
            selected_mac="${macs[$selected_index]}"
            selected_name="${names[$selected_index]}"
            break
        else
            echo -e "${RED}Selección inválida. Intente de nuevo.${NC}"
        fi
    done


    echo -e "${GREEN}Iniciando emparejamiento con $selected_name...${NC}"
    echo -e "${YELLOW}Ejecute estos comandos en otra terminal si se solicita PIN:${NC}"
    echo "sudo bluetoothctl"
    echo "trust $selected_mac"
    echo "pair $selected_mac"
    echo "connect $selected_mac"

    # Iniciar agente para manejar PIN
    sudo bluetoothctl agent on
    sudo bluetoothctl default-agent
    sudo bluetoothctl pair "$selected_mac"

    # ... (verificación igual) ...
}

# Función para listar dispositivos emparejados
list_paired_devices() {
    # Obtener dispositivos emparejados
    local devices
    #devices=$(bluetoothctl paired-devices)
    devices=$(bluetoothctl devices)

    if [ -z "$devices" ]; then
        echo -e "${RED}No hay dispositivos emparejados${NC}"
        return 1
    fi

    # Crear arrays para MACs y nombres
    local macs=()
    local names=()
    local counter=1

    echo -e "${GREEN}Dispositivos emparejados:${NC}"
    while IFS= read -r device; do
        mac=$(echo "$device" | awk '{print $2}')
        name=$(echo "$device" | cut -d ' ' -f 3-)

        macs+=("$mac")
        names+=("$name")

        echo -e "${YELLOW}$counter.${NC} $name ($mac)"
        ((counter++))
    done <<< "$devices"

    # Devolver los arrays por referencia (Bash 4.3+)
    if [ "$1" ]; then
        declare -n __macs=$1
        __macs=("${macs[@]}")
    fi

    if [ "$2" ]; then
        declare -n __names=$2
        __names=("${names[@]}")
    fi

    return 0
}

# Función para seleccionar dispositivo
select_paired_device() {
    # Obtener dispositivos emparejados con bluetoothctl
    local devices
    #devices=$(bluetoothctl paired-devices 2>/dev/null)
    devices=$(bluetoothctl devices 2>/dev/null)

    # Verificar si hay dispositivos
    if [ -z "$devices" ]; then
        echo -e "${RED}No hay dispositivos emparejados${NC}" >&2
        return 1
    fi

    # Crear arrays para almacenar la información
    local macs=()
    local names=()
    local counter=1

    echo -e "${GREEN}Dispositivos emparejados:${NC}" >&2

    # Procesar cada línea de dispositivos
    while IFS= read -r device; do
        # Extraer MAC (segundo campo)
        mac=$(echo "$device" | awk '{print $2}')
        # Extraer nombre (todos los campos después del segundo)
        name=$(echo "$device" | cut -d ' ' -f 3-)

        # Almacenar en arrays
        macs+=("$mac")
        names+=("$name")

        # Mostrar dispositivo numerado
        echo -e "${YELLOW}$counter.${NC} $name ($mac)" >&2
        ((counter++))
    done <<< "$devices"

    # Pedir selección al usuario
    while true; do
        read -p "Seleccione un dispositivo (1-$((${#macs[@]}))): " choice

        # Validar entrada
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#macs[@]} ]; then
            selected_index=$((choice-1))
            echo "${macs[$selected_index]}"  # Devolver la MAC seleccionada
            return 0
        else
            echo -e "${RED}Selección inválida. Intente de nuevo.${NC}" >&2
        fi
    done
}

# Función para conectar/desconectar
manage_connection() {
    # Obtener MAC del dispositivo seleccionado
    local mac
    mac=$(select_paired_device) 

    # Si no se seleccionó nada, salir
    if [ -z "$mac" ]; then
        return 1
    fi

    # Mostrar menú de acciones
    echo -e "\n${YELLOW}Operaciones para ${GREEN}$mac${NC}"
    echo "1. Conectar"
    echo "2. Desconectar"
    echo "3. Volver al menú principal"
    read -p "Opción: " action

    case $action in
        1) 
            echo -e "${GREEN}Conectando a $mac...${NC}"
            if sudo bluetoothctl connect "$mac"; then
                echo -e "${GREEN}¡Conectado con éxito!${NC}"
            else
                echo -e "${RED}Error al conectar${NC}"
            fi
            ;;
        2) 
            echo -e "${RED}Desconectando de $mac...${NC}"
            if sudo bluetoothctl disconnect "$mac"; then
                echo -e "${GREEN}¡Desconectado con éxito!${NC}"
            else
                echo -e "${RED}Error al desconectar${NC}"
            fi
            ;;
        3)
            return
            ;;
        *) 
            echo -e "${RED}Opción inválida${NC}"
            ;;
    esac

    # Pequeña pausa para que el usuario vea el resultado
    sleep 2
}

# Función para eliminar dispositivo
remove_device() {
    echo -e "${YELLOW}Seleccione un dispositivo a eliminar:${NC}"
    local mac
    mac=$(select_paired_device) || return

    echo -e "${RED}Eliminando dispositivo $mac...${NC}"
    bluetoothctl remove "$mac"
}

# Función para información del adaptador
adapter_info() {
    echo -e "${YELLOW}Información del adaptador:${NC}"
    hciconfig -a | grep -E 'Name|BD Address|UP|DOWN'
    echo -e "\n${YELLOW}Dirección MAC:${NC} $(hcitool dev | awk '/hci0/{print $2}')"
}

# Menú principal
while true; do

    clear
    echo -e "\n${GREEN}*** Bluetooth Manager ***${NC}"
    check_bluetooth_service
    echo "1. Encender/Apagar Bluetooth"
    echo "2. Escanear dispositivos cercanos"
    echo "3. Emparejar nuevo dispositivo"
    echo "4. Listar dispositivos emparejados"
    echo "5. Conectar/Desconectar dispositivo"
    echo "6. Información del adaptador"
    echo -e "7. Eliminar dispositivo emparejado$GREEN"
    echo -e "0. Salir$NC"
    read -p "Selecciona una opción: " option

    case $option in

        1)
            toggle_bluetooth
            press_key
            ;;

        2)
            scan_devices
            press_key
            ;;

        3)
            pair_device
            press_key
            ;;

        4)
            list_paired_devices
            press_key
            ;;

        5)
            manage_connection
            press_key
            ;;

        6)
            adapter_info
            press_key
            ;;

        7)
            remove_device
            press_key
            ;;

        0)
            clear
            exit 0 
            ;;
        *)
            echo -e "${RED}Opción no válida${NC}"
            ;;
    esac
done
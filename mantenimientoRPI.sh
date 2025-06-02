#!/bin/bash
  
# 0-> Reset/Normal; 1-> Bold; 2-> Faint; 3-> Italics; 4-> Underline
RED="\e[0;31m"          # Red
GREEN="\e[0;32m"        # Green
BGREEN="\e[1;32m"       # Green BOLD
ORANGE="\e[0;33m"       # Yellow
BLUE="\e[0;34m"         # BLUE
PURPLE="\e[0;35m"       # MAGENTA
OTHER="\e[0;92m"        # CYAN
NC="\e[0m"              # No Color
VARHOST=$HOSTNAME
clear

# Read system temperature
read_temperature () {
        TEMP_FILE=/sys/class/thermal/thermal_zone0/temp
        ORIGINAL_TEMP=$(cat $TEMP_FILE)
        TEMP_C=$((ORIGINAL_TEMP/1000))
        TEMP_F=$(($TEMP_C * 9/5 + 32))
        echo -e "$TEMP_C"
        #return $TEMP_C
}

# Get computer info
cpu_info () 
{
        CPU_INFO=`cat /proc/cpuinfo | grep -i "^model name" | cut -d ":" -f2 | sed -n '1p'`
        echo -e "$CPU_INFO"
}

# Continue program
press_key ()
{
        echo -e "$NC"
        read -rsp $'Press any key to continue...\n' -n1 key
        # Press any key to continue...
}

Instalar_Postfix()
{
        # Update system
        printf "\n\t${BLUE}*Instalando servidor Postfix*"

        # Get data user
        printf "\nCreando archivo de configuracion ssmtp.conf...${RED}\'e\' para salir${NC}\n"

        IS_DATA_OK=false
        while :; do
            read -p "Ingrese su email (ejemplo@gmail.com): " DIRECCION

            if [ -z "$DIRECCION" ]; then
                printf "${RED}Error: ${NC}El email no puede estar vacío\n"
            elif [ "$DIRECCION" = "e" ]; then
                echo -e "Volviendo al menu"
                IS_DATA_OK=false
                break
            else 
                printf "${GREEN}Email registrado\n${NC}"
                IS_DATA_OK=true
                break
            fi
        done

        if ! $IS_DATA_OK; then
                return
        fi

        while :; do
                read -p "Ingrese nombre del host: " HOSTS

                if [ -z "$HOSTS" ]; then
                        printf "${RED}Error: ${NC}El hostname no puede estar vacío\n"
                elif [ "$HOSTS" = "e" ]; then
                        echo -e "Volviendo al menu"
                        IS_DATA_OK=false
                        break
                else 
                        printf "${GREEN}Hosname registrado\n${NC}"
                        IS_DATA_OK=true
                        break
                fi
        done

        if ! $IS_DATA_OK; then
                return
        fi

        while :; do
                read -p "Ingrese password: " POSTFIXPASS

                if [ -z "$POSTFIXPASS" ]; then
                        printf "${RED}Error: ${NC}El email no puede estar vacío\n"
                elif [ "$POSTFIXPASS" = "e" ]; then
                        echo -e "Volviendo al menu"
                        IS_DATA_OK=false
                        break
                else 
                        printf "${GREEN}Password registrado\n${NC}"
                        IS_DATA_OK=true
                        break
                fi
        done
        if ! $IS_DATA_OK; then
                return
        else
                printf "$BLUE\nActualizando sistema...\n"
                #sudo apt update
                
                # Install PostFix
                printf "Instalando Postfix...\n"
                # sudo apt install postfix mailutils libsasl2-2 ca-certificates libsasl2-modules
                # sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
                
                # Install ssmtp
                printf "Instalando ssmtp...${NC}\n"
                # sudo apt install ssmtp
                printf "${GREEN}Creando copia de seguridad ssmtp.conf...\n"
                # cp  /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.bak
                # rm /etc/ssmtp/ssmtp.conf


                # Create ssmtp config file
                echo "
                        root=$DIRECCION
                        mailhub=smtp.gmail.com:587
                        hostname=$HOSTS
                        AuthUser=$DIRECCION
                        AuthPass=$POSTFIXPASS
                        UseSTARTTLS=Yes
                        UseTLS=Yes
                        " > /etc/ssmtp/ssmtp.conf

                printf "Reiniciando el servicio ssmtp...\n"
                # sudo service smtp restart

                echo -e "$BLUE\nDirección de correo:$GREEN $DIRECCION $BLUE\nHost:$GREEN $HOSTS\n"
                echo -e "El correo ha sido configurado" | mail -s "Confirmacion servidor ssmtp" $DIRECCION #carlosdy3d@gmail.com
                if [ "$(echo $?)" == "1" ]; then
                        echo -e "$RED Error al ejecutar comando mail, revisa /etc/ssmtp/ssmtp.conf$NC"
                fi

                printf "$BLUE\t*** Fin de la instalacion de Postfix ***\n${NC}"
        fi
}

comprobar_dhcpcd ()
{ 
        clear
        echo -e "$OTHER \n*** Comprobando instalación de dhpcd ***"
        test -f /usr/sbin/dhcpcd
        # echo $? muestra si el comando anterior se ejecuto correctamente
        # si es valor 0 todo se ejecuto correctamente
        test_dhcpcd=$(echo $?)

        if test $test_dhcpcd == "0"; then
                echo -e "$OTHER\ndhcpd esta instalado!!!\n$NC"
                dhcpd_config=""
                while [[ $dhcpd_config != "y" ]];
                do
                        read -p "Configurar dhcpcd? y/n  " dhcpd_config
                        if [[ $dhcpd_config == "n" ]]; then
                                echo -e "$RED\nNo se configura dhcpcd\n$NC"
                                return
                        fi
                done

                if [[ $dhcpd_config == "y" ]]; then
                        echo -e "$OTHER\nConfigurando dhcpd$NC"
                        configurar_dhcpcd
                        return
                fi 
        else
                echo -e "$RED\ndhcpd no esta instalado\n$NC"
                dhcpd_install="q"
                while [[ $dhcpd_install != "y" ]];
                do
                        read -p "Instalar dhcpd? y/n " dhcpd_install
                        if [[ $dhcpd_install == "n" ]]; then
                                echo -e "$RED\nNo se instalo dhcpd\n$NC"
                                return
                        fi
                done

                if [[ $dhcpd_install == "y" ]]; then
                        echo -e "$OTHER\nInstalando dhcpd\n$NC"
                        sudo apt install dhcpcd -y
                        if [ "$(echo $?)" == "0" ]; then
                                comprobar_dhcpcd
                        fi
                fi
        fi
}

configurar_dhcpcd () 
{
        read -p "Introduce la ip (e: salir): " IP
        if [ "$IP" = "e" ]; then
                echo -e "Volviendo al menu"
                return
        else
                # Valida si la IP es correcta
                if validar_ip "$IP"; then
                        echo -e "$GREEN\nIP válida - procediendo...$NC"
                else
                        echo -e "$RED\nError: IP no válida$NC" >&2
                        configurar_dhcpcd
                fi
                check_interfaces
        fi

        # Hace una copia de seguridad del archivo /etc/dhcpcd.conf
        echo -e "$GREEN\nHaciendo copia de seguridad de /etc/dhcpcd.conf...\n$NC"
        #cp /etc/dhcpcd.conf /etc/dhcpcd.conf.old

        # Añade las lineas de configuración en el archivo /etc/dhcpcd.conf
        echo -e "$OTHER\nAñadiendo lineas de configuración al archivo dhcpcd.conf$NC"
        echo -e "\n# Static ip Address:\
                        \nstatic ip_address=$IP/24\
                        \ninterface $INTERFACE\
                        \nstatic_routers=192.168.1.1\
                        \nstatic domain_name_servers=8.8.8.8 8.8.4.4\
                " > /home/peyutron/Scripts/Raspberry/aa.txt #/etc/dhcpcd.conf
        # cat /etc/dhcpcd.conf
        cat /home/peyutron/Scripts/Raspberry/aa.txt
        #echo -e "\n# Static ip Address:\
        #                \nstatic ip_address=192.168.1.51/24\
        #                \ninterface eth0\
        #                \nstatic_routers=192.168.1.1\
        #                \nstatic domain_name_servers=8.8.8.8 8.8.4.4\
        #        " >> /etc/dhcpcd.conf
}

function check_interfaces () 
{

        echo -e "$OTHER \n*** Interfaces de Red Disponibles ***\n$NC" >&2

        interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v lo))

        for i in "${!interfaces[@]}"; do
                estado=$(ip link show ${interfaces[$i]} | grep -oP '(?<=state\s)\w+')
                echo "$((i+1)). ${interfaces[$i]} (Estado: $estado)" >&2
        done
        # Seleccionar interfaz
        read -p "Selecciona el número de la interfaz: " num

        if [[ ! "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#interfaces[@]}" ]; then
                echo -e "$RED Error: Selección no valida$NC"

        else
                INTERFACE="${interfaces[$((num-1))]}"
                echo -e "$OTHER"
                echo -e "Interfaz seleccionada: $INTERFACE$NC" >&2
        fi
}

validar_ip () 
{
    local ip="$1"
    local stat=1

    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra octetos <<< "$ip"
        for oct in "${octetos[@]}"; do
            [[ "$oct" -le 255 ]] || return 1
        done
        stat=0
    fi

    return "$stat"
}

stress_test(){
        # sudo stress --cpu 4 -t 300 &
while : 
        do
        echo "$(date) @ $(hostname)"
        echo "-----------------------------"
        cpu=$(</sys/class/thermal/thermal_zone0/temp) 
        echo "GPU=> $(vcgencmd measure_temp)"
        echo "CPU=> $((cpu/1000))'C"
        echo "${ORANGE}Test de stress nuevo ciclo$NC" 
        sudo stress --cpu 4 --io 20 --vm 6 --vm-bytes 25M --timeout 30s 
        cpu=$(</sys/class/thermal/thermal_zone0/temp) 
        echo "------------------------------"
        echo "GPU => $(vcgencmd measure_temp)"
        echo "CPU => $((cpu/1000))'C"
        echo -e "$GREEN\nFin de la medicion$NC"
        sleep 3
        read -t 0.1 -n 1 key
        if [[ $key == "q" ]]; then
                echo -e "\nSaliendo del bucle"
                return
        fi
done
    
}

# Menu start
#while [ "$yn" != "exit" ]; do
while true; do
        echo -e "\nHostname:$ORANG $VARHOST $NC"
        echo -e "System temperature: $(read_temperature) ºC"
        echo "CPU model: $(cpu_info)"
        echo -e "$GREEN"
        echo -e " 1) Server - Información neofetch"
        echo -e " 2) Server - Volcar pagina desde zip (harold)"
        echo -e " 3) Server - Recargar Dondom (harold)"
        echo -e " 4) Server - Borrar logs apache2"
        echo -e " 5) Server - Quien esta conectado al servidor?"
        echo -e " 6) Server - Ultimas conexiones$ORANGE"
        echo -e " 7) System - Iniciar rkhunter"
        echo -e " 8) System - Mantenimiento - Iniciar lynis"
        echo -e " 9) System - Mostrar pines GPIO RPI"
        echo -e "10) System - Espacio libre en la SD \(Raspberry\)"
        echo -e "11) System - Mostrar archivos mayores de 50MB"
        echo -e "12) System - Test de stress$BLUE"
        echo -e "13) Software - Actualizar el sistema (-y)"
        echo -e "14) Software - Versión de programas"
        echo -e "15) Software - Programas instalados"
        echo -e "16) Software - Procesos con mayores consumo$OTHER"
        echo -e "17) Network - Estado de mi red"
        echo -e "18) Network - Cambiar dirección de red"
        echo -e "19) Network - Escaneo de puertos nmap"
        echo -e "20) Network - Mostrar equipos conectados en rago de servidor"
        echo -e "21) Network - Mostrar carpetas compartidas$PURPLE"
        echo -e "22) Bluetooth - Bluetooth Manager2$GREEN"

        echo -e "0) Salir (exit)"
        echo -e "$RED\nRecuerda que algunas opciones necesitan sudo$NC "
        echo -e "$NC"

        read -p 'Selecciona una opción: ' case;
        case $case in

                22)     ##Bluetooth_manager.sh
                        clear
                        echo -e "\n* Bluetooth_manager *"
                        sudo ./bluetooth_manager.sh
                        #press_key
                        #clear
                        ;;

                1)      # Neofetch
                        clear
                        echo -e " Neofetch"
                        neofetch
                        press_key
                        ;;
 
                2)      # Volcado de blog
                        echo -e "\* n Vocado de blog desde archivo zip *"
                        unzip /home/user/Archivo.zip
                        # Elimina la carpeta de manera recursiva
                        sudo rm -R /home/user/directorio
                        # Mueve la carpeta a su destino final
                        sudo mv -v directorio /home/user/directorio
                        ;;
 
                3)      # Recarga dominio
                        echo -e "Recargando el dominio..."
                        ./file.sh
                        echo -e "\n"
                        ;;
 
                4)      # Delete Apache2 Logs
                        echo -e "$GREENBorrando logs de Apache2$NC "
                        echo
                        sudo rm -R /var/log/apache2
                        sudo mkdir /var/log/apache2
                        echo
                        echo -e "\nReiniciando servicios..."
                        sudo /etc/init.d/apache2 start
                        echo
                        echo -e "\nEstado del servidor:"
                        sudo /etc/init.d/apache2 status
                      	;;
 
                5)      # Clientes conectados
                        echo -e "Clientes conectados  al servidor...\n"
                        sudo who
                        echo -e "\n"
                        press_key
                        ;;      

                6)      # Últimas conexiones
                         echo -e "Ultimas conexiones al servidor.."
                         last | tail
                         press_key
                         ;;
                
                7)      # Rkhunter
                        echo " Iniciando rkhunter...."
                        sudo rkhunter --check
                        # sudo rkhunter --update -propupd # Si está recien instalado 
                        # hay que cambiar la linea WEB_CMD="/bin/false" a WEB_CMD=""
                        # en el archivo /etc/rkhunter.conf
                        ;;
 
                8)      # Lynis
                        echo "Lynis optimización del sistema"
                        sudo lynis audit system
                        ;;
 
                9)      # RPI Pinout
                        pinout
                        echo -e "$GREEN Mostrando pines de entrada/salida de para Raspberry Pi$NC"
                        press_key
                        ;;
 
                10)     # Espacio libre en disco
                        echo -e "$ORANGE\nMostrando espacio libre en disco...$GREEN"
                        df -h 
                        echo -e "$NC"
                        press_key
                        clear
                        ;;

                11)     # Archivos mayores de 50MB
                        echo -e "$ORANGE\nMostrando archivos +50MB\n$GREEN"
                        find . -type f -size +50M -ls 
                        echo -e "$NC"
                        press_key
                        ;;

                12)     # Test de estress para cpu 
                        # sudo apt install stress
                        echo -e "$ORANGE\nIniciando test de Stress$NC"
                        stress_test
                        press_key
                        clear
                        ;;

                13)     # Actualiza el sistema (-y)
                        echo -e "$GREEN\n* Actualizando el equipo *$NC"
                        sudo apt update && sudo apt upgrade -y
                        echo -e "$RED\nSistema actualizado $NC"
                        ;;

                14)     # Muestra version de programas instalados
                        clear
                        echo -e "$BLUE"
                        apache2 -version
                        echo -e "$NC"
                        ;;

                15)     # Programas instalados
                        # dpkg -l
                        # dpkg -l | grep -v -E "lib* | ubuntu | modules | server"
                        clear
                        while [ "$yn" != "exit" ]; do
                                echo -e "$BLUE"
                                echo -e "1) Instalar Shell Fish"
                                echo -e "2) Instalar compartir archivos Samba"
                                echo -e "3) Instalar administrador de archivos Ranger"
                                echo -e "4) Monitor de sistema btop"
                                echo -e "5) Monitor de tráfico Iptraf"
                                echo -e "6) Navegador de terminal w3m"
                                echo -e "7) Instalar nmap"
                                echo -e "8) Servicio de correo Postfix (Gmail)$GREEN"
                                echo -e "0) Volver al menu principal"
                                echo -e "$NC"
                                read -p 'Selecciona un programa: ' selection;
                                
                                case $selection in
                                        7)      
                                                test -f /usr/bin/postfix
                                                # comprueba que la salida del ultimo test es 0 (ok)
                                                if [ "$(echo $?)" == "0" ]; then
                                                        echo -e "$GREEN"        
                                                        echo -e "postfix ya esta instalado en el sistema :) $NC"
                                                else
                                                        #echo "No se encuentra en el sistema, instalando"
                                                        #sudo apt updade > /dev/null && sudo apt install postfix -y > /dev/null
                                                        Instalar_Postfix
                                                fi
                                                press_key
                                                clear
                                                ;; 
                                        7)      
                                                echo -e "$BLUE\t** Instalando Nmap **$NC"
                                                test -f /usr/bin/nmap
                                                # comprueba que la salida del ultimo test es 0 (ok)
                                                if [ "$(echo $?)" == "0" ]; then
                                                        echo -e "$GREEN"
                                                        echo -e "Nmap ya esta instalado en el sistema :) $NC"
                                                else
                                                        sudo apt install nmap -y > /dev/null
                                                fi
                                                press_key
                                                clear
                                                ;;    
                                        6)      echo -e "$BLUE\t** Instalando w3m **$NC"
                                                test -f /usr/bin/w3m
                                                # comprueba que la salida del ultimo test es 0 (ok)
                                                if [ "$(echo $?)" == "0" ]; then
                                                        echo -e "$GREEN"
                                                        echo -e "w3m ya esta instalado en el sistema :) $NC"
                                                else
                                                        sudo apt install w3m -y 
                                                fi
                                                press_key
                                                clear
                                                ;;

                                        4)      echo -e "$BLUE\t** Instalando btop **$NC"
                                                test -f /usr/bin/btop
                                                # comprueba que la salida del ultimo test es 0 (ok)
                                                if [ "$(echo $?)" == "0" ]; then
                                                        echo -e "$GREEN"
                                                        echo -e "Btop ya esta instalado en el sistema :) $NC"
                                                else
                                                        sudo apt install btop -y 
                                                fi
                                                press_key
                                                clear
                                                ;;

                                        3)      echo -e "$BLUE\n** Instalando Ranger ** $NC"
                                                test -f /usr/bin/ranger
                                                # comprueba que la salida del ultimo test es 0 (ok)
                                                if [ "$(echo $?)" == "0" ]; then
                                                        echo -e "$GREEN"
                                                        echo -e "ranger ya esta instalado en el sistema :) $NC "
                                                else
                                                        sudo apt install ranger -y
                                                fi
                                                press_key
                                                clear
                                                ;;

                                        2)      echo -e "$BLUE\n** Instalando Samba ** $NC"
                                                test -f /usr/bin/samba-tool
                                                # comprueba que la salida del ultimo test es 0 (ok)
                                                if [ "$(echo $?)" == "0" ]; then
                                                        echo -e "$GREEN"
                                                        echo "Samba ya esta instalado en el sistema :)$NC"
                                                else
                                                        sudo apt install samba -y
                                                fi
                                                press_key
                                                clear
                                                ;;

                                        1)      echo -e "$BLUE\n** Instalando Fish ** $NC"
                                                sudo apt install fish -y
                                                chsh -s /usr/bin/fish
                                                press_key
                                                clear
                                                ;;

                                        0)      clear
                                                break;
                                                ;;

                                esac
                                done

                        ;;

                16)     # Procesos que más consumen
                        echo -e "$GREEN\n* Procesos que más consumen *\n"
                        top -b | head -3
                        echo -e "$BLUE\nProcesos:\n"
                        top -b | head -10 | tail -4
                        echo -e "$NC\n"
                        press_key
                        ;;

                17)     # Check network information

                        check_interfaces
                        # Obtener información de red
                        echo -e "\n\033[1;34m * Información para $INTERFACE * $NC"

                        # IP y MAC
                        ip_addr=$(ip -4 addr show $INTERFACE 2>/dev/null | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+')
                        mac_addr=$(ip link show $INTERFACE 2>/dev/null | grep -oP '(?<=link/ether\s)\K[0-9a-fA-F:]+')

                        # Gateway y DNS
                        gateway=$(ip route | grep default | grep $INTERFACE | awk '{print $3}')
                        dns_servers=$(grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}')

                        # Mostrar resultados con formato
                        echo -e "IP:\t \033[1;32m${ip_addr:-No asignada}\033[0m"
                        echo -e "MAC:\t \033[1;33m${mac_addr:-No disponible}\033[0m"
                        echo -e "Gateway:\t \033[1;34m${gateway:-No configurado}\033[0m"
                        echo -e "DNS:\t \033[1;35m${dns_servers:-No configurado}\033[0m"

                        # Información adicional
                        # echo -e "\n\033[1;36mDetalles adicionales:\033[0m"
                        # ip addr show $INTERFACE | grep -E 'inet|ether'
                        # ip link show $INTERFACE | grep 'state'

                        press_key
                        clear
                        ;;

                18)     # Cambia la dirección IP del dispositivo
                        comprobar_dhcpcd
                        press_key
                        clear
                        ;;
                         
                19)     # Escaneo de puertos en el servidor
                        echo -e " * Escaneo de puertos,$RED tarda casi 1 minuto * $NC"
                        ip=192.168.0.X
                        sudo nmap  -sT -O localhost
                        echo -e "$RED\nEscaneo de puertos finalizado$NC\n"
                        press_key
                        ;;

                20)     # Equipos conectados en rango servidor
                        clear
                        n=0
                        echo -e "\n$OTHER\n* Mostrando equipos conectados *\n"
                        for i in {50..60}; do
                                timeout 0.5 bash -c "ping -c 1 192.168.0.$i" >/dev/null 2>&1
                                if [ $? -eq 0 ]; then
                                        echo -e "$GREEN Equipo encontrado en ip  192.168.0.$i"
                                        n=$(($n+1))
                                        fi
                         done
                         echo -e "\nEquipos conectados en rango de servidor: $n\n"
                         press_key
                         ;;
               
                21)     
                        clear
                        echo -e "\033[1;36m* Carpetas Compartidas (Samba) *\033[0m"

                        # Extraer nombre del share y ruta con formato
                        sudo grep -E '^\s*\[.*\]|^\s*path\s*=' /etc/samba/smb.conf | \
                        grep -vE 'global|print' | \
                        awk '
                            BEGIN { FS="="; OFS="\t"; print "Share\tRuta Local" }
                            /^\[/ { gsub(/[\[\]]/, ""); share=$0 }
                            /path/ { gsub(/[ \t]+/, "", $2); print share, $2 }
                        '

                        echo -e "\n\033[1;33mNota:\033[0m Las rutas son locales en el servidor Samba."
                                press_key
                                clear
                        ;;

                0)      # Salir del programa
                        exit 1
                        ;;

                *)      
                        echo -e "${RED}\nOpción no válida (0-21)${NC}" 
                        ;;
        esac
        done











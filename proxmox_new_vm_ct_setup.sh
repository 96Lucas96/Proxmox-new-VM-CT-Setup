#!/usr/bin/env bash
set -euo pipefail

APP_NAME="New VM/CT Setup Script"

variable_reset() {

USER_CHOICE=""
USERNAME=""
USER_PASS=""
USER_PASS_STATUS=""
SUDO_ANSWER=""
SHELL_CHOICE=""
ENABLE_SSH=""
ENABLE_AUTHKEY=""
SSH_KEY=""
SSH_KEY_STATUS=""
SSH_PORT=""
PASSWORD_AUTH=""
ROOT_LOGIN=""
SSH_PORT_VALID=""
STATUS=""
NTFY_CHOICE=""
NTFY_DOMAIN=""
NTFY_TOPIC=""

}

#Prerequisites

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Your are not root, please switch to the root user and re-run script"
        exit 1
    fi
}


fix_network() {
    IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
    IFACE=${IFACE%@*}

    if [[ -z "$IFACE" ]]; then
        whiptail --msgbox "No network interface found." 10 50
        return 1
    fi

    ip link set "$IFACE" up

    if command -v dhclient >/dev/null 2>&1; then
        dhclient "$IFACE"
    elif command -v dhcpcd >/dev/null 2>&1; then
        dhcpcd "$IFACE"
    fi
}


install_whiptail() {
    if  ! command -v whiptail >/dev/null 2>&1; then
        apt update -y
        apt install whiptail -y
    fi
}

#Main Menu

main_menu() {
    while true; do

        if MENU_CHOICE=$(whiptail --title "$APP_NAME" --menu " \n\n\n     This script is for setting up a new VM or CT \n\n\n\n" 20 60 4 \
        "1." "Run the script" \
        "2." "Exit" \
        3>&1 1>&2 2>&3); then

            STATUS="0"
                else
                    STATUS="$?"
        fi

            case "$STATUS" in

               0)

                case "$MENU_CHOICE" in

                    1.) variable_reset
                        setup_questions
                        ;;

                    2.) exit_question
                        ;;

                esac
                ;;

               *) exit_question
                  ;;

            esac
    done
}


#Setup Trigger

setup_questions() {
    add_user
    add_user_pass
    add_to_sudo
    change_shell
    enable_ssh
    edit_ssh
    ntfy
    hide_sensitive
    overview
}


#Setup Questions

exit_question() {
     if whiptail --title "$APP_NAME" --yesno "\n        Are you sure you want to exit?" 10 50; then
        exit 0
            else
                return 0
     fi
}

add_user() {
    while true; do
        if whiptail --title "$APP_NAME" --yesno "\n               Add a new user?" 10 50; then
            STATUS="0"
                else
                    STATUS="$?"
        fi

        case "$STATUS" in

            0) USER_CHOICE="Yes"
               break
               ;;

            1) USER_CHOICE="No"
               return 0
               ;;

            *) exit_question
               ;;

        esac

    done


    while true; do
         if USERNAME=$(whiptail --title "$APP_NAME" --inputbox "\nUsername:" 10 50 3>&1 1>&2 2>&3); then
             STATUS="0"
                 else
                     STATUS="$?"
         fi

         case "$STATUS" in

          0) if [[ -z "$USERNAME" ]]; then
                 whiptail --msgbox "\n You haven't entered anything, please enter a\n                   username" 10 50
                 continue
             fi

             if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                 whiptail --msgbox "\n     Username contains invalid characters" 10 50
                 continue
             fi

             if id "$USERNAME" &>/dev/null; then
                 whiptail --msgbox "\n           Username already exists" 10 50
                 continue
             fi

             if [[ -n "$USERNAME" ]]; then
                 return 0
             fi
             ;;

          *) exit_question
             ;;
        esac
    done
}


add_user_pass() {

    if [[ -z "$USERNAME" ]]; then
       return 0
    fi

    while true; do

        if USER_PASS=$(whiptail --title "$APP_NAME" --passwordbox "\nUser Password:" 10 50 3>&1 1>&2 2>&3); then
            STATUS="0"
                else
                    STATUS="$?"
        fi

        case "$STATUS" in

            0) if [[ -z "$USER_PASS" ]]; then

                   whiptail --msgbox "\n You haven't entered anything, please enter a\n                user password" 10 50
                   continue
                       else
                           break
               fi
               ;;


           *) exit_question
              ;;

       esac

    done

}

add_to_sudo() {

    if [[ -z "$USERNAME" ]]; then
       return 0
    fi

    while true; do

        if whiptail --title "$APP_NAME" --yesno "\n         Add user to the sudo group?" 10 50; then
            STATUS="0"
                else
                    STATUS="$?"
        fi

            case "$STATUS" in

                0) SUDO_ANSWER="Yes"
                   return 0
                   ;;

                1) SUDO_ANSWER="No"
                   return 0
                   ;;

                *) exit_question
                   ;;

            esac
    done
}


change_shell() {
    if [[ -z "$USERNAME" ]]; then
        return 0

    fi

  while true; do

    if SHELL_CHOICE=$(whiptail --title "$APP_NAME" --menu "\n\n\n                 Select a shell to use: \n\n\n\n" 20 60 4 \
    "1." "Sh" \
    "2." "Bash" \
    "3." "Zsh" \
    "4." "Fish"  \
    3>&1 1>&2 2>&3); then

        STATUS="0"
            else
                STATUS="$?"
    fi

        case "$STATUS" in

          0)

            case "$SHELL_CHOICE" in

                1.) SHELL_CHOICE="sh"
                    ;;

                2.) SHELL_CHOICE="bash"
                    ;;

                3.) SHELL_CHOICE="zsh"
                    ;;

                4.) SHELL_CHOICE="fish"
                    ;;
            esac
            return 0
            ;;

         *) exit_question
            ;;

       esac

  done

}

enable_ssh() {

while true; do

    if whiptail --title "$APP_NAME" --yesno "\n         Would you like to enable SSH?"  10 50; then
        STATUS="0"
            else
                STATUS="$?"
    fi

        case "$STATUS" in

           0) ENABLE_SSH="Yes"
              break
              ;;

           1) ENABLE_SSH="No"
              return 0
              ;;

           *) exit_question
              ;;
        esac
done


while true; do

    if whiptail --title "$APP_NAME" --yesno "\n     Would you like to access SSH with an\n              authorization key?" 10 50; then
        STATUS="0"
            else
                STATUS="$?"
    fi

    case "$STATUS" in

     0) ENABLE_AUTHKEY="Yes"
        break
        ;;

     1) ENABLE_AUTHKEY="No"
        return 0
        ;;


     *) exit_question
        ;;
   esac
done

while true; do

     if SSH_KEY=$(whiptail --title "$APP_NAME" --inputbox "\nPublic Key:" 10 50 3>&1 1>&2 2>&3); then
         STATUS="0"
             else
                 STATUS="$?"
     fi

         case "$STATUS" in

             0) if [[ -z "$SSH_KEY" ]]; then
                    whiptail --msgbox "\nYou haven't entered anything, please enter an\n                   SSH key" 10 50
                    continue
                fi

                if [[ -n "$SSH_KEY" ]]; then
                    break
                fi
                ;;

            *) exit_question
               ;;

         esac
done

}

edit_ssh() {

while true; do

     if [[ -z "$SSH_KEY" ]]; then
         break
     fi

     if whiptail --title "$APP_NAME" --yesno "\n   Would you like to disable SSH password\n               authentication" 10 50; then

         STATUS="0"
           else
              STATUS="$?"
     fi

     case "$STATUS" in

         0) PASSWORD_AUTH="Yes"
            break
            ;;

         1) PASSWORD_AUTH="No"
            break
            ;;

         *) exit_question
            ;;
     esac

done

while true; do

    if [[ "$ENABLE_SSH" == "No" ]]; then
        return 0
    fi

    if [[ "$USER_CHOICE" == "No" ]]; then
        break
    fi

         if whiptail --title "$APP_NAME" --yesno "\n   Would you like to disable SSH root login?" 10 50; then
             STATUS="0"
                 else
                     STATUS="$?"
         fi

      case "$STATUS" in

         0) ROOT_LOGIN="Yes"
            break
            ;;

         1) ROOT_LOGIN="No"
            break
            ;;

         *) exit_question
            ;;
     esac
done

while true; do

       if SSH_PORT=$(whiptail --title "$APP_NAME" --inputbox "\nSSH Port:" 10 50 3>&1 1>&2 2>&3); then
           STATUS="0"
               else
                   STATUS="$?"
       fi

           case "$STATUS" in

              0) if [[ -z "$SSH_PORT" ]]; then
                     whiptail --msgbox "\nYou haven't entered anything, please enter a\n                 port number" 10 50
                     continue
                 fi

                 if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]]; then
                     whiptail --msgbox "\n         Please enter numbers only" 10 50
                     continue
                 fi

                 if (( "$SSH_PORT" < 1 || "$SSH_PORT" > 65535 )); then
                     whiptail --msgbox "\n     Please enter a valid SSH port number" 10 50
                     continue
                 fi
                 break
                 ;;

             *) exit_question
                ;;
          esac
done

}


ntfy() {

while true; do

    if whiptail --title "$APP_NAME" --yesno "\n   Would you like to add an NTFY SSH alert?" 10 50; then
        STATUS="0"
            else
                STATUS="$?"
    fi

    case "$STATUS" in

         0) NTFY_CHOICE="Yes"
            break
            ;;

         1) NTFY_CHOICE="No"
            return 0
            ;;

         *) exit_question
            ;;

    esac
done

while true; do

    if [[ "$NTFY_CHOICE" == "No" ]]; then
        return 0
    fi


    if NTFY_DOMAIN=$(whiptail --title "$APP_NAME" --inputbox "\nNTFY Domain:" 10 50 3>&1 1>&2 2>&3); then
       STATUS="0"
            else
                STATUS="$?"
    fi

    case "$STATUS" in

        0) if [[ -z "$NTFY_DOMAIN" ]]; then

               whiptail --msgbox "\nYou haven't entered anything, please enter an\n                 NTFY domain" 10 50
               continue
                   else
                       break
           fi
           ;;


        *) exit_question
           ;;

    esac
done

while true; do

    if NTFY_TOPIC=$(whiptail --title "$APP_NAME" --inputbox "\nNTFY Topic:" 10 50 3>&1 1>&2 2>&3); then
        STATUS="0"
            else
                STATUS="$?"
    fi

    case "$STATUS" in

        0) if [[ -z "$NTFY_TOPIC" ]]; then

               whiptail --msgbox "\nYou haven't entered anything, please enter an\n                 NTFY topic" 10 50
               continue
                   else
                       return 0

           fi
           ;;

       *) exit_question
          ;;

    esac
done

}

hide_sensitive() {

if [[ -z "$USER_PASS" ]]; then

    USER_PASS_STATUS="Not Configured"
        else
            USER_PASS_STATUS="Configured"

fi


if [[ -z "$SSH_KEY" ]]; then

    SSH_KEY_STATUS="Not Configured"
        else
            SSH_KEY_STATUS="Configured"
fi

}


overview() {
  OVERVIEW=$(cat << EOF
                                      OVERVIEW
=====================================================================================

1. Add a new user?                                              ${USER_CHOICE:-Not Configured}
--------------------------------------------------------------------------------------
      1. Username:                                              ${USERNAME:-Not Configured}
      --------------------------------------------------------------------------------
      2. Username pass:                                         ${USER_PASS_STATUS}
      --------------------------------------------------------------------------------
      3. Add user to the sudo group?                            ${SUDO_ANSWER:-Not Configured}
      --------------------------------------------------------------------------------
      4. Select a shell to use:                                 ${SHELL_CHOICE:-Not Configured}
      --------------------------------------------------------------------------------
2. Would you like to enable SSH?                                ${ENABLE_SSH:-Not Configured}
--------------------------------------------------------------------------------------
      1. Access SSH with an authorization key?                  ${ENABLE_AUTHKEY:-Not Configured}
      --------------------------------------------------------------------------------
      2. Public key:                                            ${SSH_KEY_STATUS}
      --------------------------------------------------------------------------------
      3. Disable Password authentication?                       ${PASSWORD_AUTH:-Not Configured}
      --------------------------------------------------------------------------------
      4. Disable root login?                                    ${ROOT_LOGIN:-Not Configured}
      --------------------------------------------------------------------------------
      5. SSH port:                                              ${SSH_PORT:-Not Configured}
      --------------------------------------------------------------------------------
3. Would you like to add an NTFY SSH alert?                     ${NTFY_CHOICE:-Not Configured}
--------------------------------------------------------------------------------------
      1. NTFY domain:                                           ${NTFY_DOMAIN:-Not Configured}
      --------------------------------------------------------------------------------
      2. NTFY topic:                                            ${NTFY_TOPIC:-Not Configured}
      --------------------------------------------------------------------------------

                       Would you like to apply these updates?

EOF
)

while true; do

    if whiptail --title "$APP_NAME" --yesno "$OVERVIEW" --scrolltext 30 90; then
        STATUS="0"
            else
                STATUS="$?"
    fi

       case "$STATUS" in

         0) install_config
            return 0
            ;;

         1) if whiptail --title "$APP_NAME" --yesno "\n     Would you like to restart the script?" 10 50; then
               main_menu
                   else
                       exit_question
            fi
            ;;

        *) exit_question
           ;;

      esac

done

}


set_sshd_option() {

    local key="$1"
    local value="$2"

    if grep -qE "^[#[:space:]]*$key[[:space:]]+" "$SSHD_CONFIG"; then
        sed -i -E "s|^[#[:space:]]*$key[[:space:]]+.*|$key $value|" "$SSHD_CONFIG"
    else
        echo "$key $value" >> "$SSHD_CONFIG"
    fi
}


install_config() {

    if [[ "$USER_CHOICE" == "Yes" ]]; then

        if ! command -v "$SHELL_CHOICE" >/dev/null 2>&1; then
            apt update
            apt install -y "$SHELL_CHOICE"
        fi

        SHELL_PATH=$(command -v "$SHELL_CHOICE")

        useradd -m "$USERNAME"
        echo "$USERNAME:$USER_PASS" | chpasswd
        chsh -s "$SHELL_PATH" "$USERNAME"

    fi

    if [[ "$SUDO_ANSWER" == "Yes" ]]; then

        if ! command -v sudo >/dev/null 2>&1; then
            apt update
            apt install -y sudo
        fi

    usermod -aG sudo "$USERNAME"

    fi


    if [[ "$ENABLE_SSH" == "Yes" ]]; then

        if ! command -v sshd >/dev/null 2>&1; then
            apt update
            apt install -y openssh-server
        fi

            systemctl enable ssh
            systemctl start ssh

    fi


    if [[ "$ENABLE_AUTHKEY" == "Yes" ]]; then
        if [[ "$USER_CHOICE" == "Yes" ]]; then
            AUTH_USER="$USERNAME"
            AUTH_HOME="/home/$USERNAME"
        else
            AUTH_USER="root"
            AUTH_HOME="/root"
        fi

        mkdir -p "$AUTH_HOME/.ssh"
        echo "$SSH_KEY" > "$AUTH_HOME/.ssh/authorized_keys"

        chmod 700 "$AUTH_HOME/.ssh"
        chmod 600 "$AUTH_HOME/.ssh/authorized_keys"

        chown -R "$AUTH_USER:$AUTH_USER" "$AUTH_HOME/.ssh"

    fi

    if [[ "$ENABLE_SSH" == "Yes" ]]; then

        SSHD_CONFIG="/etc/ssh/sshd_config"

        if [[ "$PASSWORD_AUTH" == "Yes" ]]; then
            set_sshd_option "PasswordAuthentication" "no"
        fi

        if [[ "$ROOT_LOGIN" == "Yes" ]]; then
            set_sshd_option "PermitRootLogin" "no"
        fi

        if [[ -n "$SSH_PORT" ]]; then
            set_sshd_option "Port" "$SSH_PORT"
        fi

        sshd -t
        systemctl restart ssh
    fi


    if systemctl list-unit-files ssh.socket >/dev/null 2>&1; then
        systemctl disable --now ssh.socket
        sshd -t
        systemctl restart ssh
    fi


if [[ "$NTFY_CHOICE" == "Yes" ]]; then

    if ! command -v curl >/dev/null 2>&1; then

        apt update -y
        apt install curl -y

    fi

    grep -qxF "session optional pam_exec.so /usr/bin/ntfy-ssh-login.sh" /etc/pam.d/sshd \
        || echo "session optional pam_exec.so /usr/bin/ntfy-ssh-login.sh" >> /etc/pam.d/sshd

    cat > /usr/bin/ntfy-ssh-login.sh <<EOF
#!/usr/bin/env bash

NTFY_URL="$NTFY_DOMAIN/$NTFY_TOPIC"

if [[ "\$PAM_TYPE" == "open_session" ]]; then
    curl -s \\
        -H "Tags: warning,exclamation" \\
        -H "Title: SSH Login" \\
        -d "\$PAM_USER@\$(hostname -f) from \$PAM_RHOST" \\
        "\$NTFY_URL" > /dev/null
fi
EOF

    chmod +x /usr/bin/ntfy-ssh-login.sh
fi



    clear
    echo "Setup completed successfully."
    read -n 1 -s -r -p "Press any key to exit..."
    exit 0

}


check_root
fix_network
install_whiptail
main_menu

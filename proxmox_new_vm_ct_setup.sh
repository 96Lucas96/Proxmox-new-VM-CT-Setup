#!/usr/bin/env bash
set -euo pipefail

APP_NAME="New VM/CT Setup Script"

variable_reset() {

USER_CHOICE=""
USERNAME=""
USER_PASS=""
USER_PASS_STATUS=""
USER_PASS_VERIFY=""
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
        echo "Your are not root, please switch to the root user and re-run the script"
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


exit_question() {
    if whiptail --title "$APP_NAME" --yes-button "Exit" --no-button "Stay" \
        --yesno "\n        Are you sure you want to exit?" 10 50; then
        exit 0
    fi
}

ask_input() {
    local kind="$1" prompt="$2" initial="${3:-}" rc
    local output
    if [[ "$kind" == passwordbox ]]; then
        if output=$(whiptail --title "$APP_NAME" --ok-button "OK" --cancel-button "Back" \
            --passwordbox "$prompt" 10 50 3>&1 1>&2 2>&3); then
            ANSWER="$output"; return 0
        else
            rc=$?
        fi
    else
        if output=$(whiptail --title "$APP_NAME" --ok-button "OK" --cancel-button "Back" \
            --inputbox "$prompt" 10 50 "$initial" 3>&1 1>&2 2>&3); then
            ANSWER="$output"; return 0
        else
            rc=$?
        fi
    fi
    return "$rc"
}

ask_yes_no() {
    local prompt="$1" current="${2:-Yes}" rc selection rendered
    [[ "$current" == No ]] || current=Yes
    printf -v rendered '%b' "$prompt"

    local line shifted=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -n "$line" ]]; then
            shifted+="      $line"
        fi
        shifted+=$'\n'
    done <<< "$rendered"
    rendered="${shifted%$'\n'}"
    if selection=$(whiptail --title "$APP_NAME" --ok-button "OK" --cancel-button "Back" \
        --default-item "$current" --menu "${rendered}"$'\n\n\n' 15 60 2 \
        "Yes" "" "No" "" 3>&1 1>&2 2>&3); then
        ANSWER="$selection"; return 0
    else
        rc=$?
    fi
    return "$rc"
}

ask_shell() {
    local rc selection default="${SHELL_CHOICE:-bash}"
    if selection=$(whiptail --title "$APP_NAME" --ok-button "OK" --cancel-button "Back" \
        --default-item "$default" --menu "\n\n                 Select a shell to use: \n\n\n\n" 15 60 4 \
        "sh" "" "bash" "" "zsh" "" "fish" "" \
        3>&1 1>&2 2>&3); then
        ANSWER="$selection"; return 0
    else
        rc=$?
    fi
    return "$rc"
}

step_applies() {
    case "$1" in
        1|2|3|4) [[ "$USER_CHOICE" == Yes ]] ;;
        6) [[ "$ENABLE_SSH" == Yes ]] ;;
        8) [[ "$ENABLE_SSH" == Yes && "$ENABLE_AUTHKEY" == Yes ]] ;;
        9) [[ "$ENABLE_SSH" == Yes && "$ENABLE_AUTHKEY" == Yes && -n "$SSH_KEY" ]] ;;
        10) [[ "$ENABLE_SSH" == Yes && "$USER_CHOICE" == Yes ]] ;;
        11) [[ "$ENABLE_SSH" == Yes ]] ;;
        13|14) [[ "$NTFY_CHOICE" == Yes ]] ;;
        *) return 0 ;;
    esac
}

clear_inapplicable() {
    if [[ "$USER_CHOICE" != Yes ]]; then
        USERNAME=""; USER_PASS=""; USER_PASS_VERIFY=""; SUDO_ANSWER=""; SHELL_CHOICE=""
    fi
    if [[ "$ENABLE_SSH" != Yes ]]; then
        ENABLE_AUTHKEY=""; SSH_KEY=""; PASSWORD_AUTH=""; ROOT_LOGIN=""; SSH_PORT=""
    elif [[ "$ENABLE_AUTHKEY" != Yes ]]; then
        SSH_KEY=""; PASSWORD_AUTH=""
    fi
    if [[ "$USER_CHOICE" != Yes ]]; then ROOT_LOGIN=""; fi
    if [[ "$NTFY_CHOICE" != Yes ]]; then NTFY_DOMAIN=""; NTFY_TOPIC=""; fi
}

setup_questions() {
    local step=0 rc previous
    while true; do
        if ! step_applies "$step"; then
            ((step += 1))
            continue
        fi
        rc=0
        case "$step" in
            0) ask_yes_no "\n\n               Add a new user?" "$USER_CHOICE" || rc=$?
               if ((rc == 0)); then USER_CHOICE="$ANSWER"; clear_inapplicable; fi ;;
            1) ask_input inputbox "\nUsername:" "$USERNAME" || rc=$?
               if ((rc == 0)); then
                   if [[ -z "$ANSWER" || ! "$ANSWER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                       whiptail --msgbox "Please enter a valid username (lowercase letters, digits, _ or -)." 10 60
                       continue
                   fi
                   if id "$ANSWER" &>/dev/null; then
                       whiptail --msgbox "Username already exists." 10 50
                       continue
                   fi
                   USERNAME="$ANSWER"
               fi ;;
            2) ask_input passwordbox "\nUser Password:" || rc=$?
               if ((rc == 0)); then
                   if [[ -z "$ANSWER" && -z "$USER_PASS" ]]; then
                       whiptail --msgbox "Please enter a user password." 10 50
                       continue
                   fi
                   if [[ -n "$ANSWER" ]]; then
                       USER_PASS="$ANSWER"
                       # Verification is part of the same step; Back returns to password entry.
                       if ask_input passwordbox "\nPlease verify user password:"; then
                           if [[ "$ANSWER" != "$USER_PASS" ]]; then
                               whiptail --msgbox "Passwords don't match. Please try again." 10 50
                               USER_PASS=""; continue
                           fi
                           USER_PASS_VERIFY="$ANSWER"
                       else
                           rc=$?
                           if ((rc == 1)); then continue; fi
                       fi
                   fi
               fi ;;
            3) ask_yes_no "\n\n         Add user to the sudo group?" "$SUDO_ANSWER" || rc=$?
               if ((rc == 0)); then SUDO_ANSWER="$ANSWER"; fi ;;
            4) ask_shell || rc=$?
               if ((rc == 0)); then SHELL_CHOICE="$ANSWER"; fi ;;
            5) ask_yes_no "\n\n         Would you like to enable SSH?" "$ENABLE_SSH" || rc=$?
               if ((rc == 0)); then ENABLE_SSH="$ANSWER"; clear_inapplicable; fi ;;
            6) ask_yes_no "\n\n     Would you like to access SSH with an\n              authorization key?" "$ENABLE_AUTHKEY" || rc=$?
               if ((rc == 0)); then ENABLE_AUTHKEY="$ANSWER"; clear_inapplicable; fi ;;
            7) # Reserved for navigation compatibility; key entry is step 8.
               ((step += 1)); continue ;;
            8) ask_input inputbox "\nEnter the PUBLIC KEY of the device you want to connect FROM:" "$SSH_KEY" || rc=$?
               if ((rc == 0)); then
                   if [[ -z "$ANSWER" ]]; then
                       whiptail --msgbox "Please enter an SSH public key." 10 50; continue
                   fi
                   SSH_KEY="$ANSWER"
               fi ;;
            9) ask_yes_no "\n\n   Would you like to disable SSH password\n               authentication" "$PASSWORD_AUTH" || rc=$?
               if ((rc == 0)); then PASSWORD_AUTH="$ANSWER"; fi ;;
            10) ask_yes_no "\n\n   Would you like to disable SSH root login?" "$ROOT_LOGIN" || rc=$?
                if ((rc == 0)); then ROOT_LOGIN="$ANSWER"; fi ;;
            11) ask_input inputbox "\nSSH Port:" "${SSH_PORT:-22}" || rc=$?
                if ((rc == 0)); then
                    if [[ ! "$ANSWER" =~ ^[0-9]+$ ]] || ((10#$ANSWER < 1 || 10#$ANSWER > 65535)); then
                        whiptail --msgbox "Please enter a valid SSH port (1-65535)." 10 50; continue
                    fi
                    SSH_PORT="$ANSWER"
                fi ;;
            12) ask_yes_no "\n\n   Would you like to add an NTFY SSH alert?" "$NTFY_CHOICE" || rc=$?
                if ((rc == 0)); then NTFY_CHOICE="$ANSWER"; clear_inapplicable; fi ;;
            13) ask_input inputbox "\nEnter NTFY domain WITHOUT the topic:" "$NTFY_DOMAIN" || rc=$?
                if ((rc == 0)); then
                    if [[ -z "$ANSWER" ]]; then whiptail --msgbox "Please enter an NTFY domain." 10 50; continue; fi
                    NTFY_DOMAIN="$ANSWER"
                fi ;;
            14) ask_input inputbox "\nNTFY Topic:" "$NTFY_TOPIC" || rc=$?
                if ((rc == 0)); then
                    if [[ -z "$ANSWER" ]]; then whiptail --msgbox "Please enter an NTFY topic." 10 50; continue; fi
                    NTFY_TOPIC="$ANSWER"
                fi ;;
            15) hide_sensitive
                overview || rc=$?
                if ((rc == 0)); then install_config; return 0; fi ;;
        esac
        case "$rc" in
            0) ((step += 1)) ;;
            1) previous=$((step - 1))
               while ((previous >= 0)); do
                   if step_applies "$previous" && ((previous != 7)); then break; fi
                   ((previous -= 1))
               done
               if ((previous < 0)); then return 0; fi
               step=$previous ;;
            255) exit_question ;;
            *) exit_question ;;
        esac
    done
}

hide_sensitive() {
    if [[ -z "$USER_PASS" ]]; then USER_PASS_STATUS="Not Configured"; else USER_PASS_STATUS="Configured"; fi
    if [[ -z "$SSH_KEY" ]]; then SSH_KEY_STATUS="Not Configured"; else SSH_KEY_STATUS="Configured"; fi
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
    local rc
    if whiptail --title "$APP_NAME" --yes-button "OK" --no-button "Back" \
        --yesno "$OVERVIEW" --scrolltext 30 90; then
        return 0
    else
        rc=$?
    fi
    return "$rc"
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

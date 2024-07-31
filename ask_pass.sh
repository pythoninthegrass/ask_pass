#!/usr/bin/env bash

# shellcheck disable=SC2317

# show description
help() {
	cat <<- DESCRIPTION >&2
	Bespoke askpass script for macOS.

	USAGE
	    $(basename "$0") [OPTIONS]

	OPTIONS
	    -s|--set    Set password in keychain.
	    -g|--get    Get password from keychain. [default]
	    -d|--delete Delete password from keychain.
	    -c|--custom Set custom service name in keychain.
	    -v|--vault  Use 'vault-pass' as the service name.
	    --sudo      Use 'ansible-sudo' as the service name.
	    -h|--help   Show this help message.

	EXAMPLES
	    # set a custom service name password
	    $(basename "$0") -c <custom-service-name> -s

	    # get a custom service name password
	    $(basename "$0") -c <custom-service-name> -g

	    # delete a custom service name password
	    $(basename "$0") -c <custom-service-name> -d

	    # use vault-pass service
	    $(basename "$0") -v

	    # use ansible-sudo service
	    $(basename "$0") --sudo

	NOTES
	    Set 'SUDO_ASKPASS=$(realpath "$0")' in your shell profile.
	    e.g., echo "export SUDO_ASKPASS='$(realpath "$0")'" >> ~/.bashrc

	    Can override the default service name by setting the env var 'ASKPASS_SERVICE_NAME'.
	    e.g., export ASKPASS_SERVICE_NAME='custom-service-name'
	DESCRIPTION
}

# $USER
[[ -n $(logname >/dev/null 2>&1) ]] && logged_in_user=$(logname) || logged_in_user=$(whoami)

# read env var for service name
service_name="${ASKPASS_SERVICE_NAME:-ssh-ask-pass}"

# set password in keychain
set_password() {
    local max_attempts=3
    local attempt=1
    local password
    local confirm_password

    while (( attempt <= max_attempts )); do
        echo -n "Enter password for $service_name: " >&2
        read -rs password
        echo >&2

        echo -n "Confirm password: " >&2
        read -rs confirm_password
        echo >&2

        if [[ "$password" == "$confirm_password" ]]; then
            security add-generic-password \
                -a "$logged_in_user" \
                -s "$service_name" \
                -w "$password" \
                -U > /dev/null 2>&1
            ret_code=$?
            if [[ "$ret_code" -eq 0 ]]; then
                echo "Password set in keychain service: $service_name"
                return 0
            else
                echo "Failed to set password in keychain service: $service_name" >&2
                return 1
            fi
        else
            echo "Passwords do not match. Please try again." >&2
            (( attempt++ ))
            if (( attempt > max_attempts )); then
                echo "Maximum attempts reached. Password not set." >&2
                return 1
            fi
        fi
    done
}

# get password from keychain
get_password() {
	output=$(security find-generic-password -l "$service_name" -w 2>&1)
	ret_code=$(echo "$output" | awk '/The specified item could not be found in the keychain./ {print 1}')
	if [[ "$ret_code" -ne 0 ]]; then
		echo "Password not found in keychain service: $service_name" >&2
		set_password
	else
		echo "$output"
	fi
}

# remove password from keychain
_delete_password() {
	security delete-generic-password \
		-a "$logged_in_user" \
		-s "$service_name" > /dev/null 2>&1
	ret_code=$?
	if [[ "$ret_code" -ne 0 ]]; then
		echo "Password failed to delete from keychain service: $service_name" >&2
	else
		echo "Password deleted from keychain service: $service_name"
	fi
}

# update password in keychain
update_password() {
    if get_password > /dev/null 2>&1; then
        echo "Updating existing password for service: $service_name"
    else
        echo "Creating new password for service: $service_name"
    fi
    set_password
}

main() {
    local action=""
    local custom_service=""
    local use_vault=false
    local use_sudo=false

    while getopts ":hsgdvc:-:" opt; do
        case ${opt} in
            h)
                help
                exit 0
                ;;
            s)
                action="update"
                ;;
            g)
                action="get"
                ;;
            d)
                action="delete"
                ;;
            v)
                use_vault=true
                ;;
            c)
                custom_service="$OPTARG"
                ;;
            -)
                case "${OPTARG}" in
                    help)
                        help
                        exit 0
                        ;;
                    set)
                        action="update"
                        ;;
                    get)
                        action="get"
                        ;;
                    delete)
                        action="delete"
                        ;;
                    custom)
                        custom_service="${!OPTIND}"; OPTIND=$(( OPTIND + 1 ))
                        ;;
                    vault)
                        use_vault=true
                        ;;
                    sudo)
                        use_sudo=true
                        ;;
                    *)
                        echo "Invalid option: --${OPTARG}" >&2
                        help
                        exit 1
                        ;;
                esac
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                help
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                help
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))

    # Handle custom service name
    if [[ -n "$custom_service" ]]; then
        service_name="$custom_service"
    elif $use_vault; then
        service_name="vault-pass"
    elif $use_sudo; then
        service_name="ansible-sudo"
    fi

    # If no action specified, default to get
    action="${action:-get}"

    case "$action" in
        update)  update_password ;;
        get)     get_password ;;
        delete)  _delete_password ;;
    esac
}
main "$@"

exit 0

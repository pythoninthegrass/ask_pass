#!/usr/bin/env bash

# shellcheck disable=SC2317

# SOURCES
# https://superuser.com/questions/393506/can-i-automatically-login-to-ssh-using-passwords-from-os-x-keychain

# show description
help() {
	cat <<- DESCRIPTION >&2
	Bespoke askpass script for macOS.

	USAGE
	    $(basename "$0") [OPTIONS]

	OPTIONS
	    -s|--set	Set password in keychain.
	    -g|--get	Get password from keychain. [default]
	    -d|--delete	Delete password from keychain.
	    -c|--custom	Set custom service name in keychain.
	    -h|--help	Show this help message.

	EXAMPLES
	    # set a custom service name password
	    $(basename "$0") -c <custom-service-name> -s

	    # get a custom service name password
	    $(basename "$0") -c <custom-service-name> -g

	    # delete a custom service name password
	    $(basename "$0") -c <custom-service-name> -d

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
	security add-generic-password \
		-a "$logged_in_user" \
		-s "$service_name" \
		-w > /dev/null 2>&1
	ret_code=$?
	if [[ "$ret_code" -ne 0 ]]; then
		echo "Failed to set password in keychain service: $service_name" >&2
		exit 1
	else
		echo "Password set in keychain service: $service_name"
	fi
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

main() {
	if [ "$#" -eq 0 ]; then
		get_password
	else
		case "$1" in
			-h|--help)
				help
				;;
			-s|--set)
				set_password
				;;
			-c|--custom)
				shift
				service_name="$1"
				shift
				case "$1" in
					-s|--set)
						set_password
						;;
					-g|--get)
						get_password
						;;
					-d|--delete)
						_delete_password
						;;
					*)
						echo "Invalid option: $1" >&2
						help
						exit 1
						;;
				esac
				;;
			-g|--get)
				get_password
				;;
			-d|--delete)
				_delete_password
				;;
			*)
				echo "Invalid option: $1" >&2
				help
				exit 1
				;;
		esac
	fi
}
main "$@"

exit 0

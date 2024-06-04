# ask_pass

Bespoke [askpass](https://apple.stackexchange.com/questions/23494/what-option-should-i-give-the-sudo-command-to-have-the-password-asked-through-a) script for macOS.

## Installation

```bash
git clone https://github.com/pythoninthegrass/ask_pass.git
ln -s $(pwd)/ask_pass.sh ~/.local/bin/askpass
```

## Quickstart

```bash
USAGE
    ask_pass.sh [OPTIONS]

OPTIONS
    -s|--set	Set password in keychain.
    -g|--get	Get password from keychain. [default]
    -d|--delete	Delete password from keychain.
    -c|--custom	Set custom service name in keychain.
    -h|--help	Show this help message.

EXAMPLES
    # set a custom service name password
    ask_pass.sh -c <custom-service-name> -s

    # get a custom service name password
    ask_pass.sh -c <custom-service-name> -g

    # delete a custom service name password
    ask_pass.sh -c <custom-service-name> -d

NOTES
    Set 'SUDO_ASKPASS=$(realpath "$0")' in your shell profile.
    e.g., echo "export SUDO_ASKPASS='$(realpath "$0")'" >> ~/.bashrc

    Can override the default service name by setting the env var 'ASKPASS_SERVICE_NAME'.
    e.g., export ASKPASS_SERVICE_NAME='custom-service-name'
```

## Use with Ansible

```bash
# create
ansible-vault create vault.yml

# create a custom service name password
export ASKPASS_SERVICE_NAME='vault-pass'
askpass -s

# print
export ANSIBLE_VAULT_PASSWORD_FILE=$(which askpass)
$ ansible-vault view vault.yml
Secret meeting in the basement of my brain
```

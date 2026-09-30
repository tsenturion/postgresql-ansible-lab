#!/usr/bin/env bash
set -euo pipefail
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if [[ ! -f local.yml ]]; then
    printf '%s\n' 'Сначала создайте local.yml по образцу local.example.yml и вставьте открытый ключ Windows.' >&2
    exit 1
fi

# Коллекция устанавливается до разбора плейбука, использующего её модули.
sudo -v
if ! command -v ansible-playbook >/dev/null || ! /usr/bin/python3 -c 'import passlib' 2>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y ansible-core python3-passlib
fi
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible-galaxy collection install -r requirements.yml -p "$PWD/collections"
sudo env LANG="$LANG" LC_ALL="$LC_ALL" ANSIBLE_CONFIG="$ANSIBLE_CONFIG" ansible-playbook site.yml -e @local.yml "$@"

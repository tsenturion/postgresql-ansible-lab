#!/usr/bin/env bash
set -euo pipefail
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if [[ ! -f local-kafka.yml ]]; then
    printf '%s\n' 'Создайте local-kafka.yml по образцу local-kafka.example.yml и вставьте открытый ключ Windows.' >&2
    exit 1
fi

sudo -v
if ! command -v ansible-playbook >/dev/null || ! /usr/bin/python3 -c 'import passlib' 2>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends ansible-core python3-passlib
fi
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
sudo env LANG="$LANG" LC_ALL="$LC_ALL" ANSIBLE_CONFIG="$ANSIBLE_CONFIG" ansible-playbook kafka.yml -e @local-kafka.yml "$@"

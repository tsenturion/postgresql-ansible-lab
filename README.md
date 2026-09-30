# Учебная нода PostgreSQL 18.6 через локальный Ansible

Репозиторий содержит отдельные варианты развёртывания `master1` с PostgreSQL и `master2` с Kafka из полного клона базовой Ubuntu Server. Ansible запускается на самой ноде через `connection: local`: предварительно настраивать SSH для его работы не требуется.

- PostgreSQL: `bash bootstrap.sh`, параметры в `local.yml`; инструкция ниже.
- Kafka: `bash bootstrap-kafka.sh`, параметры в `local-kafka.yml`; [инструкция по установке Kafka](KAFKA.md).

Это конфигурация учебной ВМ в локальной сети. В ней намеренно заданы известные учебные пароли и разрешён SSH-вход root по паролю. Для сервера вне учебной среды эти параметры нужно изменить.

## Что получается

| Компонент | Значение по умолчанию |
| --- | --- |
| Имя ноды | `master1` |
| Исходный пользователь Ubuntu | `ubuntu`, пароль `ubuntu`, создаётся при установке ОС |
| Дополнительный пользователь Ubuntu | `admin`, пароль `admin`, sudo без пароля |
| Root Ubuntu | пароль `root`, SSH по паролю и по ключу |
| SSH без пароля | открытый ключ Windows в `authorized_keys` пользователей ubuntu, admin и root |
| Адаптер 1 | NAT, `enp0s3`, DHCP |
| Адаптер 2 | мост, `enp0s8`, `192.168.0.33/24`, без второго шлюза |
| PostgreSQL | 18.6, сборка из включённого в Git архива |
| Исходники | `/usr/local/src/postgresql-18.6` |
| Программы | `/opt/postgresql` |
| Кластер | `/data/postgresql/18/main`, UTF-8, ICU `ru-RU` |
| Служба | `postgresql-18`, автозапуск |
| База и роль | `postgres` / `postgres`, пароль роли `admin` |
| Unix-сокет | `/tmp`, аутентификация `peer` |
| TCP | порт `5432`, SCRAM, loopback и `192.168.0.0/24` |
| Расширения | pageinspect, pg_buffercache, pg_stat_statements, dblink, plpython3u |
| Python | openpyxl и reportlab из пакетов Ubuntu |

`admin` — пользователь Ubuntu для SSH и sudo. Роль `admin` и база `lab` в PostgreSQL не создаются. Файл настроек `lab.conf` — имя файла, а не база данных.

## 1. Один раз создать базовую ВМ

Установить [Ubuntu Server](https://ubuntu.com/download/server) в [VirtualBox](https://www.oracle.com/virtualization/technologies/vm/downloads/virtualbox-downloads.html). Для этой установки используется Ubuntu 26.04.1. Назвать базовую ВМ, например, `ubuntu-26-04-1`.

Минимум при установке:

1. Адаптер 1 — NAT с подключённым кабелем; DHCP должен дать доступ в Интернет.
2. Диск от 30 ГБ, память от 4 ГБ, от 2 процессоров.
3. Создать пользователя **ubuntu** с паролем **ubuntu** и правом sudo.
4. Установить ОС и выключить базовую ВМ. PostgreSQL и Ansible на базовой ВМ не нужны. OpenSSH при установке необязателен: все действия ниже можно выполнить через консоль VirtualBox.

## 2. Вручную создать полный клон

В VirtualBox: правой кнопкой по выключенной базовой ВМ → **Clone** → имя **master1** → **Generate new MAC addresses for all network adapters** → **Full clone**. Базовую ВМ оставить выключенной.

В настройках клона:

- адаптер 1 — NAT, **Cable Connected**;
- в пробросе портов добавить TCP: IP хоста `127.0.0.1`, порт хоста `2222`, IP гостя пустой, порт гостя `22`;
- адаптер 2 — **Bridged Adapter**, выбрать активный физический адаптер Windows и включить **Cable Connected**.

Выбрать свободный адрес в своей сети: пример `192.168.0.33/24` подходит только для сети `192.168.0.0/24`. Имя ВМ в VirtualBox и hostname внутри Ubuntu — разные настройки. Hostname установит плейбук. Если нужно переименовать вручную до его запуска:

```bash
sudo hostnamectl set-hostname master1
```

Внутренний hostname затем всё равно сверяется с `node_hostname` из настроек Ansible. MAC, machine-id и серверные ключи SSH у клона должны быть свои: MAC меняет VirtualBox, остальные идентификаторы плейбук создаёт при первом запуске.

## 3. Минимальная ручная подготовка клона

Запустить `master1`, войти через консоль VirtualBox как `ubuntu` с паролем `ubuntu`:

```bash
sudo apt update
sudo apt install -y git ansible-core
git clone https://github.com/tsenturion/postgresql-ansible-lab.git
cd postgresql-ansible-lab
cp local.example.yml local.yml
nano local.yml
```

Не нужно вручную настраивать root, admin, SSH, Netplan или PostgreSQL перед запуском. Файл `local.yml` задаёт параметры конкретной ноды и игнорируется Git.

На Windows вывести **открытый** ключ:

```powershell
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
```

Если ключ ещё не создан:

```powershell
ssh-keygen -t ed25519
```

Вставить всю строку открытого ключа в `local.yml`, заменив образец. Закрытый `id_ed25519` остаётся на Windows. Пример структуры:

```yaml
node_hostname: master1
bridge_address: 192.168.0.33/24
postgres_allowed_subnet: 192.168.0.0/24
ssh_public_keys:
  - 'ssh-ed25519 ВАШ_ОТКРЫТЫЙ_КЛЮЧ'
```

Если интерфейсы называются иначе, проверить `ip -br link` и добавить `nat_interface` / `bridge_interface` в `local.yml`. При двух адаптерах Intel PRO/1000 в этой ВМ используются `enp0s3` и `enp0s8`.

### Другое имя или IP-адрес ноды

Имя ВМ в списке VirtualBox задаётся при клонировании или в настройках готовой ВМ (**General / Основные → Name / Имя**). Hostname Ubuntu и IP-адрес моста задаются в `local.yml` на ноде:

```yaml
node_hostname: pg-node1
bridge_address: 192.168.0.40/24
postgres_allowed_subnet: 192.168.0.0/24
```

Остальные строки, включая открытые ключи, сохранить. Если меняется только IP внутри той же подсети, `postgres_allowed_subnet` остаётся прежним. При переходе в другую подсеть изменить и разрешённую подсеть PostgreSQL. `local.yml` имеет приоритет над общим `settings.yml`.

Чтобы имя в VirtualBox и hostname Ubuntu совпадали, указать одинаковое значение в обоих местах. Ansible управляет hostname внутри гостевой ОС.

Для изменения уже работающей ноды отредактировать `local.yml` и снова запустить `bash bootstrap.sh`. Смену IP применять из консоли VirtualBox или по SSH через NAT `127.0.0.1:2222`. После этого обновить адрес прямого подключения в SSH-конфигурации Windows и DBeaver. SSH-алиасы можно переименовать по желанию; NAT-подключения SSH/FileZilla сохраняются при прежнем правиле проброса. Смена hostname сама по себе не создаёт запись DNS.

## 4. Запустить автоматизацию

```bash
bash bootstrap.sh
```

При запросе sudo ввести пароль `ubuntu`. Обёртка сама ставит недостающую зависимость Python `passlib`, устанавливает коллекцию `community.postgresql` из `requirements.yml` и запускает плейбук от root. Коллекция загружается **до** разбора плейбука: использующие её модули должны быть доступны уже на этом этапе. [Документация Ansible по установке коллекций](https://docs.ansible.com/projects/ansible/latest/collections_guide/collections_installing.html).

Плейбук устанавливает зависимости Ubuntu, создаёт пользователей и ключи, меняет hostname и Netplan, распаковывает включённый архив, собирает PostgreSQL, создаёт кластер и службу. `make world-bin` / `make install-world-bin` включают сервер, contrib и выбранные процедурные языки; отдельная повторная сборка четырёх contrib-модулей при таком способе не требуется. [Сборка PostgreSQL](https://www.postgresql.org/docs/18/install-make.html).

После установки файлов выполняются эквиваленты:

```sql
CREATE EXTENSION IF NOT EXISTS pageinspect;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS dblink;
CREATE EXTENSION IF NOT EXISTS plpython3u;
```

`shared_preload_libraries = 'pg_stat_statements'` задаётся до запуска сервера. `plpython3u` собирается благодаря `--with-python`, а openpyxl и reportlab устанавливаются отдельно как Python-библиотеки. В конце плейбук проверяет все расширения и создаёт Excel/PDF в памяти, без сохранения файлов.

После успешного первого запуска перезагрузить клон, чтобы все процессы использовали новый machine-id:

```bash
sudo reboot
```

## 5. Подключения с Windows

### SSH

В `%USERPROFILE%\.ssh\config`:

```sshconfig
Host master1
    HostName 192.168.0.33
    User admin
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host master1-admin
    HostName 127.0.0.1
    User admin
    Port 2222

Host master1-root
    HostName 127.0.0.1
    User root
    Port 2222
```

```powershell
ssh master1-root
```

Пароль учётной записи не нужен при использовании соответствующего закрытого ключа. Если ключ защищён собственной парольной фразой, её запрос относится к ключу; используйте SSH-agent для сохранения разблокированного ключа в сеансе Windows.

После удаления предыдущей `master1` её старые записи `known_hosts` не соответствуют новому клону. Удалить только записи заменённой ВМ, убедившись, что подключение направлено к своему новому клону:

```powershell
ssh-keygen -R "[127.0.0.1]:2222"
ssh-keygen -R "192.168.0.33"
```

### FileZilla

FileZilla Client → **File → Site Manager → New site**:

| Поле | Значение |
| --- | --- |
| Protocol | SFTP — SSH File Transfer Protocol |
| Host | `127.0.0.1` |
| Port | `2222` |
| Logon Type | Normal |
| User | `root` |
| Password | `root` |

Принять ключ нового сервера при первом подключении к своей ВМ. Дополнительная настройка ключа в FileZilla для входа по паролю не нужна. При необходимости можно вручную передать `.tar.gz` из Downloads в `/usr/local/src`; для этого варианта установки архив уже находится в репозитории и плейбук размещает его сам.

### DBeaver на Windows

**Database → New Database Connection → PostgreSQL**:

| Поле | Значение |
| --- | --- |
| Host | `192.168.0.33` |
| Port | `5432` |
| Database | `postgres` |
| Username | `postgres` |
| Password | `admin` |

Нажать **Test Connection**, при запросе скачать JDBC-драйвер, затем **Finish**. Через NAT доступен SSH-туннель: на основной вкладке Host `127.0.0.1`, Port `5432`, Database `postgres`; на вкладке SSH включить **Use SSH Tunnel**, Host `127.0.0.1`, Port `2222`, User `root`, пароль `root`. PostgreSQL-пароль остаётся `admin`.

### Локальный psql на Ubuntu

```bash
sudo -u postgres /opt/postgresql/bin/psql -d postgres
```

Это вход через Unix-сокет без пароля PostgreSQL. `peer` сопоставляет пользователя Linux с ролью PostgreSQL; root сначала запускает клиент от Linux-пользователя postgres. Отдельная роль PostgreSQL root не создаётся.

## Повторный запуск и обновление

```bash
cd ~/postgresql-ansible-lab
git pull --ff-only
bash bootstrap.sh
```

Существующий кластер не инициализируется повторно. Сервер пересобирается только при отсутствии необходимых компонентов или изменении параметров сборки. Установка этой автоматизации предполагает выделенную учебную ноду: она заменяет её Netplan, pg_hba и учебные настройки PostgreSQL. Архив PostgreSQL находится в корне репозитория; он не скачивается заново при запуске.

Прямая команда запуска после подготовки зависимостей и коллекции:

```bash
sudo env LANG=C.UTF-8 LC_ALL=C.UTF-8 ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook site.yml -e @local.yml
```

Проверки:

```bash
hostnamectl --static
ip -br address
ip route
systemctl is-active postgresql-18
systemctl is-enabled postgresql-18
sudo -u postgres /opt/postgresql/bin/psql -d postgres -c '\dx'
sudo -u postgres /opt/postgresql/bin/psql -d postgres -c 'SHOW shared_preload_libraries;'
```

## Состав репозитория

- `bootstrap.sh` — установка коллекции и запуск Ansible;
- `site.yml` — все этапы настройки одной ноды;
- `settings.yml` — общие учебные параметры;
- `local.example.yml` — образец индивидуальных настроек;
- `inventory.yml` и `ansible.cfg` — локальное выполнение;
- `requirements.yml` — версия коллекции PostgreSQL;
- `templates/` — конфигурации сети, SSH и PostgreSQL;
- `verify.sql` — проверка пяти расширений и Python-библиотек;
- `postgresql-18.6.tar.gz` — исходный архив PostgreSQL, предоставленный для курса.

## Проверка на реальной ВМ

Развёртывание проверено на полном клоне Ubuntu Server 26.04.1: PostgreSQL 18.6 установлен, пять расширений работают, служба запускается после перезагрузки. Повторный запуск плейбука без изменения настроек завершился с `changed=0` и `failed=0`. С Windows проверены SSH по ключу, SFTP root по паролю и подключение PostgreSQL к `192.168.0.33:5432` с ролью и базой `postgres`.

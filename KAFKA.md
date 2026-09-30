# Установка Apache Kafka на master2

Инструкция устанавливает готовый дистрибутив Kafka 4.3.1 на Ubuntu Server 26.04.1. Используется одна нода KRaft с ролями broker и controller. Выбрать один способ: ручная установка или Ansible.

## Программы и страницы скачивания

- [Oracle VirtualBox](https://www.oracle.com/virtualization/technologies/vm/downloads/virtualbox-downloads.html).
- [Ubuntu Server](https://ubuntu.com/download/server).
- [Apache Kafka — официальная страница скачивания](https://kafka.apache.org/downloads/).
- [Kafka — зеркало Яндекса](https://mirror.yandex.ru/mirrors/apache/kafka/).
- [Kafka 4.3.1 — готовый дистрибутив kafka_2.13-4.3.1.tgz](https://mirror.yandex.ru/mirrors/apache/kafka/4.3.1/kafka_2.13-4.3.1.tgz).
- [Пакеты Ubuntu — зеркало Яндекса](https://mirror.yandex.ru/ubuntu/).
- [FileZilla Client](https://filezilla-project.org/download.php?type=client).
- [Visual Studio Code](https://code.visualstudio.com/download).
- [Репозиторий автоматизации](https://github.com/tsenturion/postgresql-ansible-lab).

Kafka распаковывается из готового `.tgz`; компиляция не выполняется. Через `apt` устанавливаются Java и системные компоненты. Java 25 поддерживается Kafka 4.3. [Документация Java для Kafka](https://kafka.apache.org/43/operations/java-version/).

## Итоговые параметры

| Компонент | Значение |
| --- | --- |
| Имя ВМ и hostname Ubuntu | `master2` |
| Исходный пользователь Ubuntu | `ubuntu`, пароль `ubuntu` |
| Пользователь Ubuntu для SSH и sudo | `admin`, пароль `admin`, sudo без пароля |
| Root Ubuntu | пароль `root`, SSH по ключу и паролю |
| Адаптер 1 | NAT, DHCP на `enp0s3` |
| Проброс SSH | `127.0.0.1:2223` → порт `22` гостя |
| Адаптер 2 | мост, `enp0s8`, `192.168.0.34/24` |
| Java | OpenJDK 25, пакет `openjdk-25-jre-headless` |
| Kafka | `4.3.1`, дистрибутив `kafka_2.13-4.3.1.tgz` |
| Программы | `/opt/kafka-4.3.1`, ссылка `/opt/kafka` |
| Конфигурация | `/etc/kafka/server.properties` |
| Данные Kafka | `/data/kafka` |
| Метаданные KRaft | `/data/kafka-metadata` |
| Системный пользователь службы | `kafka` |
| Служба | `kafka.service` |
| Адрес для клиентов | `192.168.0.34:9092` |
| Controller | `127.0.0.1:9093` |

Пароли предназначены для учебной ВМ в локальной сети. Kafka использует клиентский listener `PLAINTEXT`; в этой конфигурации учётные записи Ubuntu применяются к SSH/SFTP, а Kafka не запрашивает их пароли.

## Общая подготовка VirtualBox

### Базовая Ubuntu

Если базовая ВМ уже создана, использовать её. Иначе установить Ubuntu Server с пользователем `ubuntu`, паролем `ubuntu` и правом sudo. Для установки достаточно одного адаптера NAT и Интернета через DHCP. После установки извлечь ISO и выключить ВМ.

### Полный клон master2

В VirtualBox нажать правой кнопкой по выключенной базовой ВМ → **Clone / Клонировать**:

1. Имя клона — `master2`.
2. **Generate new MAC addresses for all network adapters**.
3. **Full clone / Полный клон**.
4. Для клона выделить 4 ГБ памяти, 2 процессора и диск от 30 ГБ.

Адаптер 1: **NAT**, включён **Cable Connected**. В **Advanced → Port Forwarding**:

| Name | Protocol | Host IP | Host Port | Guest IP | Guest Port |
| --- | --- | --- | --- | --- | --- |
| ssh | TCP | `127.0.0.1` | `2223` | пусто | `22` |

Адаптер 2: **Bridged Adapter / Сетевой мост**, выбрать активный физический адаптер Windows и включить **Cable Connected**. В текущем стенде используется `Intel(R) Wi-Fi 7 BE201 320MHz`.

Запустить клон и войти через консоль VirtualBox как `ubuntu/ubuntu`. Базовую ВМ оставить выключенной. Проверить интерфейсы:

```bash
ip -br link
```

Ниже NAT обозначен `enp0s3`, мост — `enp0s8`. При других именах заменить их в конфигурации. Адрес `192.168.0.34` должен быть свободен в сети `192.168.0.0/24`.

## Вариант 1. Ручная установка

### 1. Зеркало Яндекса и системные пакеты

В Ubuntu 26.04 репозитории задаются в `/etc/apt/sources.list.d/ubuntu.sources`. Заменить его содержимое:

```bash
sudo nano /etc/apt/sources.list.d/ubuntu.sources
```

```text
Types: deb
URIs: https://mirror.yandex.ru/ubuntu/
Suites: resolute resolute-updates resolute-backports resolute-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

Для другой версии Ubuntu использовать её кодовое имя вместо `resolute`.

В этом стенде загрузки выполняются по IPv4:

```bash
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99-lab-ipv4 >/dev/null
sudo apt update
sudo apt install -y openjdk-25-jre-headless openssh-server netplan.io locales curl tar
java -version
```

### 2. Имя и идентификаторы клона

```bash
sudo hostnamectl set-hostname master2
sudo nano /etc/hosts
```

В `/etc/hosts` должна быть строка:

```text
127.0.1.1 master2
```

При первичной подготовке полного клона создать собственный machine-id и ключи сервера SSH:

```bash
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo ssh-keygen -A
```

Эти действия выполняются один раз на новом клоне. Если `locale -a` не содержит `en_US.utf8`, открыть `/etc/locale.gen`, включить строку `en_US.UTF-8 UTF-8` и выполнить:

```bash
sudo locale-gen
```

### 3. Netplan

На новой учебной ноде убрать исходные YAML-конфигурации, чтобы DHCP на мосте не конфликтовал со статическим адресом:

```bash
sudo rm -f /etc/netplan/*.yaml /etc/netplan/*.yml
sudo nano /etc/netplan/01-netcfg.yaml
```

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
      dhcp6: false
    enp0s8:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.0.34/24
```

Маршрут по умолчанию и DNS получает NAT. На мосте второй шлюз и DNS не задаются.

```bash
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg >/dev/null
sudo chmod 600 /etc/netplan/01-netcfg.yaml
sudo netplan generate
sudo netplan apply
ip -br address
ip route
```

### 4. Admin, root и sudo

Создать пользователя `admin`; в диалоге указать пароль `admin`:

```bash
sudo adduser admin
sudo usermod -aG sudo admin
sudo passwd root
```

Для root задать пароль `root`. Настроить sudo:

```bash
sudo visudo -f /etc/sudoers.d/90-lab-admin
```

Содержимое:

```text
admin ALL=(ALL) NOPASSWD: ALL
```

```bash
sudo chmod 440 /etc/sudoers.d/90-lab-admin
```

### 5. Открытый ключ Windows и SSH

На Windows вывести существующий открытый ключ:

```powershell
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
```

Если ключа ещё нет, сначала выполнить `ssh-keygen -t ed25519`. Закрытый `id_ed25519` остаётся на Windows.

В консоли Ubuntu создать файл для admin и вставить в него всю строку открытого ключа:

```bash
sudo install -d -m 700 -o admin -g admin /home/admin/.ssh
sudo nano /home/admin/.ssh/authorized_keys
sudo chown admin:admin /home/admin/.ssh/authorized_keys
sudo chmod 600 /home/admin/.ssh/authorized_keys
sudo install -d -m 700 /root/.ssh
sudo cp /home/admin/.ssh/authorized_keys /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys
sudo install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
sudo cp /home/admin/.ssh/authorized_keys /home/ubuntu/.ssh/authorized_keys
sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
sudo chmod 600 /home/ubuntu/.ssh/authorized_keys
sudo nano /etc/ssh/sshd_config.d/00-lab.conf
```

Содержимое `/etc/ssh/sshd_config.d/00-lab.conf`:

```text
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
```

```bash
sudo /usr/sbin/sshd -t
sudo systemctl enable --now ssh
sudo systemctl restart ssh
```

Настройки Windows и FileZilla приведены в общем разделе подключений ниже.

### 6. Получение готового дистрибутива Kafka

```bash
sudo mkdir -p /usr/local/src
sudo curl --ipv4 --fail --location --retry 3 --continue-at - \
  --output /usr/local/src/kafka_2.13-4.3.1.tgz \
  https://mirror.yandex.ru/mirrors/apache/kafka/4.3.1/kafka_2.13-4.3.1.tgz
```

Если скачивание на ВМ медленное, скачать файл на Windows по ссылке выше или через PowerShell:

```powershell
curl.exe --ipv4 --fail --location --retry 3 --continue-at - `
  --output "$env:USERPROFILE\Downloads\kafka_2.13-4.3.1.tgz" `
  "https://mirror.yandex.ru/mirrors/apache/kafka/4.3.1/kafka_2.13-4.3.1.tgz"
```

В репозитории также есть `download-kafka.ps1` с этой загрузкой. Через FileZilla подключиться от root, слева открыть Downloads, справа `/usr/local/src` и перетащить `.tgz` напрямую в этот каталог.

Распаковать программы:

```bash
sudo mkdir -p /opt/kafka-4.3.1
sudo tar -xzf /usr/local/src/kafka_2.13-4.3.1.tgz \
  -C /opt/kafka-4.3.1 --strip-components=1
sudo ln -s /opt/kafka-4.3.1 /opt/kafka
```

### 7. Пользователь службы и конфигурация Kafka

```bash
sudo useradd --system --create-home --home-dir /var/lib/kafka --shell /usr/sbin/nologin kafka
sudo install -d -m 750 -o kafka -g kafka /etc/kafka /data/kafka /data/kafka-metadata /var/log/kafka
sudo nano /etc/kafka/server.properties
```

Содержимое:

```properties
process.roles=broker,controller
node.id=2
controller.quorum.bootstrap.servers=127.0.0.1:9093
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://127.0.0.1:9093
advertised.listeners=PLAINTEXT://192.168.0.34:9092
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
inter.broker.listener.name=PLAINTEXT
controller.listener.names=CONTROLLER
log.dirs=/data/kafka
metadata.log.dir=/data/kafka-metadata
num.partitions=1
default.replication.factor=1
min.insync.replicas=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
```

`advertised.listeners` должен содержать адрес, доступный клиентам, в этой схеме — IP моста. Параметр `log.dirs` обозначает каталог данных Kafka. Для этой одиночной ноды фактор репликации внутренних topics равен `1`.

```bash
sudo chown root:kafka /etc/kafka/server.properties
sudo chmod 640 /etc/kafka/server.properties
```

### 8. Однократная инициализация KRaft

На новой ноде каталоги `/data/kafka` и `/data/kafka-metadata` должны быть пустыми. Если кластер уже инициализирован и имеются `meta.properties`, этот шаг пропустить. Не удалять данные для повторного запуска службы.

```bash
KAFKA_CLUSTER_ID="$(sudo -u kafka env LOG_DIR=/var/log/kafka /opt/kafka/bin/kafka-storage.sh random-uuid)"
sudo -u kafka env LOG_DIR=/var/log/kafka \
  /opt/kafka/bin/kafka-storage.sh format --standalone \
  --cluster-id "$KAFKA_CLUSTER_ID" \
  --config /etc/kafka/server.properties
```

Используется KRaft с динамическим quorum и одним controller. ZooKeeper для этого варианта не устанавливается. [Документация инициализации KRaft](https://kafka.apache.org/43/operations/kraft/).

### 9. Служба systemd

```bash
sudo nano /etc/systemd/system/kafka.service
```

```ini
[Unit]
Description=Apache Kafka 4.3.1 (KRaft)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=kafka
Group=kafka
Environment="KAFKA_HEAP_OPTS=-Xms1g -Xmx1g"
Environment="LOG_DIR=/var/log/kafka"
ExecStart=/opt/kafka/bin/kafka-server-start.sh /etc/kafka/server.properties
Restart=on-failure
RestartSec=5
KillSignal=SIGTERM
SuccessExitStatus=143
TimeoutStopSec=120
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
```

```bash
sudo nano /etc/profile.d/kafka.sh
```

```bash
export KAFKA_HOME=/opt/kafka
export PATH=$KAFKA_HOME/bin:$PATH
```

Для очистки штатных файлов журналов через 30 дней:

```bash
echo 'd /var/log/kafka 0750 kafka kafka 30d -' | sudo tee /etc/tmpfiles.d/kafka.conf >/dev/null
sudo systemctl enable --now systemd-tmpfiles-clean.timer
sudo systemctl daemon-reload
sudo systemctl enable --now kafka
```

После первичной настройки клона перезагрузить его, чтобы все процессы использовали новый machine-id:

```bash
sudo reboot
```

## Вариант 2. Установка через Ansible

### 1. Минимальная подготовка клона

Выполнить общую подготовку VirtualBox: полный клон с новыми MAC, имя `master2`, NAT с портом `2223`, сетевой мост. В консоли войти как `ubuntu/ubuntu`.

Перевести стандартные репозитории Ubuntu на зеркало Яндекса:

```bash
sudo sed -i -E \
  's#https?://([a-z]{2}\.)?archive\.ubuntu\.com/ubuntu/?#https://mirror.yandex.ru/ubuntu/#g; s#https?://security\.ubuntu\.com/ubuntu/?#https://mirror.yandex.ru/ubuntu/#g' \
  /etc/apt/sources.list.d/ubuntu.sources
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99-lab-ipv4 >/dev/null
sudo apt update
sudo apt install -y git ansible-core
git clone https://github.com/tsenturion/postgresql-ansible-lab.git
cd postgresql-ansible-lab
cp local-kafka.example.yml local-kafka.yml
nano local-kafka.yml
```

### 2. Индивидуальные настройки

На Windows вывести открытый ключ из `id_ed25519.pub`, как в ручном варианте, и вставить его в `local-kafka.yml`:

```yaml
node_hostname: master2
nat_interface: enp0s3
bridge_interface: enp0s8
bridge_address: 192.168.0.34/24
ssh_public_keys:
  - 'ssh-ed25519 ВАШ_ОТКРЫТЫЙ_КЛЮЧ'
```

`local-kafka.yml` игнорируется Git. Общие параметры находятся в `kafka-settings.yml`; значения индивидуального файла имеют приоритет. Зеркала Яндекса включены в репозиторий как настройки:

```yaml
ubuntu_apt_mirror: https://mirror.yandex.ru/ubuntu/
kafka_download_mirror: https://mirror.yandex.ru/mirrors/apache/kafka
```

Для другой ноды изменить `node_hostname` и `bridge_address`. `kafka_advertised_host` по умолчанию вычисляется из IP в `bridge_address`. Имя ВМ в VirtualBox задаётся отдельно на Windows. Если изменять адрес уже работающей ноды, запускать плейбук через консоль или SSH через NAT, затем обновить адреса клиентских подключений.

### 3. Запуск автоматизации

```bash
bash bootstrap-kafka.sh
```

При запросе sudo ввести пароль `ubuntu`. Скрипт устанавливает недостающие Ansible и `passlib`, задаёт локаль `C.UTF-8` и запускает `kafka.yml` от root через sudo. Для Kafka используются встроенные модули Ansible: коллекция `community.postgresql` не требуется.

Плейбук выполняет этапы ручного варианта: hostname, локаль, отдельные идентификаторы клона, admin/root, sudo, ключи SSH, Netplan, зеркало Ubuntu, Java, загрузка готового дистрибутива, конфигурация Kafka, первичная инициализация KRaft и служба. PostgreSQL на `master2` не устанавливается.

Если архив предварительно передан через FileZilla в `/usr/local/src/kafka_2.13-4.3.1.tgz`, скачивание пропускается. Автоматическая загрузка сохраняется сначала в `.part` и после успешного завершения переименовывается; прерванную загрузку можно возобновить повторным запуском.

В конце плейбук проверяет API брокера, объявляемый адрес и состояние quorum. После успешного первого запуска с `failed=0` и `unreachable=0`:

```bash
sudo reboot
```

### 4. Повторное применение

От пользователя ubuntu:

```bash
cd ~/postgresql-ansible-lab
git pull --ff-only
bash bootstrap-kafka.sh
```

Существующие каталоги Kafka повторно не форматируются. Индивидуальные параметры `local-kafka.yml` сохраняются при обновлении репозитория.

## Подключения с Windows

### SSH

В `%USERPROFILE%\.ssh\config`:

```sshconfig
Host master2
    HostName 192.168.0.34
    User admin
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host master2-admin
    HostName 127.0.0.1
    User admin
    Port 2223

Host master2-root
    HostName 127.0.0.1
    User root
    Port 2223
```

В примерах NAT используется `127.0.0.1`, чтобы исключить выбор IPv6-адреса `::1` для `localhost`.

```powershell
ssh master2
ssh master2-admin
ssh master2-root
```

Вход с соответствующим ключом не запрашивает пароль учётной записи Ubuntu. Если закрытый ключ защищён парольной фразой, использовать SSH-agent или ввести эту фразу при подключении.

Если заменена предыдущая ВМ `master2`, удалить её старые записи только после проверки, что адрес относится к своему новому клону:

```powershell
ssh-keygen -R "192.168.0.34"
ssh-keygen -R "[127.0.0.1]:2223"
ssh-keygen -R "[localhost]:2223"
```

При первом подключении принять ключ нового сервера. В VS Code использовать **Remote-SSH: Connect to Host... → master2** или `master2-admin` для NAT.

### FileZilla

**File → Site Manager → New site**:

| Поле | Значение |
| --- | --- |
| Protocol | SFTP — SSH File Transfer Protocol |
| Host | `127.0.0.1` |
| Port | `2223` |
| Logon Type | Normal |
| User | `root` |
| Password | `root` |

Нажать **Connect** и при первом подключении принять ключ своей ВМ. Дополнительная настройка ключей в FileZilla для этого входа по паролю не требуется. Root может напрямую записывать в `/usr/local/src` и `/etc/kafka`.

### Адрес Kafka для клиентов

Использовать `bootstrap.servers=192.168.0.34:9092` с Windows и других нод локальной сети. Kafka возвращает этот же адрес через `advertised.listeners`, поэтому он должен быть доступен клиенту.

Проброс `2223` обслуживает SSH. Для клиентского соединения Kafka в этой инструкции используется мост и порт `9092`. DBeaver применяется к PostgreSQL; для этой установки Kafka соединение в DBeaver не создаётся.

## Проверка установки

На ноде:

```bash
hostnamectl --static
ip -br address
ip route
java -version
systemctl is-active kafka
systemctl is-enabled kafka
ss -lnt | grep -E ':9092|:9093'
sudo -u kafka env LOG_DIR=/var/log/kafka \
  /opt/kafka/bin/kafka-topics.sh --version
sudo -u kafka env LOG_DIR=/var/log/kafka \
  /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server 192.168.0.34:9092
sudo -u kafka env LOG_DIR=/var/log/kafka \
  /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server 192.168.0.34:9092 describe --status
```

С Windows:

```powershell
Test-NetConnection 192.168.0.34 -Port 9092
```

Ожидаются hostname `master2`, адрес моста `.34`, единственный IPv4-маршрут по умолчанию через NAT, Java 25, Kafka 4.3.1, активная служба с автозапуском и ответ API брокера. В quorum `LeaderId` должен соответствовать `node.id=2`.

## Диагностика установки

Если служба не запускается:

```bash
systemctl status kafka --no-pager
sudo journalctl -u kafka -n 100 --no-pager
sudo ls -l /var/log/kafka
sudo -u kafka test -r /etc/kafka/server.properties
sudo -u kafka test -w /data/kafka
sudo -u kafka test -w /data/kafka-metadata
```

Если порт доступен, но клиент не подключается, проверить `advertised.listeners`, доступность указанного IP и порт `9092`. При активном UFW разрешить SSH и Kafka из локальной подсети:

```bash
sudo ufw allow 22/tcp
sudo ufw allow from 192.168.0.0/24 to any port 9092 proto tcp
```

Включать UFW для выполнения этой инструкции отдельно не требуется. Kafka останавливается и запускается штатно через `sudo systemctl stop kafka` и `sudo systemctl start kafka`; повторное форматирование для перезапуска не выполняется.

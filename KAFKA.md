# Установка Kafka на master2

Устанавливается готовый дистрибутив Apache Kafka 4.3.1 с зеркала Яндекса. Сборка исходного кода не требуется. Используется одна нода в режиме KRaft с ролями broker и controller.

## Параметры

| Компонент | Значение |
| --- | --- |
| Нода | master2 |
| Адрес моста | 192.168.0.34/24 |
| SSH через NAT | 127.0.0.1:2223 → 22 |
| Пользователь Ubuntu | admin / admin, sudo без пароля |
| Root Ubuntu | root / root |
| Kafka | 4.3.1, Java 25 |
| Дистрибутив | https://mirror.yandex.ru/mirrors/apache/kafka/ |
| Пакеты Ubuntu | https://mirror.yandex.ru/ubuntu/ |
| Программы | /opt/kafka-4.3.1, ссылка /opt/kafka |
| Конфигурация | /etc/kafka/server.properties |
| Данные | /data/kafka |
| Метаданные KRaft | /data/kafka-metadata |
| Служба | kafka.service |
| Порт клиентов | 192.168.0.34:9092 |
| Порт controller | 127.0.0.1:9093 |

## Запуск через Ansible

Создать полный клон базовой Ubuntu с пользователем `ubuntu/ubuntu`, новыми MAC-адресами, именем `master2`, NAT с пробросом `127.0.0.1:2223 → 22` и мостом через активный адаптер Windows. Достаточно 4 ГБ памяти и 2 процессоров. Базовую ВМ оставить выключенной.

В консоли клона от пользователя ubuntu перевести стандартные репозитории Ubuntu на зеркало Яндекса:

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

В `local-kafka.yml` указать hostname, свободный IP и открытый ключ Windows:

```yaml
node_hostname: master2
bridge_address: 192.168.0.34/24
ssh_public_keys:
  - 'ssh-ed25519 ВАШ_ОТКРЫТЫЙ_КЛЮЧ'
```

Запустить:

```bash
bash bootstrap-kafka.sh
```

Плейбук настроит hostname, пользователей, SSH, открытые ключи и Netplan, установит Java, скачает и распакует Kafka, один раз инициализирует пустые каталоги KRaft, создаст службу и проверит API брокера и quorum. PostgreSQL на master2 не устанавливается. Коллекция community.postgresql для плейбука Kafka не требуется.

После первого успешного запуска:

```bash
sudo reboot
```

`local-kafka.yml` игнорируется Git. Общие параметры находятся в `kafka-settings.yml`: здесь заданы оба зеркала Яндекса. Индивидуальные значения в `local-kafka.yml` имеют приоритет. Для другого IP изменяется `bridge_address`; объявляемый адрес Kafka вычисляется из него. Для другого hostname изменить `node_hostname`, а имя ВМ в VirtualBox задать отдельно.

При необходимости скачать архив на Windows вручную:

```powershell
.\download-kafka.ps1
```

Скрипт сохраняет архив в Downloads. Через FileZilla можно передать его от root в `/usr/local/src/kafka_2.13-4.3.1.tgz` и повторить запуск плейбука: существующий файл не скачивается заново.

## Проверка

```bash
hostnamectl --static
ip -br address
ip route
java -version
systemctl is-active kafka
systemctl is-enabled kafka
sudo -u kafka env LOG_DIR=/var/log/kafka \
  /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server 192.168.0.34:9092
sudo -u kafka env LOG_DIR=/var/log/kafka \
  /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server 192.168.0.34:9092 describe --status
```

Повторное применение от ubuntu:

```bash
cd ~/postgresql-ansible-lab
git pull --ff-only
bash bootstrap-kafka.sh
```

Каталоги Kafka повторно не форматируются. Netplan сохраняет единственный IPv4-маршрут по умолчанию и DNS на NAT-интерфейсе. Используется `/etc/netplan/01-netcfg.yaml`.

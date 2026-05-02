#!/bin/bash

# Script para instalação do cacti

# Função para exibir títulos no terminal
azul() {
    echo -e "\n\e[1;0;34m>>> $1 <<<\e[0m"
}
verde() {
    echo -e "\n\e[1;0;32m>>> $1 <<<\e[0m"
}
amarelo() {
    echo -e "\n\e[1;0;33m>>> $1 <<<\e[0m"
}
vermelho() {
    echo -e "\n\e[1;0;31m!!! $1 !!!\e[0m"
}
roxo() {
    echo -e "\n\e[1;0;35m>>> $1 <<<\e[0m"
}

# Mensagem de erro caso algum código apresente erro
set -euo pipefail
sleep 2
trap 'vermelho "❌ ERRO NA LINHA $LINENO. SCRIPT INTERROMPIDO..."; exit 1' ERR
sleep 2

# Atualizando os pacotes
amarelo "ATUALIZANDO PACOTES"
sleep 2
sudo apt update
sleep 2
verde "PACOTES ATUALIZADOS COM SUCESSO"
sleep 2

# Instalando pacotes Apache, MySQL e PHP na máquina
amarelo "INSTALANDO PACOTES APACHE2, MYSQL E PHP"
sleep 2
sudo apt install -y apache2 mariadb-server mariadb-client php-mysql libapache2-mod-php
sleep 2
verde "PACOTES INSTALADOS COM SUCESSO"
sleep 2

# Instalado extensões PHP
amarelo "INSTALANDO EXTENSÕES PHP"
sleep 2
sudo apt install -y php-xml php-ldap php-mbstring php-gd php-gmp
sleep 2
verde "EXTENSÃO INSTALADA COM SUCESSO"
sleep 2

# Instalando SNMP e RRDtool
amarelo "INSTALANDO SNMP E RROTOOL"
sleep 2
sudo apt install -y snmp php-snmp rrdtool librrds-perl
sleep 2
verde "INSTALAÇÃO CONCLUÍDA COM SUCESSO"
sleep 2

# Alterações no MySQL
amarelo "ALTERANDO CONFIGURAÇÕES NO MYSQL"
if ! grep -q "innodb_buffer_pool_size" "/etc/mysql/mariadb.conf.d/50-server.cnf";
then
sleep 2

# Inserindo alterações na linha 10
CONFIG="/etc/mysql/mariadb.conf.d/50-server.cnf"

sed -i '/\[mysqld\]/a innodb_io_capacity_max = 10000' $CONFIG
sed -i '/\[mysqld\]/a innodb_io_capacity = 5000' $CONFIG
sed -i '/\[mysqld\]/a innodb_write_io_threads = 16' $CONFIG
sed -i '/\[mysqld\]/a innodb_read_io_threads = 32' $CONFIG
sed -i '/\[mysqld\]/a innodb_flush_log_at_timeout = 3' $CONFIG
sed -i '/\[mysqld\]/a innodb_buffer_pool_size = 512M' $CONFIG
sed -i '/\[mysqld\]/a innodb_large_prefix = 1' $CONFIG
sed -i '/\[mysqld\]/a innodb_file_format = Barracuda' $CONFIG
sed -i '/\[mysqld\]/a join_buffer_size = 64M' $CONFIG
sed -i '/\[mysqld\]/a tmp_table_size = 64M' $CONFIG
sed -i '/\[mysqld\]/a max_heap_table_size = 128M' $CONFIG
sed -i '/\[mysqld\]/a collation-server = utf8mb4_unicode_ci' $CONFIG
verde "ALTERAÇÕES CONLCUÍDAS COM SUCESSO"
sleep 2


# Avisar que já foi configurado
else
roxo "CONFIGURAÇÕES DO MYSQL JÁ ESTÃO PRESENTES. PULANDO..."
fi
sleep 2

# Definindo local no arquivo de configuração do PHP
amarelo "DEFININDO VALORES NA CONFIGURAÇÃO DO PHP"
sleep 2
sed -i 's|^;*date.timezone.*|date.timezone = America/Sao_Paulo|' /etc/php/8.1/apache2/php.ini
sed -i 's|^memory_limit.*|memory_limit = 512M|' /etc/php/8.1/apache2/php.ini
sed -i 's|^max_execution_time.*|max_execution_time = 60|' /etc/php/8.1/apache2/php.ini

sed -i 's|^;*date.timezone.*|date.timezone = America/Sao_Paulo|' /etc/php/8.1/cli/php.ini
sed -i 's|^memory_limit.*|memory_limit = 512M|' /etc/php/8.1/cli/php.ini
sed -i 's|^max_execution_time.*|max_execution_time = 60|' /etc/php/8.1/cli/php.ini
sleep 2
verde "VALORES DEFINIDOS COM SUCESSO"
sleep 2

# Reiniciando o mariadb
amarelo "REINICIANDO O MARIADB"
sleep 2
sudo systemctl restart mariadb
sleep 2
verde "REINICIALIZAÇÃO CONCLUÍDA COM SUCESSO"

# Crianção de um banco de dados para instalação do cacti
amarelo "CRIANDO UM BANCO DE DADOS"
sleep 2
# Perguntar dados
roxo "DIGITE O NOME DO BANCO E AGUARDE UM MOMENTO"
read DB_NAME
sleep 2
roxo "DIGITE O USUÁRIO DO BANCO E AGUARDE UM MOMENTO"
read DB_USER
sleep 2

# Perguntar senha com validação
while true; do
    roxo "DIGITE A SENHA DO BANCO E AGUARDE UM MOMENTO"
    read -s DB_PASS
    echo
    sleep 2

    roxo "CONFIRME A SENHA E AGUARDE UM MOMENTO"
    read -s DB_PASS2
    echo
    sleep 2

    if [ "$DB_PASS" = "$DB_PASS2" ]; then
        verde "SENHA CONFIRMADA"
        break
    else
        vermelho "AS SENHAS NÃO COINCIDEM"
        sleep 2
    fi
done

# Criar banco e usuário
amarelo "CRIANDO USUÁRIO"
sleep 2

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
sleep 2
verde "BANCO E USUÁRIO CRIADOS COM SUCESSO"
sleep 2

# Importando dados de timezone
amarelo "IMPORTANDO DADOS DE TIMEZONE..."
sleep 2
if mysql -u root -e "SELECT * FROM mysql.time_zone_name LIMIT 1" | grep -q "MET"; then
    echo "TIMEZONE JÁ CONFIGURADO, PULANDO..."
else
    mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql
fi

sleep 2

# Permissões no MYSQL
amarelo "CONCEDENDO PERMISSÕES"
sleep 2

mysql -u root <<EOF
GRANT SELECT ON mysql.time_zone_name TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
sleep 2
verde "PERMISSÕES CONCEDIDAS"
sleep 2

# Verificando se já possui Cacti
if [ -d "/opt/cacti/index.php" ]; then
    roxo "CACTI JÁ ESTÁ INSTALADO, PULANDO DOWNLOAD..."
else
    amarelo "BAIXANDO E INSTALANDO O CACTI..."
    wget https://www.cacti.net/downloads/cacti-latest.tar.gz
sleep 2

# Extraindo o arquivo
amarelo "EXTRAINDO O ARQUIVO..."
sleep 2
 tar -zxvf cacti-latest.tar.gz
sleep 2
fi

# Movendo para /opt
amarelo "MOVENDO CACTI PARA /opt..."
sleep 2

if [ -d "/opt/cacti" ]; then
    roxo "CACTI JÁ EXISTE, REMOVENDO VERSÃO ANTIGA..."
    rm -rf /opt/cacti
fi
sleep 2

# Cria diretório novamente
mkdir -p /opt/cacti
mv cacti-*/* /opt/cacti

# Importe os dados padrão do banco de dados do Cacti
amarelo "IMPORTANDO BANCO DO CACTI..."
sleep 2

SQL_FILE=$(find /opt/cacti -name cacti.sql | head -n 1)

if [ -z "$SQL_FILE" ]; then
    vermelho "ERRO: CACTI.SQL NÃO ENCONTRADO!"
    exit 1
fi

mysql -u root $DB_NAME < "$SQL_FILE"

verde "BANCO IMPORTADO COM SUCESSO"
sleep 2

amarelo "CONFIGURANDO ARQUIVO DO CACTI..."
sleep 2

CONFIG="/opt/cacti/include/config.php"

if [ ! -f "$CONFIG" ]; then
    cp /opt/cacti/include/config.php.dist "$CONFIG"
fi

sed -i "s|\$database_default *=.*|\$database_default = \"$DB_NAME\";|" $CONFIG
sed -i "s|\$database_username *=.*|\$database_username = \"$DB_USER\";|" $CONFIG
sed -i "s|\$database_password *=.*|\$database_password = \"$DB_PASS\";|" $CONFIG
sed -i "s|\$database_hostname *=.*|\$database_hostname = \"localhost\";|" $CONFIG

verde "CONFIGURAÇÃO CONCLUÍDA"
sleep 2

# Cron do Cacti
amarelo "CONFIGURANDO CRON..."
sleep 2

echo "*/5 * * * * www-data php /opt/cacti/poller.php > /dev/null 2>&1" > /etc/cron.d/cacti
chmod 644 /etc/cron.d/cacti

verde "CRON CONFIGURADO COM SUCESSO"
sleep 2

# Apache - configuração completa
amarelo "CRIANDO CONFIGURAÇÃO DO APACHE..."
sleep 2

cat <<EOF > /etc/apache2/sites-available/cacti.conf
Alias /cacti /opt/cacti

<Directory /opt/cacti>
    Options +FollowSymLinks
    AllowOverride None

    <IfVersion >= 2.3>
        Require all granted
    </IfVersion>

    <IfVersion < 2.3>
        Order Allow,Deny
        Allow from all
    </IfVersion>

    AddType application/x-httpd-php .php

    <IfModule mod_php.c>
        php_flag magic_quotes_gpc Off
        php_flag short_open_tag On
        php_flag register_globals Off
        php_flag register_argc_argv On
        php_flag track_vars On

        php_value mbstring.func_overload 0
        php_value include_path .
    </IfModule>

    DirectoryIndex index.php
</Directory>
EOF

verde "CONFIGURAÇÃO DO APACHE CRIADA"
sleep 2

# Ativando o site
amarelo "ATIVANDO SITE DO CACTI..."
sleep 2

a2ensite cacti.conf
a2enmod rewrite

# Reiniciando apache
amarelo "REINICIANDO APACHE..."
sleep 2

systemctl restart apache2

verde "APACHE REINICIADO COM SUCESSO"
sleep 2

# Configurando log e permissões
amarelo "CONFIGURANDO PERMISSÕES..."
sleep 2

mkdir -p /opt/cacti/log
touch /opt/cacti/log/cacti.log

chown -R www-data:www-data /opt/cacti/

verde "PERMISSÕES CONFIGURADAS"
sleep 2

# Final
verde "PRONTO! CACTI INSTALADO E CONFIGURADO COM SUCESSO!!!"
echo
echo "ACESSE NO NAVEGADOR:"
echo "http://SEU_IP/cacti"


vermelho "SCRIPT DESENVOLVIDO POR: FILIPE NONEMACHER @filipe.fnl E JOÃO HENRIQUE @fig_joao77"

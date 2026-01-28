#!/bin/bash

# 1. VERIFICAÇÃO DE ROOT
if [ "$EUID" -ne 0 ]; then 
  echo "ERRO: Precisa de sudo! (sudo ./solucao_final.sh)"
  exit 1
fi

echo "=== CORREÇÃO VSFTPD (CONFIGURAÇÃO LIMPA) ==="

# 2. PARAR TUDO
systemctl stop vsftpd 2>/dev/null
systemctl stop vsftpd.socket 2>/dev/null

# 3. GARANTIR DIRETÓRIO
FTP_DIR="/mnt/99f0132f-3904-46b2-bd4c-cb7ee22f964a/FTP"
mkdir -p "$FTP_DIR"
chown -R ajmn:ajmn "$FTP_DIR"
chmod 755 "$FTP_DIR"

# 4. GARANTIR CERTIFICADO
mkdir -p /etc/ssl/private
if [ ! -f /etc/ssl/private/vsftpd.pem ]; then
    echo "--> Gerando certificado..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/vsftpd.pem \
        -out /etc/ssl/private/vsftpd.pem \
        -subj "/C=BR/CN=vsftpd" 2>/dev/null
fi

# 5. ESCREVER CONFIGURAÇÃO (SEM OPÇÕES PROBLEMÁTICAS)
echo "--> Criando /etc/vsftpd.conf..."
CONF="/etc/vsftpd.conf"

# Começa do zero
echo "anonymous_enable=NO" > $CONF
echo "local_enable=YES" >> $CONF
echo "write_enable=YES" >> $CONF
echo "local_umask=022" >> $CONF
echo "dirmessage_enable=YES" >> $CONF
echo "xferlog_enable=YES" >> $CONF
echo "connect_from_port_20=YES" >> $CONF

# REMOVIDO: Qualquer opção utf8 (O Linux já lida nativamente)
# REMOVIDO: listen_ipv6 (Deixar o padrão do sistema)

echo "local_root=$FTP_DIR" >> $CONF
echo "chroot_local_user=YES" >> $CONF
echo "allow_writeable_chroot=YES" >> $CONF

echo "ssl_enable=YES" >> $CONF
echo "rsa_cert_file=/etc/ssl/private/vsftpd.pem" >> $CONF
echo "rsa_private_key_file=/etc/ssl/private/vsftpd.pem" >> $CONF
echo "force_local_data_ssl=YES" >> $CONF
echo "force_local_logins_ssl=YES" >> $CONF
echo "require_ssl_reuse=NO" >> $CONF
echo "ssl_ciphers=HIGH" >> $CONF

echo "pasv_enable=YES" >> $CONF
echo "pasv_min_port=40000" >> $CONF
echo "pasv_max_port=50000" >> $CONF
echo "pasv_addr_resolve=YES" >> $CONF

echo "listen=YES" >> $CONF
echo "pam_service_name=vsftpd" >> $CONF
echo "seccomp_sandbox=NO" >> $CONF

# 6. FIREWALL
ufw allow 20/tcp >/dev/null
ufw allow 21/tcp >/dev/null
ufw allow 40000:50000/tcp >/dev/null
ufw reload >/dev/null

# 7. REINICIAR
echo "--> Reiniciando..."
systemctl daemon-reload
systemctl restart vsftpd

# 8. VERIFICAR
sleep 2
if systemctl is-active --quiet vsftpd; then
    echo ""
    echo "✅ SUCESSO! SERVIDOR ONLINE."
    echo "Tente conectar agora."
else
    echo ""
    echo "❌ FALHA. Log:"
    systemctl status vsftpd --no-pager
fi
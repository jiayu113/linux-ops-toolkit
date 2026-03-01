#!/bin/bash

set -e

NGINX_VERSION="1.26.2"
NGINX_PREFIX="/usr/local/nginx"
SRC_DIR="/usr/local/src"
WEB_ROOT="/data/www/static"

echo "========== Nginx 手动安装脚本 =========="

# 必须 root
if [ "$(id -u)" != "0" ]; then
  echo " 请使用 root 用户执行"
  exit 1
fi

# 安装依赖
echo "▶ 安装依赖..."
apt update
apt install -y \
build-essential \
libpcre3 libpcre3-dev \
zlib1g zlib1g-dev \
libssl-dev \
wget

# 下载源码
echo "▶ 下载 Nginx ${NGINX_VERSION}..."
mkdir -p ${SRC_DIR}
cd ${SRC_DIR}

if [ ! -f nginx-${NGINX_VERSION}.tar.gz ]; then
  wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
fi

tar -zxf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}

# 编译安装
echo "▶ 编译 Nginx..."
./configure \
--prefix=${NGINX_PREFIX} \
--with-http_ssl_module \
--with-http_gzip_static_module

make -j$(nproc)
make install

# 创建软链接
ln -sf ${NGINX_PREFIX}/sbin/nginx /usr/bin/nginx

# 创建站点目录
echo "▶ 创建站点目录..."
mkdir -p ${WEB_ROOT}

cat > ${WEB_ROOT}/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Nginx Installed</title>
</head>
<body>
  <h1>Nginx 手动安装成功 </h1>
  <p>部署时间：$(date)</p>
</body>
</html>
EOF

chmod -R 755 /data/www

# 修改 nginx.conf
echo "▶ 配置 Nginx..."
cat > ${NGINX_PREFIX}/conf/nginx.conf <<EOF
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 80;
        server_name localhost;

        location / {
            root ${WEB_ROOT};
            index index.html;
        }
    }
}
EOF

# 检查并启动
echo " 启动 Nginx..."
nginx -t
nginx || nginx -s reload

echo " Nginx 安装完成！"
echo " 访问：http://服务器IP"

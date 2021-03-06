FROM alpine:3.9

LABEL SERVICE_NAME="nginx"

#HEALTHCHECK CMD docker-healthcheck

ARG TZ="Asia/Shanghai"

# Docker Build Arguments
ARG RESTY_VERSION="1.19.3.1"
ARG RESTY_LUAROCKS_VERSION="2.4.3"
ARG RESTY_OPENSSL_VERSION="1.0.2l"
ARG RESTY_PCRE_VERSION="8.40"
ARG RESTY_J="1"
ARG RESTY_NPS_VERSION="1.12.34.2"
ARG RESTY_CONFIG_OPTIONS="\
    --prefix=/usr/local \
    --conf-path=/etc/nginx/nginx.conf \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-ipv6 \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    --without-http_redis2_module \
    --without-http_redis_module \
    --without-http_rds_csv_module \
    --without-http_rds_json_module \
    # 对应上面添加的模块目录
    #--add-module=/opt/ngx_http_proxy_connect_module \
    --add-dynamic-module=/opt/ngx_http_proxy_connect_module \
    "

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"

ARG CONTAINER_PACKAGE_URL="mirrors.aliyun.com"

# https://github.com/chobits/ngx_http_proxy_connect_module下载的主分支包
COPY ./ngx_http_proxy_connect_module  /opt/ngx_http_proxy_connect_module

#COPY ./tmp /tmp


ENV PCRE_CONF_OPT="--enable-utf8 --enable-unicode-properties"

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup

RUN sed -i "s/dl-cdn.alpinelinux.org/${CONTAINER_PACKAGE_URL}/g" /etc/apk/repositories \
    && apk add gnu-libiconv --no-cache --repository http://${CONTAINER_PACKAGE_URL}/alpine/edge/community/ --allow-untrusted \
    && apk add --no-cache --update --virtual .build-deps \
        curl \
        build-base \
        git \
        jq \
        gd-dev \
        linux-headers \
        cmake \
        make \
        readline-dev \
        zlib-dev \
        libmaxminddb-dev \
        #安装lcrypto
        libressl-dev \ 
        # 编译ngx_http_proxy_connect_module依赖的
        patch \
        pcre \
    && apk add --no-cache --update \
        gd \
        # GraphicsMagick 依赖
        libxslt \
        # openesty依赖
        libgcc \
        #时区设置时间依赖
        tzdata \
        # resty命令行工具和crypto依赖
        perl \
    && cp "/usr/share/zoneinfo/$TZ" /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    \
    && cd /tmp \
    && curl -fSL ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/delegates/jpegsrc.v6b2.tar.gz | tar -zx \
    #&& tar -xzf jpegsrc.v6b2.tar.gz \
    && cd jpeg-6b2 \
    && ./configure \
    && make \
    && make install \
    && cd /tmp \
    && curl -fSL ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/delegates/libpng-1.6.37.tar.gz | tar -zx \
    #&& tar -xzf libpng-1.6.37.tar.gz \
    && cd libpng-1.6.37 \
    && ./configure \
    && make \
    && make install \
    && cd /tmp \
    && curl -fSL ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/1.3/GraphicsMagick-1.3.36.tar.gz | tar -zx \
    #&& tar -xzf GraphicsMagick-1.3.36.tar.gz \
    && cd GraphicsMagick-1.3.36 \
    && ./configure --prefix=/usr/local/GraphicsMagick --enable-shared --disable-openmp --without-perl \
    && make \
    && make install \
    && ln -s /usr/local/GraphicsMagick/bin/gm /usr/bin/gm \
    \
    && cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz | tar -zx \
    #&&  tar -xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz | tar -zx \
    #&&  tar -xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz | tar -zx \
    #&&  tar -xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} \
        # 对应版本的patch文件
        && patch -d build/nginx-1.19.3/ -p 1 < /opt/ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_1018.patch \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && curl -fSL http://luarocks.github.io/luarocks/releases/luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz | tar -zx \
    #&&  tar -xzf luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && cd luarocks-${RESTY_LUAROCKS_VERSION} \
    && ./configure \
        --prefix=/usr/local/luajit \
       --with-lua=/usr/local/luajit \
        --lua-suffix=jit-2.1.0-beta3 \
        --with-lua-include=/usr/local/luajit/include/luajit-2.1 \
    && make build \
    && make install \
    && ln -s /usr/local/luajit/bin/luarocks /bin/luarocks \
    && cd /tmp \
    \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && git clone https://github.com/DaveGamble/cJSON \
    && cd cJSON && cmake . && make && make install && cd .. \
    \
    && mkdir -p /var/cache/nginx /etc/nginx/sites-enabled /etc/nginx/upstream-conf.d /etc/nginx/templates \
    \
    && rm -f /etc/nginx/conf.d/default.conf \
    && luarocks install lua-resty-libcjson \
    && sed -ie 's#ffi_load "cjson"#ffi_load "/usr/local/lib/libcjson.so"#' /usr/local/luajit/share/lua/5.1/resty/libcjson.lua \
    && luarocks install lua-resty-http 0.13-0 \
    && luarocks install statsd \
    && luarocks install lua-resty-statsd \
    && luarocks install lua-resty-beanstalkd \
    && luarocks install lua-resty-jit-uuid \
    && luarocks install lua-resty-cookie \
    && luarocks install luafilesystem 1.7.0-2 \
    && luarocks install penlight 1.5.4-1 \
    && luarocks install lrandom 20180729-1 \
    && luarocks install luacrypto 0.3.2-2 \
    && luarocks install luasocket 3.0rc1-2 \
    && luarocks install lua-resty-kafka 0.06-0 \
    && luarocks install lua-resty-dns-client 1.0.0-1 \
    && luarocks install lua-resty-jwt 0.2.0-0 \
    && luarocks install lua-resty-consul 0.2-0 \
    && luarocks install luaossl \
    && luarocks install lua-resty-repl \
    && apk del .build-deps \
    && rm -rf /tmp/* \
    && cd /tmp

RUN find /usr/local/bin -type f -exec chmod +x {} \;

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]

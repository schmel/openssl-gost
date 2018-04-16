FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive

ADD engine /tmp/engine

# Openssl with GOST
RUN apt update && apt upgrade -y && apt install apt-utils openssl libssl-dev make cmake wget -y \
 && grep -q '^openssl_conf' /etc/ssl/openssl.cnf || sed -i '1iopenssl_conf = openssl_def' /etc/ssl/openssl.cnf \
 && echo "" >> /etc/ssl/openssl.cnf \
 && echo "[openssl_def]" >> /etc/ssl/openssl.cnf \
 && echo "engines = engine_section" >> /etc/ssl/openssl.cnf \
 && echo "" >> /etc/ssl/openssl.cnf \
 && echo "[engine_section]" >> /etc/ssl/openssl.cnf \
 && echo "gost = gost_section" >> /etc/ssl/openssl.cnf \
 && echo "" >> /etc/ssl/openssl.cnf \
 && echo "[gost_section]" >> /etc/ssl/openssl.cnf \
 && echo "engine_id = gost" >> /etc/ssl/openssl.cnf \
 && echo "dynamic_path = /usr/lib/ssl/engines/libgost.so" >> /etc/ssl/openssl.cnf \
 && echo "default_algorithms = ALL" >> /etc/ssl/openssl.cnf \
 && echo "CRYPT_PARAMS = id-Gost28147-89-CryptoPro-A-ParamSet" >> /etc/ssl/openssl.cnf \
 && echo "" >> /etc/ssl/openssl.cnf \
 && mkdir -p /usr/lib/ssl/engines \
 && rm -rf /var/cache/apt/* \
 && echo "============ BUILD GOST ENGINE ============" \
 && mkdir -p /tmp/engine/build \
 && cd /tmp/engine/build \
 && cmake -DCMAKE_BUILD_TYPE=Release .. \
 && cmake --build . --config Release \
 && cmake --build . --target install --config Release \
 && find / -name "gost.so" -exec cp {} /usr/lib/ssl/engines/libgost.so \; \
 && rm -rf /tmp/*

# CURL with GOST
RUN apt update && apt install binutils gcc libcurl4-openssl-dev -y \
 && apt-get remove curl -y \
 && mkdir -p /tmp/curl && cd /tmp/curl \
 && wget https://curl.haxx.se/download/curl-7.57.0.tar.gz \
 && tar -xzvpf curl-7.57.0.tar.gz \
 && cd curl-7.57.0/ \
 && ./configure --with-ssl \
 && make && make install \
 && rm -rf /tmp/curl \
 && curl -V \
 && rm -rf /var/cache/apt/*

ADD stunnel-5.44 /tmp/stunnel
COPY conf/stunnel_prod.conf /etc/stunnel.conf

# Stunnel with GOST
RUN cd /tmp/stunnel \
 && ./configure \
 && make && make install \
 && stunnel -version \
 && ls -la /usr/local/bin \
 && rm -rf /var/cache/apt/* \
 && rm -rf /tmp/*

# Dirs for agent

RUN mkdir -p /etc/ssl/agents \
 && mkdir -p /etc/ssl/nbki

# Kontragent
#ADD conf/certs.tar /etc/ssl/agents
#RUN chown -R root:root /etc/ssl/agents/ && chmod 600 /etc/ssl/agents/*.* \
# && cp /etc/ssl/agents/*.crt /usr/local/share/ca-certificates/ \
# && update-ca-certificates \
# && ls -la /usr/local/share/ca-certificates/

# NBKI
COPY conf/nbki/ /usr/local/share/ca-certificates

RUN cd /usr/local/share/ca-certificates/ \
 && wget http://cpca.cryptopro.ru/cacer.p7b \
 && openssl pkcs7 -inform der -in cacer.p7b -out cacer.pkcs7 \
 && openssl pkcs7 -print_certs -in cacer.pkcs7 -out cryptopro.crt \
 && rm -f cacer.pkcs7 cacer.p7b \
 && update-ca-certificates \
 && ls -la /usr/local/share/ca-certificates/

# Проверка OpenSSL на ГОСТ
RUN ls -la /usr/lib/ssl/engines/ \
 && openssl ciphers -v | grep GOST \
 && openssl version -e

EXPOSE 15115

CMD ["/usr/local/bin/stunnel", "/etc/stunnel.conf"]

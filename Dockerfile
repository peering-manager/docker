FROM alpine:3.19 as builder

RUN apk add --no-cache \
    bash \
    build-base \
    cargo \
    ca-certificates \
    cmake \
    cyrus-sasl-dev \
    git \
    jpeg-dev \
    libevent-dev \
    libffi-dev \
    libxslt-dev \
    make \
    musl-dev \
    openldap-dev \
    postgresql-dev \
    py3-pip \
    python3-dev \
    && python3 -m venv /opt/peering-manager/venv \
    && /opt/peering-manager/venv/bin/python3 -m pip install --upgrade \
    pip \
    setuptools \
    wheel

ARG PEERING_MANAGER_PATH
COPY ${PEERING_MANAGER_PATH}/requirements.txt requirements-container.txt /
RUN /opt/peering-manager/venv/bin/pip install -r /requirements.txt
RUN /opt/peering-manager/venv/bin/pip install -r /requirements-container.txt
WORKDIR /peering-manager

FROM alpine:3.19 as bgpq-builder

RUN mkdir app && \
    apk add --no-cache build-base autoconf automake gcc git libtool linux-headers musl-dev

WORKDIR /bgp3

RUN mkdir /bgpq3 && \
    git clone https://github.com/snar/bgpq3 . && git checkout v0.1.36.1 && \
    ./configure && make install 

WORKDIR /bgp4

RUN mkdir /bgpq4 && \
    git clone https://github.com/bgp/bgpq4.git . && git checkout 1.12 && \
    ./bootstrap && ./configure && make install 

##############
# Main stage #
##############

FROM alpine:3.19 as main

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    libevent \
    libffi \
    libjpeg-turbo \
    libxslt \
    openssl \
    postgresql-client \
    postgresql-libs \
    py3-pip \
    python3 \
    tini \
    unit \
    unit-python3

WORKDIR /opt

COPY --from=builder /opt/peering-manager/venv /opt/peering-manager/venv
COPY --from=bgpq-builder /usr/local/bin/bgpq3 /usr/local/bin/bgpq3
COPY --from=bgpq-builder /usr/local/bin/bgpq4 /usr/local/bin/bgpq4

ARG PEERING_MANAGER_PATH
COPY ${PEERING_MANAGER_PATH} /opt/peering-manager

COPY docker/configuration.docker.py /opt/peering-manager/peering_manager/configuration.py
COPY docker/docker-entrypoint.sh /opt/peering-manager/docker-entrypoint.sh
COPY docker/run-command.sh /opt/peering-manager/run-command.sh
COPY docker/launch-peering-manager.sh /opt/peering-manager/launch-peering-manager.sh
COPY startup_scripts/ /opt/peering-manager/startup_scripts/
COPY initializers/ /opt/peering-manager/initializers/
COPY configuration/ /etc/peering-manager/config/
COPY docker/nginx-unit.json /etc/unit/

WORKDIR /opt/peering-manager

# Must set permissions for '/opt/peering-manager/static' directory
# to g+w so that `./manage.py collectstatic` can be executed during
# container startup.
RUN mkdir -p static /opt/unit/state/ /opt/unit/tmp/ \
    && chown -R unit:root /opt/unit/ \
    && chmod -R g+w /opt/unit/ \
    && cd /opt/peering-manager/ \
    && SECRET_KEY="dummy" /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py collectstatic --no-input

ENTRYPOINT [ "/sbin/tini", "--" ]

CMD [ "/opt/peering-manager/docker-entrypoint.sh", "/opt/peering-manager/launch-peering-manager.sh" ]

LABEL ORIGINAL_TAG="" \
    PEERING_MANAGER_GIT_BRANCH="" \
    PEERING_MANAGER_GIT_REF="" \
    PEERING_MANAGER_GIT_URL="" \
    # See https://github.com/opencontainers/image-spec/blob/master/annotations.md#pre-defined-annotation-keys
    org.opencontainers.image.created="" \
    org.opencontainers.image.title="Peering Manager Docker" \
    org.opencontainers.image.description="A container based distribution of Peering Manager, the free and open BGP management solution." \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.authors="The Peering Manager contributors." \
    org.opencontainers.image.vendor="The Peering Manager contributors." \
    org.opencontainers.image.url="https://github.com/peering-manager/docker" \
    org.opencontainers.image.documentation="https://github.com/peering-manager/docker" \
    org.opencontainers.image.source="https://github.com/peering-manager/docker.git" \
    org.opencontainers.image.revision="" \
    org.opencontainers.image.version="snapshot"

###################
## LDAP specific ##
###################

FROM main as ldap

RUN apk add --no-cache libldap libsasl util-linux

COPY docker/ldap_config.docker.py /opt/peering-manager/peering_manager/ldap_config.py

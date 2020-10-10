FROM python:3-slim as builder

# OS dependencies
RUN apt-get update -y \
    && apt-get install -y \
       build-essential \
       python3-dev \
       libldap2-dev \
       libsasl2-dev \
       libssl-dev \
       libxml2-dev \
       libxslt1-dev

ARG PEERING_MANAGER_PATH
WORKDIR /peering-manager

COPY ${PEERING_MANAGER_PATH}/requirements.txt /peering-manager
RUN mkdir /install \
    && pip3 install --upgrade pip \
    && pip3 install \
       --prefix="/install" --no-warn-script-location --no-cache-dir -r \
       /peering-manager/requirements.txt \
    && pip3 install \
       --prefix="/install" --no-warn-script-location --no-cache-dir \
       gunicorn \
       django-auth-ldap \
       django-radius

##############
# Main stage #
##############

FROM python:3-slim as main

RUN apt-get -y update \
    && apt-get -y install bgpq3 \
    && apt-get clean \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

WORKDIR /opt

COPY --from=builder /install /usr/local

ARG PEERING_MANAGER_PATH
COPY ${PEERING_MANAGER_PATH} /opt/peering-manager

COPY configuration/configuration.py /opt/peering-manager/peering_manager
COPY configuration/gunicorn_config.py /etc/peering-manager/config/
COPY startup_scripts/ /opt/peering-manager/startup_scripts/
COPY docker/nginx.conf /etc/peering-manager/nginx/nginx.conf
COPY docker/entrypoint.sh /opt/peering-manager/

WORKDIR /opt/peering-manager

# Must set permissions for '/opt/peering-manager/static' directory
# to g+w so that `./manage.py collectstatic` can be executed during
# container startup.
RUN mkdir static && chmod -R g+w static

ENTRYPOINT [ "/opt/peering-manager/entrypoint.sh" ]

CMD ["gunicorn", "-c", "/etc/peering-manager/config/gunicorn_config.py", "peering_manager.wsgi"]

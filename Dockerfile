FROM python:3
RUN apt-get update -y \
    && apt-get install -y python3-dev libldap2-dev libsasl2-dev build-essential bgpq3
RUN adduser --system --group --home /opt/peering-manager --no-create-home --shell /bin/bash peering-manager  
WORKDIR /opt/peering-manager
COPY --chown=peering-manager:peering-manager peering-manager /opt/peering-manager
RUN pip3 install --upgrade pip \
    && pip3 install --no-cache-dir -r requirements_dev.txt \
    && pip3 install --no-cache-dir gunicorn
COPY --chown=peering-manager:peering-manager configuration/configuration.py /opt/peering-manager/peering_manager
COPY configuration/gunicorn_config.py /etc/peering-manager/config/
COPY startup_scripts/ /opt/peering-manager/startup_scripts/
COPY docker/nginx.conf /etc/peering-manager/nginx/nginx.conf
COPY docker/entrypoint.sh /opt/peering-manager/
RUN mkdir static && chown peering-manager:peering-manager static
USER peering-manager:peering-manager
ENTRYPOINT [ "/opt/peering-manager/entrypoint.sh" ]
CMD ["gunicorn", "-c", "/etc/peering-manager/config/gunicorn_config.py", "peering_manager.wsgi"]

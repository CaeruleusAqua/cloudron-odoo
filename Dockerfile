FROM cloudron/base:4.2.0
# Reference: https://github.com/odoo/docker/blob/master/17.0/Dockerfile

RUN mkdir -p /app/code /app/pkg /app/data /app/code/auto/addons
WORKDIR /app/code

#RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-dev build-essential libjpeg-dev libpq-dev libjpeg8-dev libxml2-dev libssl-dev libffi-dev libmysqlclient-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev liblcms2-dev curl python3.10-venv

RUN curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb


RUN npm install -g rtlcss

COPY bin/* /usr/local/bin/

#COPY lib/doodbalib /usr/local/lib/python3.8/dist-packages/doodbalib
#COPY custom /app/code/custom
#RUN chmod -R a+rx /usr/local/bin \
#    && chmod -R a+rX /usr/local/lib/python3.8/dist-packages/doodbalib \
#    && sync

# Install Odoo
# sync extra addons

ENV ODOO_VERSION=17.0
ENV ODOO_SOURCE=odoo/odoo
ENV DEPTH_DEFAULT=100
ENV DEPTH_MERGE=500
RUN git config --global user.email "$CLOUDRON_MAIL_SMTP_USERNAME"
RUN git config --global user.name "Cloudron service"

#RUN /app/code/custom/build.d/200-dependencies

# RUN curl -L https://github.com/odoo/odoo/archive/${ODOO_COMMIT_HASH}.tar.gz | tar zx --strip-components 1 -C /app/code && \
RUN git clone https://github.com/odoo/odoo.git --depth 1 -b $ODOO_VERSION /app/code/odoo
WORKDIR /app/code/odoo
RUN git pull -r
WORKDIR /app/code
RUN python3 -m venv odoo_venv
RUN source odoo_venv/bin/activate && pip3 install --upgrade pip
RUN source odoo_venv/bin/activate && pip3 install -r /app/code/odoo/requirements.txt
RUN source odoo_venv/bin/activate && pip3 install -e /app/code/odoo

ADD sql.patch ldap.patch /app/pkg/

# Patch Odoo to prevent connecting to the default database named 'postgres' every now and then.
RUN patch -p1 /app/code/odoo/odoo/sql_db.py /app/pkg/sql.patch

# Properly map the LDAP attribute 'displayname' instead of 'cn' to the display name of the logged in user.
RUN patch -p1 /app/code/odoo/addons/auth_ldap/models/res_company_ldap.py /app/pkg/ldap.patch

RUN rm -rf /var/log/nginx && mkdir /run/nginx && ln -s /run/nginx /var/log/nginx

WORKDIR /app/code/custom/src
#RUN gitaggregate -c /app/code/custom/src/repos.yaml --expand-env
#RUN /app/code/custom/build.d/110-addons-link
#RUN /app/code/custom/build.d/200-dependencies
#RUN /app/code/custom/build.d/400-clean
#RUN /app/code/custom/build.d/900-dependencies-cleanup

# Copy entrypoint script and Odoo configuration file
ADD start.sh odoo.conf.sample nginx.conf /app/pkg/

RUN mkdir -p /app/data/odoo/filestore /app/data/odoo/addons && \
    chown -R cloudron:cloudron /app/data

CMD [ "/app/pkg/start.sh" ]

FROM python:3.12-slim-bookworm

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general compatibility
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        python3-dev \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
        libpq-dev \
        libxml2-dev \
        libxslt1-dev \
        libjpeg-dev \
        liblcms2-dev \
        libwebp-dev \
        libtiff-dev \
        libopenjp2-7-dev \
        zlib1g-dev \
        curl \
        git \
        postgresql-client \
        nodejs \
        npm \
        # wkhtmltopdf dependencies
        fontconfig \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
        xfonts-75dpi \
        xfonts-base \
        fonts-dejavu-core \
        fonts-freefont-ttf \
        fonts-liberation2 \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf wkhtmltox.deb \
    && npm install -g rtlcss \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /opt/odoo

# Copy requirements file first to cache installation
COPY requirements.txt /opt/odoo/

# Install python dependencies
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy the rest of the codebase
COPY . /opt/odoo
RUN sed -i 's/\r$//' /opt/odoo/odoo-bin \
    && chmod +x /opt/odoo/odoo-bin

# Add odoo-bin to PATH
ENV PATH="/opt/odoo:${PATH}"

# Copy entrypoint script and Odoo configuration
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Create Odoo directory structure and data folder
RUN mkdir -p /var/lib/odoo /etc/odoo

# Expose ports
EXPOSE 8069 8072

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["odoo-bin", "-c", "/etc/odoo/odoo.conf"]

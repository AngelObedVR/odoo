# Guía de Despliegue de Odoo 19 con Docker

Esta guía detalla los pasos y mejores prácticas para desplegar Odoo 19.0 y su base de datos PostgreSQL (con soporte para Inteligencia Artificial mediante `pgvector`) tanto en un entorno **local de desarrollo** como en un **servidor de producción**.

---

## 1. Despliegue Local (Desarrollo)

El entorno local está diseñado para facilitar la edición de código en tiempo real con recarga rápida (*live-reload*).

### Requisitos Previos
*   [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y en ejecución.
*   En Windows: Configurado para usar el motor de **WSL 2**.

### Pasos para iniciar
1.  Abre una terminal en la raíz del proyecto.
2.  Construye e inicia los contenedores en segundo plano (*detached mode*):
    ```bash
    docker compose up --build -d
    ```
3.  Verifica que ambos contenedores estén activos:
    ```bash
    docker compose ps
    ```

### Acceso a los Servicios
*   **Odoo Web**: Abre tu navegador en [http://localhost:8069](http://localhost:8069).
*   **Base de Datos**: El motor PostgreSQL está expuesto en `localhost:5432` (usuario: `odoo`, contraseña: `odoo`, base de datos por defecto: `postgres`). Puedes conectarte con herramientas como DBeaver o pgAdmin.

### Flujo de Desarrollo (Código en vivo)
Gracias al mapeo de volumen `- .:/opt/odoo` en el archivo `docker-compose.yml`, cualquier cambio que realices en el código de Odoo o tus módulos (*addons*) en tu sistema operativo local se verá reflejado inmediatamente dentro del contenedor. 

Para reiniciar Odoo rápidamente y aplicar cambios en archivos Python:
```bash
docker compose restart web
```

---

## 2. Despliegue en Servidor (Producción)

Para un entorno de producción, debemos priorizar la seguridad, la persistencia robusta de datos y el rendimiento.

### Modificaciones Recomendadas en `docker-compose.prod.yml`
En producción se recomienda crear un archivo dedicado (ej. `docker-compose.prod.yml`) con las siguientes diferencias:

1.  **Eliminar el montaje del código fuente local**: No montes la carpeta local (`- .:/opt/odoo`). La imagen Docker construida ya tiene todo el código compilado dentro en el paso `COPY . /opt/odoo` del Dockerfile. Esto garantiza inmutabilidad y seguridad.
2.  **Cerrar el puerto de la base de datos**: Elimina el mapeo de puertos de la base de datos (`ports: - "5432:5432"`) para evitar accesos no autorizados desde internet. El contenedor de Odoo seguirá comunicándose internamente en la red de Docker.
3.  **Cambiar las credenciales por defecto**: Cambia la contraseña del usuario `odoo` por una clave robusta en el entorno de la base de datos y de Odoo.

#### Ejemplo de `docker-compose.prod.yml`:
```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    image: odoo:19.0-prod
    container_name: odoo_web_prod
    restart: always
    ports:
      - "8069:8069"
      - "8072:8072"
    environment:
      - DB_HOST=db
      - DB_PORT=5432
      - DB_USER=odoo_prod
      - DB_PASSWORD=CAMBIAR_POR_UNA_CLAVE_SEGURA_Y_ROBUSTA
    volumes:
      - odoo-data:/var/lib/odoo
    depends_on:
      - db

  db:
    image: pgvector/pgvector:pg16
    container_name: odoo_db_prod
    restart: always
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_USER=odoo_prod
      - POSTGRES_PASSWORD=CAMBIAR_POR_UNA_CLAVE_SEGURA_Y_ROBUSTA
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - odoo-db-data:/var/lib/postgresql/data

volumes:
  odoo-data:
  odoo-db-data:
```

### Configuración del Servidor y Proxy Inverso (Nginx)
Odoo no debe exponerse directamente a internet en producción. Se debe colocar un proxy inverso como **Nginx** en frente para manejar conexiones HTTPS (SSL/TLS), compresión gzip y redirecciones.

#### Configuración de Nginx sugerida:
```nginx
# Servidor de chat y longpolling
upstream odoochat {
    server 127.0.0.1:8072;
}

# Servidor web principal
upstream odoo {
    server 127.0.0.1:8069;
}

server {
    listen 80;
    server_name odoo.tudominio.com;
    # Redireccionar todo el tráfico HTTP a HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name odoo.tudominio.com;

    ssl_certificate /etc/letsencrypt/live/odoo.tudominio.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/odoo.tudominio.com/privkey.pem;

    # Parámetros recomendados de cabecera proxy
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;

    # Redireccionar solicitudes de Longpolling
    location /longpolling {
        proxy_pass http://odoochat;
    }

    # Redireccionar solicitudes Web estándar
    location / {
        proxy_redirect off;
        proxy_pass http://odoo;
    }

    # Caché estática
    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
    }

    # Compresión GZIP
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
    gzip on;
}
```

### Optimización y Rendimiento (Modo Multi-Processing)
En servidores de producción con múltiples núcleos de CPU, debes configurar **Workers** en Odoo (ejecutándose en segundo plano) para procesar más solicitudes simultáneas.
Puedes definir los parámetros en tu archivo `odoo.conf` (o a través de flags en `command` en docker-compose):

*   `workers`: Cantidad óptima de procesos trabajadores. Fórmula recomendada: `(núcleos CPU * 2) + 1`.
*   `limit_memory_hard`: Límite máximo de RAM permitido por worker.
*   `limit_memory_soft`: Límite recomendado de RAM por worker.

---

## 3. Comandos Útiles de Administración

*   **Ver logs en tiempo real**:
    ```bash
    docker compose logs -f
    ```
*   **Ver logs de un contenedor específico**:
    ```bash
    docker compose logs -f web
    ```
*   **Apagar servicios**:
    ```bash
    docker compose down
    ```
*   **Apagar servicios borrando todos los volúmenes (¡Cuidado! Elimina la base de datos)**:
    ```bash
    docker compose down -v
    ```
*   **Entrar a la terminal bash de Odoo**:
    ```bash
    docker compose exec web bash
    ```
*   **Acceder a la base de datos mediante la línea de comandos de PostgreSQL**:
    ```bash
    docker compose exec db psql -U odoo -d postgres
    ```

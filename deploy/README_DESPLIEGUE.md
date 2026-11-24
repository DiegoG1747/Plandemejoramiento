# Despliegue de PetCard en servidor Linux (AWS EC2)

Plan de mejoramiento – despliegue con Vite, Nginx y PostgreSQL propio. Aprendiz: Diego Guerrero.

## Arquitectura

- 1 instancia EC2 `servidor-proyecto` (Ubuntu Server 24.04 LTS, t3.micro, us-east-1a), IP elástica `100.51.94.217`.
- Disco 1 (EBS gp3 12 GiB, `/`): sistema operativo, Node.js, Nginx y la aplicación (`/opt/app`).
- Disco 2 (EBS gp3 8 GiB, `/data`): solo PostgreSQL 17 (`/data/postgresql/17/main`) y respaldos (`/data/backups`).
- Nginx sirve `frontend/dist` en el puerto 80 y reenvía `/api/` al backend (`localhost:3001`).
- PostgreSQL escucha solo en `localhost`; el puerto 5432 no está abierto a internet.

## Archivos de esta carpeta

| Archivo | Destino en el servidor | Para qué |
|---|---|---|
| `nginx-app.conf` | `/etc/nginx/sites-available/app` | Sitio de Nginx (frontend + proxy `/api`) |
| `app-backend.service` | `/etc/systemd/system/app-backend.service` | Mantiene el backend encendido |
| `migrar.sh` | `/opt/app/deploy/migrar.sh` | Exporta `public` de Supabase y lo restaura en `app_db` |
| `configurar-env.sh` | `/opt/app/deploy/configurar-env.sh` | Crea `backend/.env` pidiendo las claves por teclado |

El archivo `.env` **nunca** se sube a Git.

## Pasos resumidos

```bash
# 1. Disco de datos
sudo mkfs.ext4 -L pgdata /dev/nvme1n1
sudo mkdir -p /data && sudo mount /dev/nvme1n1 /data
echo 'UUID=<uuid> /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# 2. PostgreSQL 17 (PGDG) con datos en /data
sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
sudo apt install -y postgresql-17
# mover /var/lib/postgresql/17/main a /data/postgresql/17/main y cambiar data_directory
sudo -u postgres psql -c "CREATE ROLE app_user WITH LOGIN;" -c "CREATE DATABASE app_db OWNER app_user;"

# 3. Migración desde Supabase
./migrar.sh

# 4. Backend
cd /opt/app/backend && npm ci --omit=dev
/opt/app/deploy/configurar-env.sh
sudo cp /opt/app/deploy/app-backend.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now app-backend

# 5. Frontend
cd /opt/app/frontend && echo "VITE_API_URL=/api" > .env.production
npm ci && npm run build
sudo mkdir -p /var/www/app && sudo cp -r dist/* /var/www/app/
sudo cp /opt/app/deploy/nginx-app.conf /etc/nginx/sites-available/app
sudo ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

## Respaldos

- Diario a las 2:00 (crontab de `postgres`):
  `0 2 * * * pg_dump -Fc app_db -f /data/backups/app_db_$(date +\%F).dump && find /data/backups -name 'app_db_*.dump' -mtime +7 -delete`
- Snapshot EBS del volumen de datos desde la consola de AWS.
- Restaurar: `sudo -u postgres createdb app_db_prueba && sudo -u postgres pg_restore -d app_db_prueba /data/backups/app_db_AAAA-MM-DD.dump`

## Cambio en el código

`frontend/src/components/admin/admin-alimentacion.vue` tenía la URL `https://localhost:3001/api` fija; ahora usa `import.meta.env.VITE_API_URL || '/api'` como el resto del frontend.

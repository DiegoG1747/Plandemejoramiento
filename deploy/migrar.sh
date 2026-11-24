#!/bin/bash
# Migra el esquema public de Supabase al PostgreSQL local (app_db)
set -e
while [ -z "$SUPA" ]; do read -rsp "Pega la cadena Session pooler de Supabase y presiona Enter: " SUPA; echo; done
F=/data/backups/supabase_public_$(date +%F).dump
pg_dump "$SUPA" --schema=public --no-owner --no-privileges -Fc -f "$F"
unset SUPA
ls -lh "$F"
sudo -u postgres pg_restore -d app_db --no-owner --role=app_user "$F" 2>&1 | tee /data/backups/restore_$(date +%F).log || true
echo MIGRACION-TERMINADA

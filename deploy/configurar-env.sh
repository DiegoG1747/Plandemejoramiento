#!/bin/bash
# Crea /opt/app/backend/.env pidiendo las claves por teclado (no quedan en el historial)
set -e
while [ -z "$DBPASS" ]; do read -rsp "Clave nueva para app_user (PostgreSQL local): " DBPASS; echo; done
echo "ALTER ROLE app_user PASSWORD :'pw';" | sudo -u postgres psql -q -v pw="$DBPASS"
DBPASS_URL=$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$DBPASS")
while [ -z "$SMTP_PASS" ]; do read -rsp "SMTP_PASS (clave de aplicacion de Gmail): " SMTP_PASS; echo; done
while [ -z "$TWILIO_SID" ]; do read -rp "TWILIO_ACCOUNT_SID: " TWILIO_SID; done
while [ -z "$TWILIO_TOKEN" ]; do read -rsp "TWILIO_AUTH_TOKEN: " TWILIO_TOKEN; echo; done
JWT=$(openssl rand -hex 48)
umask 077
cat > /opt/app/backend/.env <<ENV
NODE_ENV=production
PORT=3001
FRONTEND_URL=http://100.51.94.217
DATABASE_URL=postgresql://app_user:${DBPASS_URL}@localhost:5432/app_db
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=yuberfranco2603@gmail.com
SMTP_PASS=${SMTP_PASS}
TWILIO_ACCOUNT_SID=${TWILIO_SID}
TWILIO_AUTH_TOKEN=${TWILIO_TOKEN}
TWILIO_PHONE_NUMBER=+14582318099
GOOGLE_CALENDAR_ID=yuberfranco4@gmail.com
GOOGLE_CREDENTIALS_PATH=./google-credentials.json
JWT_SECRET=${JWT}
JWT_EXPIRES_IN=24h
FIREBASE_SERVICE_ACCOUNT_PATH=./credentials/firebase-service-account.json
ENV
unset DBPASS DBPASS_URL SMTP_PASS TWILIO_SID TWILIO_TOKEN JWT
ls -l /opt/app/backend/.env
echo ENV-LISTO

#!/bin/sh
export MONGODB_APP_PASSWORD=$(cat /run/secrets/mongodb_app_password)
export MONGODB_URI=mongodb://app_user:${MONGODB_APP_PASSWORD}@mongodb:27017/products
exec node app.js 
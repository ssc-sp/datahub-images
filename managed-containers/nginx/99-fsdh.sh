#!/bin/bash

# update listen port
sed -i "s/80;/$FSDH_PORT;/g" /etc/nginx/conf.d/default.conf

# create proxy
sed -i "/location \//a \        proxy_set_header $FSDH_USER_HEADER_NAME $FSDH_USER_HEADER_DEFAULT;" /etc/nginx/conf.d/default.conf 
sed -i "/location \//a \        proxy_set_header Connection upgrade;" /etc/nginx/conf.d/default.conf 
sed -i "/location \//a \        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" /etc/nginx/conf.d/default.conf 
sed -i "/location \//a \        proxy_set_header X-Real-IP \$remote_addr;" /etc/nginx/conf.d/default.conf 
sed -i "/location \//a \        proxy_set_header Host \$host;" /etc/nginx/conf.d/default.conf 
sed -i "/location \//a \        proxy_pass http://$FSDH_PROXY_TARGET_HOST:$FSDH_PROXY_TARGET_PORT;" /etc/nginx/conf.d/default.conf 

#!/bin/bash

export REDIS_PORT=$REDIS_PORT_6379_TCP_PORT
export REDIS_HOST=$REDIS_PORT_6379_TCP_ADDR

node_modules/coffee-script/bin/coffee appserver.coffee --create-user

#!/bin/bash

# Run the appserver in the development mode with a static session key (so you
# don't have to log in every time you restart the server) and code reloading.

export PORT=8080
export SESSION_SECRET="insecure"
export NODE_ENV=development
coffee --watch appserver.coffee

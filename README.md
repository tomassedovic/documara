# Development #

0. Prerequisities: `node`, `npm` and `redis`
    # yum install nodejs npm redis
1. Install dependencies:
    $ npm install
2. Run Redis:
    $ redis-server redis/redis.conf
3. Run documara:
    $ make run


# Adding a user #

Run this:

    $ EMAIL=me@example.com PASSWORD=password \
        node_modules/coffee-script/bin/coffee appserver.coffee --create-user

You should of course specify your own EMAIL and PASSWORD values. Redis has to
be running for this to work, the app doesn't have to.


# Production #

You should compile the static assets. They should be served by an asset server
such as nginx.  When running documara, set these environment variables:

    NODE_ENV=production
    PORT=8080  # or whatever
    SESSION_SECRET=<a long secret string, shouldn't change when app restarts>


# Docker #

Get the images:

    sudo docker pull redis:3
    sudo docker build -t documara/app .

Run redis database:

    sudo docker run --name documara-redis -d redis:3 redis-server \
        --appendonly yes --appendfsync everysec

NOTE: the data will be stored on the host at:

    $ docker inspect  -f "{{range .Mounts}}{{.Source}}{{end}}" documara-redis

Which is generally under `/var/lib/docker/volumes/`.

Create users:

    sudo docker run --rm -t -i --link documara-redis:redis \
        -e EMAIL=test@example.com \
        -e PASSWORD=password documara/app \
        /create-user

Run documara application:

    sudo docker run --link documara-redis:redis --name documara-app \
        -p $HOST_PORT:8080 documara/app

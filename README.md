# Documara: Notes App That Treasures Your Data

This is a dusty old project of mine. It's a web-based note-taking app
that utilises Operational Transformation to sync notes.

This means it handles conflicts automatically and you should never
lose anything you enter, even if you have the app open on multiple
windows and type into them all at the same time.

For some motivation behind this project, see:

https://aimlesslygoingforward.com/blog/2017/05/25/documara/


This is essentially a code-dump of a private repo. I'm happy to answer
question but be prepared to do some spelunking.


TODO: move the code to sharedb?

https://github.com/share/sharedb

Seems to be the maintained successor of sharejs. Let's investigate.



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
    sudo docker pull tsedovic/node:$VERSION
    sudo docker build -t tsedovic/documara:latest .

Push the images to the registry:

    export VERSION=0.3.0   # This should match the `LABEL version` in Dockerfile
    sudo docker tag tsedovic/documara:latest tsedovic/documara:$VERSION
    sudo docker push tsedovic/documara:$VERSION
    sudo docker push tsedovic/documara:latest

Run redis database:

    sudo docker run -v /var/lib/docker/volumes/documara-redis:/data  \
        -d --name documara-redis redis:3 redis-server  \
        --appendonly yes --appendfsync everysec

NOTE: the data will be stored on the host at:

    $ docker inspect  -f "{{range .Mounts}}{{.Source}}{{end}}" documara-redis

Which is generally under `/var/lib/docker/volumes/`.

Create users:

    sudo docker run --rm -t -i --link documara-redis:redis \
        -e EMAIL=test@example.com \
        -e PASSWORD=password tsedovic/documara \
        /create-user

Run documara application:

    sudo docker run --link documara-redis:redis -d --name documara-app  \
        -p $HOST_PORT:8080 tsedovic/documara


# License

AGPLv3 or later

# Author

Tomas Sedovic <tomas@sedovic.cz>
https://aimlesslygoingforward.com/
IRC: shadower

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

    $ EMAIL=me@example.com PASSWORD=password node create-user.js

You should of course specify your own EMAIL and PASSWORD values. Redis has to
be running for this to work, the app doesn't have to.


# Production #

You should compile the static assets. They should be served by an asset server
such as nginx.  When running documara, set these environment variables:

    NODE_ENV=production
    PORT=8080  # or whatever
    SESSION_SECRET=<a long secret string, shouldn't change when app restarts>

ARG TARGET_ENV="default"
FROM nimlang/nim AS builder
CMD ["/sbin/my_init"]
RUN apt-get update # && apt-get install  libpcre3-dev libsqlite3-dev build-essential wget -y

FROM builder AS nimbuilder
WORKDIR /app
COPY . .
RUN nimble install -y --depsOnly

# Currently, this docker deployment has been tested only on fly.io
FROM nimbuilder
COPY fly-consts.nim consts.nim
RUN nim compile tohray.nim
ENTRYPOINT ["./tohray"]

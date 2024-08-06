ARG TARGET_ENV="default"
FROM nimlang/nim AS builder
RUN apt-get update

FROM builder AS nimbuilder
WORKDIR /app
COPY . .
RUN nimble install -y --depsOnly

# Currently, this docker deployment has been tested only on fly.io
FROM nimbuilder
COPY fly-consts.nim consts.nim
RUN nim -d:release compile tohray.nim
ENTRYPOINT ["./tohray"]

ARG TARGET_ENV="default"
FROM nimlang/nim AS builder
# Nim's stdlib `re` (used by prologue's route compilation and the markdown
# renderer) dlopens PCRE v1 at runtime, but Debian trixie dropped libpcre3,
# so build PCRE 8.45 from source.
ADD https://downloads.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz /tmp/pcre.tgz
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/* \
  && tar xzf /tmp/pcre.tgz -C /tmp \
  && cd /tmp/pcre-8.45 \
  && ./configure --disable-cpp --enable-utf --enable-unicode-properties \
  && make -j$(nproc) \
  && make install \
  && ldconfig \
  && rm -rf /tmp/pcre.tgz /tmp/pcre-8.45

FROM builder AS nimbuilder
WORKDIR /app
COPY . .
RUN nimble install -y --depsOnly

# Currently, this docker deployment has been tested only on fly.io
FROM nimbuilder
COPY fly-consts.nim consts.nim
RUN nim -d:release -d:nimcryptoAvx2=false compile tohray.nim
ENTRYPOINT ["./tohray"]

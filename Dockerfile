FROM ubuntu:20.04

# install tzdata separately for cacheing
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/London
RUN truncate -s0 /tmp/preseed.cfg && \
       (echo "tzdata tzdata/Areas select Europe" >> /tmp/preseed.cfg) && \
       (echo "tzdata tzdata/Zones/Europe select London" >> /tmp/preseed.cfg) && \
       debconf-set-selections /tmp/preseed.cfg && \
       rm -f /etc/timezone /etc/localtime && \
       apt-get update && \
       DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
       apt-get install -y tzdata \
  && rm -rf /var/lib/apt/lists/*

# install packages
RUN  apt-get update \
  && apt-get install -y build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 libevent-dev libboost-system-dev libboost-filesystem-dev libboost-test-dev libboost-thread-dev libsqlite3-dev libminiupnpc-dev libzmq3-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libqrencode-dev \
  && rm -rf /var/lib/apt/lists/*

# additional depends for berkeley db
RUN  apt-get update \
  && apt-get install -y wget \
  && rm -rf /var/lib/apt/lists/*

RUN addgroup --gid 10001 --system nonroot && adduser -u 10000 --system --gid 10001 --home /home/nonroot nonroot
RUN mkdir -p /code/ && chown -R nonroot:nonroot /code/
USER nonroot

# copy berkeley source code
WORKDIR /code/
COPY --chown=nonroot:nonroot ./contrib/ /code/contrib/
COPY --chown=nonroot:nonroot ./depends/ /code/depends/

# build berkeley db
RUN ./contrib/install_db4.sh `pwd`

# get remaining libs
USER root
RUN  apt-get update \
  && apt-get install -y libssl-dev libfmt-dev \
  && rm -rf /var/lib/apt/lists/*
USER nonroot

# copy remaining code
COPY --chown=nonroot:nonroot ./autogen.sh /code/
COPY --chown=nonroot:nonroot ./CODEOWNERS /code/
COPY --chown=nonroot:nonroot ./configure.ac /code/
COPY --chown=nonroot:nonroot ./CONTRIBUTING.md /code/
COPY --chown=nonroot:nonroot ./COPYING /code/
COPY --chown=nonroot:nonroot ./INSTALL.md /code/
COPY --chown=nonroot:nonroot ./libbitcoinconsensus.pc.in /code/
COPY --chown=nonroot:nonroot ./Makefile.am /code/
COPY --chown=nonroot:nonroot ./README.md /code/
COPY --chown=nonroot:nonroot ./SECURITY.md /code/
COPY --chown=nonroot:nonroot ./build-aux/ /code/build-aux/
COPY --chown=nonroot:nonroot ./build_msvc/ /code/build_msvc/
COPY --chown=nonroot:nonroot ./ci/ /code/ci/
COPY --chown=nonroot:nonroot ./doc/ /code/doc/
COPY --chown=nonroot:nonroot ./share/ /code/share/
COPY --chown=nonroot:nonroot ./src/ /code/src/
COPY --chown=nonroot:nonroot ./test/ /code/test/

# build core
RUN export BDB_PREFIX='/code/db4' && ./autogen.sh && ./configure BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" --enable-hardening
RUN make -j4

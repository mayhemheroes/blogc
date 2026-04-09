FROM --platform=linux/amd64 ubuntu:22.04 AS builder
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y cmake make gcc git

ADD . /blogc
WORKDIR /blogc
RUN cmake -S . -B build
RUN cmake --build build

RUN mkdir -p /deps
RUN ldd /blogc/build/src/blogc/blogc | tr -s '[:blank:]' '\n' | grep '^/' | xargs -I % sh -c 'cp % /deps;'

FROM ubuntu:22.04 AS package

COPY --from=builder /deps /deps
COPY --from=builder /blogc/build/src/blogc/blogc /blogc/blogc
ENV LD_LIBRARY_PATH=/deps

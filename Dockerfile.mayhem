FROM --platform=linux/amd64 ubuntu:20.04 as builder
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf libtool rubygems ruby-dev make gcc
RUN gem install ronn

ADD . /blogc
WORKDIR /blogc
RUN ./autogen.sh  
RUN ./configure 
RUN make

RUN mkdir -p /deps
RUN ldd /blogc/blogc | tr -s '[:blank:]' '\n' | grep '^/' | xargs -I % sh -c 'cp % /deps;'

FROM ubuntu:20.04 as package

COPY --from=builder /deps /deps
COPY --from=builder /blogc/blogc /blogc/blogc
ENV LD_LIBRARY_PATH=/deps

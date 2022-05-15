FROM --platform=linux/amd64 ubuntu:20.04
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf libtool rubygems ruby-dev make gcc
RUN gem install ronn

ADD . /blogc
WORKDIR /blogc
RUN ./autogen.sh  
RUN ./configure 
RUN make

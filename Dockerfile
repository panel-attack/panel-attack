FROM ubuntu:16.04

LABEL maintainer1="bumbleblo"
LABEL maintainer2="Sara Silva"

WORKDIR /home

RUN apt-get update && apt-get upgrade 

RUN apt-get install git \ 
                    wget \
                    gcc \
                    g++ \ 
                    mercurial \
                    vim \
                    lua5.3 \
                    -y 

RUN hg clone https://bitbucket.org/rude/love

WORKDIR love/

RUN apt-get install build-essential autotools-dev automake libtool pkg-config libdevil-dev libfreetype6-dev libluajit-5.1-dev libphysfs-dev libsdl2-dev libopenal-dev libogg-dev libvorbis-dev libflac-dev libflac++-dev libmodplug-dev libmpg123-dev libmng-dev libturbojpeg libtheora-dev -y

RUN hg update 0.9.0

RUN ./platform/unix/automagic && ./configure && make -j 3 && make install -j 3 


FROM ubuntu:16.04

USER root
RUN mkdir -p /root/.pip && mkdir -p /home

#Enable this to support pypi mirror
#ADD pip.conf /root/.pip/

#Enable this to suport ubuntu apt source mirror
#RUN sed -i s/archive.ubuntu.com/cn.archive.ubuntu.com/ /etc/apt/sources.list && \
#    sed -i s/security.ubuntu.com/cn.security.ubuntu.com/ /etc/apt/sources.list

#Add openr
WORKDIR /home
RUN apt-get update && apt-get install -y git
RUN git clone https://github.com/facebook/openr

#some patch, the way to archive successful build
ADD build_openr_in_container.sh /home/openr/build/

WORKDIR /home/openr/build

#Enable this to build it automatically
#RUN ./build_openr_in_container.sh

################################################################
#Example:
# docker build -t ob:16 .
# docker run -it --name ob ob:16 ./build_openr_in_container.sh
# or
# docker run -it --name ob ob:16 bash
#   ./build_openr_in_container.sh
################################################################

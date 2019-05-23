FROM ubuntu:18.04

MAINTAINER rdbox <info-rdbox@intec.co.jp>

ENV LANG C.UTF-8

RUN apt-get update && \
	apt-get -y install sudo && \
	apt-get -y install unzip && \
	apt-get -y install file && \
	apt-get -y install hdparm && \
	apt-get -y install pv && \
	apt-get -y install udev && \
	apt-get -y install curl && \
	apt-get -y install uuid-runtime && \
	apt-get -y install whois && \
	apt-get -y install wpasupplicant && \
	apt-get -y install git && \
	curl -o /usr/local/bin/flash -L https://github.com/hypriot/flash/releases/download/2.3.0/flash && \
	chown root:root /usr/local/bin/flash && \
	chmod 0755 /usr/local/bin/flash && \
	cd /opt && \
	git clone https://github.com/rdbox-intec/flashRDBOX.git

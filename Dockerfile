FROM phusion/baseimage:0.9.22
MAINTAINER James Blackwell

# set proxy (uncomment and modify when needed)
#ENV http_proxy "http://user:password@proxy:port"
#ENV https_proxy "http://user:password@proxy:port"

# Ensure UTF-8
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Set timezone
ENV TZ Europe/London

# set HOME
# see: https://github.com/phusion/baseimage-docker#environment-variables
RUN echo /root > /etc/container_environment/HOME
ENV HOME /root

# set other environment variables
ENV ZELLO_ROOT $HOME/zello

ENV X11VNC_PASSWORD password
ENV DISPLAY=:99

# suppress all wine console logs
# you can set this to 'trace+all' to get all trace information
ENV WINEDEBUG=-all

RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

CMD ["/sbin/my_init"]

###############################################################################
# UPDATE SYSTEM AND ADD PPAs
###############################################################################

# Update ubuntu base system
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# Workarounds and fixes
RUN \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
    apt-utils

# Install packages needed for ppa handling
RUN \
    apt-get update && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
    curl \
    wget \
    python-software-properties \
    apt-utils

# wine ppa
RUN \
    echo "deb https://dl.winehq.org/wine-builds/ubuntu $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/winehq.list && \
    wget --quiet -O - "https://dl.winehq.org/wine-builds/Release.key"  | apt-key add -

# enable i386 architecture for wine install
RUN \
    dpkg --add-architecture i386

###############################################################################
# INSTALL PACKAGES
###############################################################################

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --force-yes --no-install-recommends \
    # Common packages
    nano \
    mc \
    p7zip-full \
    # wine
    winehq-stable \
    # xvfb, x11vnc, fluxbox for remote X
    xvfb \
    x11vnc \
    fluxbox \
    xterm

# if mono and gecko gets not detected automatically and wine prompts to install them,
# you have to use the correct versions which correspond to the currently
# installed wine version
# to find out for which files wine is looking, start wine with:
# env WINEDEBUG=trace+all wine foo.exe
# and watch the logs
RUN \
    mkdir -p /opt/wine-stable/share/wine/mono && \
    wget http://dl.winehq.org/wine/wine-mono/4.6.4/wine-mono-4.6.4.msi -O /opt/wine-stable/share/wine/mono/wine-mono-4.6.4.msi

RUN \
    mkdir -p /opt/wine-stable/share/wine/gecko && \
    wget http://dl.winehq.org/wine/wine-gecko/2.47/wine_gecko-2.47-x86.msi -O /opt/wine-stable/share/wine/gecko/wine_gecko-2.47-x86.msi && \
    wget http://dl.winehq.org/wine/wine-gecko/2.47/wine_gecko-2.47-x86_64.msi -O /opt/wine-stable/share/wine/gecko/wine_gecko-2.47-x86_64.msi

###############################################################################
# ZELLO INSTALLATION
###############################################################################
# This is a hack and prone to fail in any future zello release
RUN \
    mkdir -p "/tmp/zellosetup-tmp" && \

    mkdir -p "$ZELLO_ROOT/Lng" && \
    mkdir -p "$ZELLO_ROOT/Snd" && \
    mkdir -p "$ZELLO_ROOT/custom" && \
    cd "/tmp/zellosetup-tmp" && \

    wget 'http://zello.com/data/ZelloSetup.exe' && \
    7z e ZelloSetup.exe && \

    #cp "de" "$ZELLO_ROOT/Lng/" && \
    cp "en" "$ZELLO_ROOT/Lng/" && \
    cp *.wav "$ZELLO_ROOT/Snd/" && \
    cp "Zello.exe" "$ZELLO_ROOT" && \
    rm -rf /tmp/zellosetup-tmp

# Add start script
ADD build/zello "$ZELLO_ROOT/"
RUN chmod a+x   "$ZELLO_ROOT/zello"

# zello_announce_time to cron
#ADD build/zello_announce_time "$ZELLO_ROOT/"
#RUN chmod a+x   "$ZELLO_ROOT/zello_announce_time"

#ADD build/zello_announce_time_cron /etc/cron.d/
#RUN chmod 700 /etc/cron.d/zello_announce_time_cron

###############################################################################
# CONFIGURE PHUSION/BASEIMAGE SETTINGS
###############################################################################

# integrate xvfb/x11vnc in init system
RUN mkdir -p        /etc/service/x11vnc
ADD build/x11vnc.sh /etc/service/x11vnc/run
RUN chmod +x        /etc/service/x11vnc/run

###############################################################################
# VOLUMES AND PORTS
###############################################################################

EXPOSE 5900

VOLUME /root/zello/custom

###############################################################################
# CLEAN UP
###############################################################################

# uninstall not needed packages, clean tmp dir and apt lists
RUN \
  apt-get purge \
  p7zip-full \

  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# unset proxy
ENV http_proxy ""
ENV https_proxy ""

###############################################################################
# END OF DOCKERFILE
###############################################################################

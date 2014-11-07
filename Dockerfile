FROM ubuntu:14.04
MAINTAINER Arien Kock <arien.kock@gmail.com>

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

COPY locale /etc/default/locale

#RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe" > /etc/apt/sources.list
RUN apt-get -qq update && \
    apt-get install -y build-essential python-software-properties software-properties-common wget curl git fontconfig && \
    apt-get clean

# SSH server
RUN apt-get install -y openssh-server && \
    sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd && \
    mkdir -p /var/run/sshd

# Java 1.7
RUN wget --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/7u67-b01/jdk-7u67-linux-x64.tar.gz && \
    mkdir -p /opt/jdk && \
    tar -zxf jdk-7u67-linux-x64.tar.gz -C /opt/jdk && \
    update-alternatives --install /usr/bin/java java /opt/jdk/jdk1.7.0_67/bin/java 100 && \
    update-alternatives --install /usr/bin/javac javac /opt/jdk/jdk1.7.0_67/bin/javac 100

# Maven 3.0.5
RUN wget http://apache.petsads.us/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz && \
    mkdir -p /opt/maven && \
    tar -zxf apache-maven-3.0.5-bin.tar.gz -C /opt/maven && \
    ln -s /opt/maven/apache-maven-3.0.5/bin/mvn /usr/bin

# Set Java and Maven env variables
ENV M2_HOME /opt/maven/apache-maven-3.0.5
ENV JAVA_HOME /opt/jdk/jdk1.7.0_67
ENV JAVA_OPTS -Xmx1G -Xms1G -XX:PermSize=256M -XX:MaxPermSize=256m

# Copied stuff from official MySQL image
RUN groupadd -r mysql && useradd -r -g mysql mysql
ENV MYSQL_MAJOR 5.5
ENV MYSQL_VERSION 5.5.40
RUN apt-get update && apt-get install -y perl --no-install-recommends && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y libaio1 && rm -rf /var/lib/apt/lists/*
# RUN gpg --keyserver pgp.mit.edu --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5
RUN apt-get update && apt-get install -y curl --no-install-recommends && rm -rf /var/lib/apt/lists/* \
	&& curl -SL "http://dev.mysql.com/get/Downloads/MySQL-$MYSQL_MAJOR/mysql-$MYSQL_VERSION-linux2.6-x86_64.tar.gz" -o mysql.tar.gz \
	&& curl -SL "http://mysql.he.net/Downloads/MySQL-$MYSQL_MAJOR/mysql-$MYSQL_VERSION-linux2.6-x86_64.tar.gz.asc" -o mysql.tar.gz.asc \
	&& mkdir /usr/local/mysql \
	&& tar -xzf mysql.tar.gz -C /usr/local/mysql --strip-components=1 \
	&& rm mysql.tar.gz* \
	&& rm -rf /usr/local/mysql/mysql-test /usr/local/mysql/sql-bench \
	&& rm -rf /usr/local/mysql/bin/*-debug /usr/local/mysql/bin/*_embedded \
	&& find /usr/local/mysql -type f -name "*.a" -delete \
	&& apt-get update && apt-get install -y binutils && rm -rf /var/lib/apt/lists/* \
	&& { find /usr/local/mysql -type f -executable -exec strip --strip-all '{}' + || true; } \
	&& apt-get purge -y --auto-remove binutils
ENV PATH $PATH:/usr/local/mysql/bin:/usr/local/mysql/scripts

EXPOSE 3306

# Load scripts
COPY bootstrap bootstrap
RUN chmod +x -Rv bootstrap

ENV MYSQL_ROOT_PASSWORD rootPassword
RUN ./bootstrap/mysql-setup.sh

# Add user jenkins to the image
RUN adduser --quiet jenkins
RUN adduser jenkins sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN echo "jenkins:jenkins" | chpasswd

# NVM
RUN mkdir -p /opt/nvm
RUN git clone https://github.com/creationix/nvm.git /opt/nvm
RUN ./bootstrap/nvm.sh
RUN echo "source /opt/nvm/nvm.sh" >> /root/.profile

# Adjust perms for jenkins user
RUN chown -R jenkins /opt/nvm
RUN touch /home/jenkins/.profile
RUN echo "source /opt/nvm/nvm.sh" >> /home/jenkins/.profile
RUN chown jenkins /home/jenkins/.profile

# Browsers
RUN apt-get update && apt-get -y install xvfb x11-xkb-utils xfonts-100dpi xfonts-75dpi xfonts-scalable xfonts-cyrillic dbus-x11 libfontconfig1-dev && apt-get clean
RUN apt-get update && apt-get -y install firefox chromium-browser ca-certificates && apt-get clean

RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/ && \
    apt-get install -y libappindicator1 libpango1.0-0 && \
    dpkg -i /tmp/google-chrome-stable_current_amd64.deb && \
    apt-get install -fy && \
    rm /tmp/google-chrome-stable_current_amd64.deb && \
    apt-get clean

# Shim chrome to disable sandbox
# See https://github.com/docker/docker/issues/1079
RUN mv /usr/bin/google-chrome /usr/bin/google-chrome.orig
COPY shims/google-chrome /usr/bin/google-chrome
RUN chmod +x /usr/bin/google-chrome

# xvfb
COPY init.d/xvfb /etc/init.d/xvfb
RUN chmod +x /etc/init.d/xvfb

ENV DISPLAY :10
ENV LD_LIBRARY_PATH /usr/lib/x86_64-linux-gnu/

# Need some fonts
COPY fonts/sourcesanspro /usr/share/fonts/sourcesanspro
RUN fc-cache -v /usr/share/fonts/sourcesanspro

# Standard SSH port
EXPOSE 22

# Startup services when running the container
CMD ["./bootstrap/init.sh"]

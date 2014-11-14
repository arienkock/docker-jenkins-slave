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
RUN gpg --keyserver pgp.mit.edu --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5
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
RUN echo "source /opt/nvm/nvm.sh" >> /home/jenkins/.bashrc
RUN echo 'export PATH=$PATH:/usr/local/mysql/bin:/usr/local/mysql/scripts' >> /home/jenkins/.bashrc

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

# Install Tomcat6
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
RUN mkdir -p "$CATALINA_HOME" && chown jenkins:jenkins "$CATALINA_HOME"
WORKDIR $CATALINA_HOME
USER jenkins

# see https://www.apache.org/dist/tomcat/tomcat-8/KEYS
RUN gpg --keyserver pgp.mit.edu --recv-keys \
	05AB33110949707C93A279E3D3EFE6B686867BA6 \
	07E48665A34DCAFAE522E5E6266191C37C037D42 \
	47309207D818FFD8DCD3F83F1931D684307A10A5 \
	541FBE7D8F78B25E055DDEE13C370389288584E7 \
	61B832AC2F1C5A90F0F9B00A1C506407564C17A3 \
	79F7026C690BAA50B92CD8B66A3AD3F4F22C4FED \
	80FF76D88A969FE46108558A80B953A041E49465 \
	8B39757B1D8A994DF2433ED58B3A601F08C975E5 \
	A27677289986DB50844682F8ACB77FC2E86E29AC \
	A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 \
	B3F49CD3B9BD2996DA90F817ED3873F5D3262722 \
	DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 \
	F3A04C595DB5B6A5F1ECA43E3B7BBB100D811BBE \
	F7DA48BB64BCB84ECBA7EE6935CD23C10D498E23

ENV TOMCAT_MAJOR 6
ENV TOMCAT_VERSION 6.0.41
ENV TOMCAT_TGZ_URL https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

RUN curl -SL "$TOMCAT_TGZ_URL" -o tomcat.tar.gz \
	&& curl -SL "$TOMCAT_TGZ_URL.asc" -o tomcat.tar.gz.asc \
	&& gpg --verify tomcat.tar.gz.asc \
	&& tar -xvf tomcat.tar.gz --strip-components=1 \
	&& rm bin/*.bat \
	&& rm tomcat.tar.gz*

# Standard SSH port
EXPOSE 22
# Expose Tomcat port
EXPOSE 8080
# MySQL port
EXPOSE 3306

USER root
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Startup services when running the container
CMD ["/usr/sbin/sshd", "-D"]
ENTRYPOINT ["/init.sh"]

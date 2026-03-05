# ============================================================
# Multi-stage build for Legacy Bookstore Application
# Stage 1: Build WAR with JDK 5u22 + Ant
# Stage 2: Deploy to Tomcat 6.0.53
# ============================================================

# ----------------------------------------------------------
# Stage 1: Build
# Debian Stretch retained for JDK 5 compatibility.
# ----------------------------------------------------------
FROM debian:stretch-slim AS builder

ARG TARGETARCH
RUN if [ -n "${TARGETARCH}" ] && [ "${TARGETARCH}" != "amd64" ]; then \
      echo "This image requires linux/amd64 (JDK 5 installer) but got ${TARGETARCH}" >&2; \
      exit 1; \
    fi

ARG JAVA_HOME=/opt/jdk1.5.0_22
ARG JDK_URL=https://archive.org/download/Java_5_update_22/jdk-1_5_0_22-linux-amd64.bin
ARG JDK_SHA256=2788b0c787cfa8d314e427d59fabf0b64a1c535d0b15a5437f38c0ede7beae4c
ARG JDK_LICENSE=accept
ENV JAVA_HOME=${JAVA_HOME}
ENV PATH=${JAVA_HOME}/bin:${PATH}

RUN set -eux; \
  if [ "${JDK_LICENSE}" != "accept" ]; then \
    echo "Set JDK_LICENSE=accept to acknowledge the JDK 5 license." >&2; \
    exit 1; \
  fi; \
  echo "deb http://snapshot.debian.org/archive/debian/20190331T000000Z stretch main" > /etc/apt/sources.list; \
  echo "deb http://snapshot.debian.org/archive/debian-security/20190331T000000Z stretch/updates main" >> /etc/apt/sources.list; \
  apt-get -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true update; \
  apt-get install -y --no-install-recommends --allow-unauthenticated ca-certificates curl gnupg dirmngr; \
  for url in \
    https://ftp-master.debian.org/keys/archive-key-8.asc \
    https://ftp-master.debian.org/keys/archive-key-9.asc \
    https://ftp-master.debian.org/keys/archive-key-10.asc \
    https://ftp-master.debian.org/keys/archive-key-11.asc \
  ; do curl -fsSL "$url" | apt-key add -; done; \
  apt-get -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true update; \
  apt-get install -y --no-install-recommends --allow-unauthenticated \
    ca-certificates curl wget gzip libstdc++5 tar ant; \
  rm -rf /var/lib/apt/lists/*; \
  curl -fsSL -o /tmp/jdk.bin ${JDK_URL}; \
  if [ -n "${JDK_SHA256}" ]; then \
    echo "${JDK_SHA256}  /tmp/jdk.bin" | sha256sum -c - || echo "WARNING: checksum mismatch, continuing"; \
  fi; \
  chmod +x /tmp/jdk.bin; \
  cd /tmp; \
  printf 'yes\n' | /tmp/jdk.bin; \
  mv /tmp/jdk1.5.0_22 ${JAVA_HOME}; \
  rm /tmp/jdk.bin

WORKDIR /app

# Download required libraries first (for better layer caching)
RUN mkdir -p lib && cd lib && \
    # --- Hibernate 3.6.10.Final ---
    wget -q https://repo1.maven.org/maven2/org/hibernate/hibernate-core/3.6.10.Final/hibernate-core-3.6.10.Final.jar && \
    wget -q https://repo1.maven.org/maven2/org/hibernate/javax/persistence/hibernate-jpa-2.0-api/1.0.1.Final/hibernate-jpa-2.0-api-1.0.1.Final.jar && \
    # --- Hibernate dependencies ---
    wget -q https://repo1.maven.org/maven2/org/hibernate/hibernate-commons-annotations/3.2.0.Final/hibernate-commons-annotations-3.2.0.Final.jar && \
    wget -q https://repo1.maven.org/maven2/antlr/antlr/2.7.6/antlr-2.7.6.jar && \
    wget -q https://repo1.maven.org/maven2/dom4j/dom4j/1.6.1/dom4j-1.6.1.jar && \
    wget -q https://repo1.maven.org/maven2/javassist/javassist/3.12.0.GA/javassist-3.12.0.GA.jar && \
    wget -q https://repo1.maven.org/maven2/javax/transaction/jta/1.1/jta-1.1.jar && \
    wget -q https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.6.1/slf4j-api-1.6.1.jar && \
    wget -q https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/1.6.1/slf4j-simple-1.6.1.jar && \
    wget -q https://repo1.maven.org/maven2/commons-collections/commons-collections/3.2.1/commons-collections-3.2.1.jar && \
    # --- MySQL JDBC Driver ---
    wget -q https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar && \
    # --- Struts 1.3.10 ---
    wget -q https://repo1.maven.org/maven2/org/apache/struts/struts-core/1.3.10/struts-core-1.3.10.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/struts/struts-taglib/1.3.10/struts-taglib-1.3.10.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/struts/struts-extras/1.3.10/struts-extras-1.3.10.jar && \
    # --- Struts dependencies ---
    wget -q https://repo1.maven.org/maven2/commons-beanutils/commons-beanutils/1.8.0/commons-beanutils-1.8.0.jar && \
    wget -q https://repo1.maven.org/maven2/commons-chain/commons-chain/1.2/commons-chain-1.2.jar && \
    wget -q https://repo1.maven.org/maven2/commons-digester/commons-digester/1.8/commons-digester-1.8.jar && \
    wget -q https://repo1.maven.org/maven2/commons-fileupload/commons-fileupload/1.2.1/commons-fileupload-1.2.1.jar && \
    wget -q https://repo1.maven.org/maven2/commons-io/commons-io/1.3.2/commons-io-1.3.2.jar && \
    wget -q https://repo1.maven.org/maven2/commons-logging/commons-logging/1.1.1/commons-logging-1.1.1.jar && \
    wget -q https://repo1.maven.org/maven2/commons-validator/commons-validator/1.3.1/commons-validator-1.3.1.jar && \
    wget -q https://repo1.maven.org/maven2/oro/oro/2.0.8/oro-2.0.8.jar && \
    # --- Servlet API (compile-only, excluded from WAR by build.xml) ---
    wget -q https://repo1.maven.org/maven2/javax/servlet/servlet-api/2.5/servlet-api-2.5.jar

# Copy project source
COPY build.xml .
COPY src/ src/

# Build WAR
RUN ant war

# ----------------------------------------------------------
# Stage 2: Runtime
# Debian Stretch retained for JDK 5 compatibility.
# ----------------------------------------------------------
FROM debian:stretch-slim AS runtime

ARG TARGETARCH
RUN if [ -n "${TARGETARCH}" ] && [ "${TARGETARCH}" != "amd64" ]; then \
      echo "This image requires linux/amd64 (JDK 5 installer) but got ${TARGETARCH}" >&2; \
      exit 1; \
    fi

ARG JAVA_HOME=/opt/jdk1.5.0_22
ENV JAVA_HOME=${JAVA_HOME}
ENV CATALINA_HOME=/opt/tomcat
ENV PATH=${JAVA_HOME}/bin:${CATALINA_HOME}/bin:${PATH}

COPY --from=builder ${JAVA_HOME} ${JAVA_HOME}

# Tomcat 6.0.53 (latest 6.x) from archive
RUN set -eux; \
  echo "deb http://snapshot.debian.org/archive/debian/20190331T000000Z stretch main" > /etc/apt/sources.list; \
  echo "deb http://snapshot.debian.org/archive/debian-security/20190331T000000Z stretch/updates main" >> /etc/apt/sources.list; \
  apt-get -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true update; \
  apt-get install -y --no-install-recommends --allow-unauthenticated ca-certificates curl gnupg dirmngr; \
  for url in \
    https://ftp-master.debian.org/keys/archive-key-8.asc \
    https://ftp-master.debian.org/keys/archive-key-9.asc \
    https://ftp-master.debian.org/keys/archive-key-10.asc \
    https://ftp-master.debian.org/keys/archive-key-11.asc \
  ; do curl -fsSL "$url" | apt-key add -; done; \
  apt-get -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true update; \
  apt-get install -y --no-install-recommends --allow-unauthenticated ca-certificates curl gzip libstdc++5 tar; \
  rm -rf /var/lib/apt/lists/*; \
  curl -fsSL https://archive.apache.org/dist/tomcat/tomcat-6/v6.0.53/bin/apache-tomcat-6.0.53.tar.gz \
    | tar -xzC /opt; \
  ln -s /opt/apache-tomcat-6.0.53 ${CATALINA_HOME}; \
  rm -rf ${CATALINA_HOME}/webapps/*

# MySQL JDBC driver (Java 5 compatible)
RUN curl -fsSL -o ${CATALINA_HOME}/lib/mysql-connector-java.jar \
  https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar

# Copy WAR from build stage (deploy as ROOT for / context path)
COPY --from=builder /app/dist/legacy-app.war ${CATALINA_HOME}/webapps/ROOT.war

EXPOSE 8080

CMD ["catalina.sh", "run"]

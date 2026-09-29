#!/bin/sh
set -e

export DATASOURCE_PASSWORD="$(cat /run/secrets/WEBAPI_DATASOURCE_PASSWORD)"
export FLYWAY_DATASOURCE_PASSWORD="$(cat /run/secrets/WEBAPI_DATASOURCE_PASSWORD)"
export SECURITY_LDAP_SYSTEM_PASSWORD="$(cat /run/secrets/SECURITY_LDAP_SYSTEM_PASSWORD)"
export SECURITY_DB_DATASOURCE_PASSWORD="$(cat /run/secrets/SECURITY_DB_DATASOURCE_PASSWORD)"
export SECURITY_AD_SYSTEM_PASSWORD="$(cat /run/secrets/SECURITY_AD_SYSTEM_PASSWORD)"
export SECURITY_OAUTH_GOOGLE_APISECRET="$(cat /run/secrets/SECURITY_OAUTH_GOOGLE_APISECRET)"
export SECURITY_OAUTH_FACEBOOK_APISECRET="$(cat /run/secrets/SECURITY_OAUTH_FACEBOOK_APISECRET)"
export SECURITY_OAUTH_GITHUB_APISECRET="$(cat /run/secrets/SECURITY_OAUTH_GITHUB_APISECRET)"
export SECURITY_SAML_KEYMANAGER_STOREPASSWORD="$(cat /run/secrets/SECURITY_SAML_KEYMANAGER_STOREPASSWORD)"
export SECURITY_SAML_KEYMANAGER_PASSWORDS_ARACHNENETWORK="$(cat /run/secrets/SECURITY_SAML_KEYMANAGER_PASSWORDS_ARACHNENETWORK)"

# Trust store: a Broadsea-mounted cacerts wins; otherwise fall back to the
# image's JVM default (Java 8 image for WebAPI 2.x, Temurin 21 for 3.x).
JAVA_KEYSTORE="/usr/local/openjdk-8/lib/security/cacerts"
if [ ! -f "$JAVA_KEYSTORE" ]; then
    JAVA_KEYSTORE="/opt/java/openjdk/lib/security/cacerts"
fi
if [ -s "/tmp/cacerts" ]; then
    JAVA_KEYSTORE=/tmp/cacerts
fi

cd /var/lib/ohdsi/webapi
if [ -d "WEB-INF" ]; then
    # WebAPI 2.x image: exploded war layout, launched via the Spring Boot
    # war launcher with extra jars appended to the classpath.
    exec java -Djavax.net.ssl.trustStore=${JAVA_KEYSTORE} \
        ${DEFAULT_JAVA_OPTS} ${JAVA_OPTS} \
        -cp ".:WebAPI.jar:WEB-INF/lib/*.jar${CLASSPATH}" \
        org.springframework.boot.loader.WarLauncher
else
    # WebAPI 3.x image: executable Spring Boot jar. Extra jars (the image's
    # plugin directory and the Broadsea-mounted additional jar) load through
    # the boot loader path instead of the classpath.
    exec java -Djavax.net.ssl.trustStore=${JAVA_KEYSTORE} \
        ${DEFAULT_JAVA_OPTS} ${JAVA_OPTS} \
        -Dloader.path=/opt/webapi/plugins,/var/lib/ohdsi/webapi/lib/additional \
        --add-opens java.naming/com.sun.jndi.ldap=ALL-UNNAMED \
        -jar WebAPI.jar
fi

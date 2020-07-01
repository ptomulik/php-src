#!/bin/sh
set -ev

# Create TLS certificate
sudo mkdir -p /etc/ldap/ssl

(cd /etc/ldap/ssl &&
  sudo openssl req -newkey rsa:4096 -x509 -nodes -out server.crt -keyout server.key -days 3650 \
       -subj "/C=US/ST=Arizona/L=Localhost/O=localhost/CN=`hostname`")

sudo chown -R openldap:openldap /etc/ldap/ssl


# Configure LDAP protocols to serve.
sudo sed -e 's|^\s*SLAPD_SERVICES\s*=.*$|SLAPD_SERVICES="ldap:/// ldaps:/// ldapi:///"|' -i /etc/default/slapd

# Configure LDAP database.
DN=`sudo ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:/// -b cn=config '(&(olcRootDN=*)(olcSuffix=*))' dn | grep -i '^dn:'`;

sudo ldapmodify -Q -Y EXTERNAL -H ldapi:/// << EOF
$DN
changetype: modify
replace: olcSuffix
olcSuffix: dc=my-domain,dc=com
-
replace: olcRootDN
olcRootDN: cn=Manager,dc=my-domain,dc=com
-
replace: olcRootPW
olcRootPW: secret

dn: cn=config
changetype: modify
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/ssl/server.crt
-
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ssl/server.crt
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ssl/server.key
-
add: olcTLSVerifyClient
olcTLSVerifyClient: never
-
add: olcAuthzRegexp
olcAuthzRegexp: uid=usera,cn=digest-md5,cn=auth cn=usera,dc=my-domain,dc=com
-
replace: olcLogLevel
olcLogLevel: -1
EOF

sudo service slapd restart

ldapadd -H ldapi:/// -D cn=Manager,dc=my-domain,dc=com -w secret <<EOF
dn: dc=my-domain,dc=com
objectclass: top
objectclass: organization
objectclass: dcObject
dc: my-domain
o: php ldap tests
EOF

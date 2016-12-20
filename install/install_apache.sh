#!/bin/bash

function install_apache {

    echo "---"
    echo "--- Installing Apache2 "
    echo "---"

    if [[ $OS == "Ubuntu" ]]; then
        echo "--"
        echo "-- Ubuntu based system install of apache2"
        echo "--"
        apt-get install apache2 -y
        SitesAvailable="/etc/apache2/sites-available"
        SitesEnabled="/etc/apache2/sites-enabled"
    else
        echo "--"
        echo "-- CENT/RH based system install of apache2"
        echo "--"

        yum install apache2 -y
        ApacheConfd="/etc/httpd/conf.d"
        setsebool -P httpd_can_network_connect 1
    fi

    echo "--"
    echo "-- configuring apache2"
    echo "--"

    local CSD="$DEVDIR/src/apache2"
    local CSF="$PRIVATE_SCOT_MODULES/etc/scot-revproxy.conf"

    if [[ ! -e $CSF ]]; then
        CSF="$CSD/scot-revproxy-remoteuser-${OS}.conf"

        if [[ ! -e $CSF ]]; then
            CSF="$CSD/scot-revproxy-local-${OS}.conf"

            if [[ ! -e $CSF ]]; then
                echo -e "${red} FAILED to FIND revproxy config! ${nc}"
                echo "Installation can not proceed until fixed!"
                exit 1;
            fi
        fi
    fi

    echo "-"
    echo "- Found Scot Reverse Proxy Config File:"
    echo "- $CSF"
    echo "- installing..."
    echo "-"
    SCOT_APACHE_CONFIG=$SitesAvailable/scot.conf

    if [[ $OS == "Ubuntu" ]]; then

        if [[ -e $SitesEnabled/000-default.conf ]]; then
            echo "- removing 000-default.conf file"
            rm -f $SitesEnabled/000-default.conf
        fi

        if [[ $REFRESHAPACHECONF == "YES" ]] || [[ ! -e $SitesEnabled/scot.conf ]]; then
            cp $CSF $SCOT_APACHE_CONFIG
            ln -s $SSCOT_APACHE_CONFIG $SitesEnabled/scot.conf
        fi

    else 

       echo "- clearing existing configs from $ApacheConfd"
       for FILE in $ApacheConfd/*conf
       do   
            if [[ $FILE != "$ApacheConfd/scot.conf" ]]; then
                mv $FILE $FILE.bak
            else
                if [[ $REFRESHAPACHECONF == "YES" ]]; then
                    mv $FILE $FILE.bak
                fi
            fi
       done
       SCOT_APACHE_CONFIG=/etc/httpd/conf.d/scot.conf
       cp $CSF $SCOT_APACHE_CONFIG
    fi
    
    echo "-"
    echo "- Config in place, editing to set variables"
    echo "- document root = $SCOTROOT"
    echo "- revproxy port = $SCOTPORT"
    echo "- hostname      = $MYHOSTNAME"
    echo "-"
    sed -i 's=/scot/document/root='$SCOTROOT'/public=g' $SCOT_APACHE_CONFIG
    sed -i 's=/localport='$SCOTPORT'=g' $SCOT_APACHE_CONFIG
    sed -i 's=scot\.server\.tld='$MYHOSTNAME'=g' $SCOT_APACHE_CONFIG

    SSLDIR="/etc/apache2/ssl"

    if [[ ! -d $SSLDIR ]]; then
        mkdir -p $SSLDIR
    fi

    if [[ ! -e $SSLDIR/scot.key ]]; then
        echo "-"
        echo "- Generating temporary SSL certificates"
        echo "- Please replace these with real Certificates as soon as possible"
        echo "-"
        openssl genrsa 2048 > $SSLDIR/scot.key
        openssl req -new -key $SSLDIR/scot.key \
                    -out /tmp/scot.csr \
                    -subj '/CN=localhost/O=SCOT Default Cert/C=US'
        openssl x509 -req -days 36530 \
                     -in /tmp/scot.csr
                     -signkey $SSLDIR/scot.key \
                     -out $SSLDIR/scot.crt
    else
        echo "-"
        echo "- scot.key exists in $SSLDIR, "
        echo "-"
    fi

    if [[ $OS == "Ubuntu" ]]; then
        echo "- enabling modules in apache "
        AMODS="proxy proxy_http ssl headers rewrite authnz_ldap"
        for m in $AMODS
        do
            echo "+     enabling $m"
            a2enmod -q $m
        done
    else 
        echo "- CENT/RH Note"
        echo "-    this installer does not check that the contents of "
        echo "-    /etc/httpd/conf.modules.d are appropriate "
        echo "-    you will need to ensure that the proxy proxy_http ssl"
        echo "-    headers rewrite and authnz_ldap modules are enabled "
        echo "-    for scot to work."
    fi

    echo "-"
    echo "- apache install / config completed"
    echo "- apache still needs a restart "
    echo "-"
}

#!/bin/bash

set -e

function prerequisites(){

    if [ -z "$RELAY_DOMAIN" ]; then
        echo >&2 "erreur:  La variable d'environnement RELAY_DOMAIN doit avoir une valeur"
        exit 1
    fi

    if [ -z "$RELAY_HOST" ]; then
        echo >&2 "erreur:  La variable d'environnement RELAY_HOST doit avoir une valeur"
        exit 1
    fi

    if [ -z "$RELAY_PORT" ]; then
        echo >&2 "erreur:  La variable d'environnement RELAY_PORT doit avoir une valeur"
        exit 1
    fi

    if [ -z "$RELAY_USERNAME" ]; then
        echo >&2 "erreur:  La variable d'environnement RELAY_USERNAME doit avoir une valeur"
        exit 1
    fi

    if [ -z "$RELAY_PASSWORD" ]; then
        echo >&2 "erreur:  La variable d'environnement RELAY_PASSWORD doit avoir une valeur"
        exit 1
    fi

    if [ -z "$POSTFIX_ALLOWED_NETWORKS" ]; then
        echo >&2 "erreur:  La variable d'environnement POSTFIX_ALLOWED_NETWORKS doit, au moins, contenir une adresse IP/CIDR"
        exit 1
    fi

}

function setup_postfix_configuration() {

    #configuration générale de postfix
    postconf -e "maillog_file=/dev/stdout" #affichage des logs dans la console
    postconf -e "maximal_queue_lifetime=2d" #vide la queue tous les 2j
    postconf -e "bounce_queue_lifetime=2d" #temps maximum avant qu'un message en file d'attente soit considéré comme non-livrable, doit inférieur ou égal à maximal_queue_lifetime
    postconf -e "biff=no" #désactive les notifications UNIX via biff
    postconf -e "smtputf8_enable=no" #désactive le SMTPUTF8, Alpine ne le supporte pas dans ses binaires
    postconf -e "mydestination=" #désactive l'envoi de mail sur le réseau local

    #configuration des commandes helo/ehlo
    postconf -e "smtpd_delay_reject=yes" #interdit les connexions s'il n'y a pas de commande helo
    postconf -e "smtpd_helo_required=yes" #force l'utilisation de la commande helo (peut éviter certaines tentatives de clients suspects)

    #autorise uniquement les cleint/réseaux approuvés
    #il est possible d'indiquer une IP fixe (ex: 172.24.7.1) mais aussi un réseau complet (ex: 172.24.0.0/21)
    postconf -e "mynetworks=cidr:/etc/postfix/allowed_network_table"

    #configuration de postfix en mode relais
    postconf -e "mydomain=$RELAY_DOMAIN" #domaine à relayer
    postconf -e "relayhost=[$RELAY_HOST]:$RELAY_PORT" #configuration de l'hôte permettant le relais
    postconf -e "relay_domains=" #interdire le relais à partir des domaines inconnus

    #configuration des restrictions pour l'utilisation de postfix
    postconf -e "smtpd_client_restrictions = permit_mynetworks, reject" #seuls les clients/réseaux approuvés peuvent se connecter au serveur SMTP
    postconf -e "smtpd_helo_restrictions = permit_mynetworks, reject_invalid_helo_hostname, reject" #seuls les clients/réseaux approuvés sont autorisés à envoyer une commande helo au serveur SMTP
    postconf -e "smtpd_relay_restrictions = permit_mynetworks, reject" #seuls les clients/réseaux approuvés peuvent relayer à partir du serveur SMTP
    postconf -e "smtpd_sender_restrictions = check_sender_access lmdb:/etc/postfix/allowed_senders, reject" #seuls les expéditeurs approuvés peuvent relayer à partir du serveur SMTP
    postconf -e "smtpd_recipient_restrictions = reject_unknown_recipient_domain, reject_non_fqdn_recipient" #seuls les destinataires appartenant à un domaine valide peuvent recevoir des messages à partir de ce serveur SMTP

    #configuration du client smtp servant de relais
    postconf -e "smtp_tls_loglevel = 1" #active l'activité complémentaire à la négociation TLS
    postconf -e "smtp_use_tls = yes" #toujours utiliser TLS
    postconf -e "smtp_tls_security_level = may"
    postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt" #importe toutes les autorités de certification permettant la vérification des certificats 
    postconf -e "smtp_always_send_ehlo = yes" #toujours envoyer le helo en début de transaction smtp
    postconf -e "smtp_sasl_auth_enable = yes" #active l'authentification sasl pour le client smtp
    postconf -e "smtp_sasl_password_maps = lmdb:/etc/postfix/sasl_passwd" #importe le fichier contenant les informations d'authentification
    postconf -e "smtp_sasl_security_options = noplaintext,noanonymous" #interdire l'authentification avec des mots de passe en clair et interdire l'authentification anonyme
    postconf -e "smtp_sasl_tls_security_options = noplaintext,noanonymous" #interdire l'authentification avec des mots de passe en clair et interdire l'authentification anonyme

    #création du fichier contenant les informations d'identification
    echo "[$RELAY_HOST]:$RELAY_PORT $RELAY_USERNAME:$RELAY_PASSWORD" >> /etc/postfix/sasl_passwd
    #changement de propriétaire
    chown root:root /etc/postfix/sasl_passwd
    #définition des droits en lecture/écriture uniquement
    chmod u+rw /etc/postfix/sasl_passwd

    #mise jour de la table postfix
    postmap /etc/postfix/sasl_passwd

    #suppression du fichier contenant les informations en clair
    rm -f /etc/postfix/sasl_passwd
    #changement de propriétaire du fichier table de postfix
    chown root:root /etc/postfix/sasl_passwd.lmdb
    #définition des droits en lecture/écriture uniquement pour le propriétaire sur le fichier table de postfix
    chmod u+rw /etc/postfix/sasl_passwd.lmdb

    #création du fichier contenant le seul expéditeur pouvant envoyer via le serveur smtp
    echo "$RELAY_USERNAME OK" >> /etc/postfix/allowed_senders

    #changement de propriétaire
    chown root:root /etc/postfix/allowed_senders
    #définition des droits en lecture/écriture uniquement
    chmod u+rw /etc/postfix/allowed_senders
    #mise jour de la table postfix
    postmap /etc/postfix/allowed_senders

    #suppression du fichier
    rm -f /etc/postfix/allowed_senders
    #changement de propriétaire du fichier table de postfix
    chown root:root /etc/postfix/allowed_senders.lmdb
    #définition des droits en lecture/écriture uniquement pour le propriétaire sur le fichier table de postfix
    chmod u+rw /etc/postfix/allowed_senders.lmdb

    #création du fichier contenant les adresses ipv4 ou notation cidr qui sont autorisées à se connecter au serveur
    for network in $POSTFIX_ALLOWED_NETWORKS; do
    echo "$network OK" >> /etc/postfix/allowed_network_table
    done

    #changement de propriétaire
    chown root:root /etc/postfix/allowed_network_table
    #définition des droits en lecture/écriture uniquement
    chmod u+rw /etc/postfix/allowed_network_table

    #ici pas besoin de postmap -q - cdir:<path>, la notation CIDR se faisant en texte clair

    #génération de la base aliases par défaut (inutile dans notre cas, mais évite un message d'avertissement)
    newaliases
}

function run(){

    #vérification des prérequis
    prerequisites

    #configuration de postfix
    setup_postfix_configuration
    echo "postfix configured [relayed domain : $RELAY_DOMAIN]."

    #supprime les instances obselètes de postfix
    rm -f /var/spool/postfix/pid/*.pid

    #démarrage de postfix
    echo "stating Postfix... [allowed host(s) to use this relay : $POSTFIX_ALLOWED_NETWORKS]"
    postfix start-fg
}

run
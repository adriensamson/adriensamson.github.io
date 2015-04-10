---
layout: post
title: Un environnement de dev avec docker
language: fr
---

## Isolation

J'ai toujours un peu peur quand je fais un `sudo npm install -g <module>` sur mon poste.
C'est un peu risqué de donner les droits root à un utilitaire qui va télécharger la moitié de l'Internet.
Et puis comment faire quand deux projets ont besoin de versions différentes d'un même module ?

Dans un autre registre, installer mysql, mongodb et autres sur mon poste, c'est pratique pour commencer à les utiliser mais comment gérer le fait que je ne veux pas les lancer quand je ne travaille pas sur un projet qui les utilise ?

On peut utiliser des machines vitruelles avec VirtualBox et Vagrant mais ce n'est pas super en terme de performances et de partages de fichiers. C'est là que Docker va nous aider (sous linux surtout).

## Sur une application PHP

Sur une applicaton typique PHP/nginx/MySQL, nous allons créer trois containers : un pour mysql, un pour nginx/php-fpm et un pour lancer des scripts PHP.

Par exemple, le Dockerfile pour lancer les scripts contriendra :

~~~
FROM stackbrew/debian:wheezy
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y curl php5-cli
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer
VOLUME /srv
WORKDIR /srv
~~~

Des exemples pour mysql et nginx sont disponibles sur le repo [adriensamson/docker-images](https://github.com/adriensamson/docker-images).

Une fois cette image construite avec `docker build -t myproject-phpcli /path/to/Dockerfile`, on pourra lancer composer dans un container avec `docker run -it -v $PWD:/srv composer install`.
Et puisque cette ligne est un peu longue, on peut la mettre dans un [do-file]({% post_url 2015-04-09-do-file %}) :

~~~
composer () {
    docker run -it -v $PWD:/srv composer $@
}
~~~

De la même manière, on peut utiliser ce container pour accéder à la console symfony et lui donner accès au container mysql :

~~~
startmysql () {
    if docker inspect myproject-mysql 1>/dev/null 2>&1
    then
        if [ $(docker inspect -f '{{ .State.Running }}' myproject-mysql) -eq "false" ]
        then
            docker restart myproject-mysql
        fi
    else
        docker run -itd -v $PWD/var/mysql:/var/lib/mysql --name myproject-mysql adriensamson/mysql
    fi
}

stopmysql () {
    docker stop myproject-mysql
    docker rm myproject-mysql
}

sf () {
    startmysql
    docker run -it -v $PWD:/srv --link myproject-mysql:mysql app/console $@
}
~~~

Depuis la version 1.3, docker ajoute automatiquement les IP des containers liés dans /etc/hosts donc il suffit dans ce cas de configurer `mysql` comme hôte MySQL.


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
# Vous pouvez ajouter d'autres extensions PHP ici
RUN apt-get update && apt-get install -y curl php5-cli php5-curl php5-intl php5-mysql
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer
VOLUME /srv
WORKDIR /srv
~~~

Des exemples pour mysql et nginx sont disponibles sur le repo [adriensamson/docker-images](https://github.com/adriensamson/docker-images).

Une fois cette image construite avec `docker build -t myproject-phpcli /path/to/Dockerfile`, on pourra lancer composer dans un container avec `docker run -it -v $PWD:/srv composer install`.
On ajoute l'option `--rm` pour supprimer le container dès que la commande est terminée.

Il reste un petit problème de droits, puisque `composer` serait lancé en root et donc va installer les vendors en root.
Il y a bien la commande `USER` que l'on peut mettre dans le Dockerfile mais cela nécessite de créer un user et de lui donner le même uid que l'utilisateur qui lancera le container, ce qui pose problème pour réutiliser l'image.
Il est aussi possible de spécifier l'utilisateur à la commande `run` avec `-u` et nous allons lui donner l'uid et le gid de l'utilisateur courant grâce à [id](http://linux.die.net/man/1/id).

Et puisque cette ligne est un peu longue, on peut la mettre dans un [do-file]({% post_url 2015-04-09-do-file %}) :

{% highlight bash %}
composer () {
    docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/srv composer $@
}
{% endhighlight %}

De la même manière, on peut utiliser ce container pour accéder à la console symfony et lui donner accès au container mysql :

{% highlight bash %}
startmysql () {
    # est-ce que le container existe déjà ?
    if docker inspect myproject-mysql 1>/dev/null 2>&1
    then
        # est-ce qu'il faut le redémarrer ?
        if [ $(docker inspect -f '{{ '{{' }} .State.Running }}' myproject-mysql) -eq "false" ]
        then
            docker restart myproject-mysql
        fi
    else
        # les données de la base sont conservés dans ./var/mysql
        docker run -itd -v $PWD/var/mysql:/var/lib/mysql --name myproject-mysql adriensamson/mysql
    fi
}

stopmysql () {
    docker stop myproject-mysql
    docker rm myproject-mysql
}

sf () {
    startmysql
    docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/srv --link myproject-mysql:mysql app/console $@
}
{% endhighlight %}

Depuis la version 1.3, docker ajoute automatiquement les IP des containers liés dans /etc/hosts donc il suffit dans ce cas de configurer `mysql` comme hôte MySQL :

{% highlight yaml %}
doctrine:
    dbal:
        driver: "pdo_mysql"
        host: "mysql"
{% endhighlight %}

Pour lancer nginx c'est à peu près pareil.

{% highlight bash %}
startnginx () {
    startmysql
    if docker inspect myproject-nginx 1>/dev/null 2>&1
    then
        if [ $(docker inspect -f '{{ '{{' }} .State.Running }}' myproject-nginx) -eq "false" ]
        then
            docker restart myproject-nginx
        fi
    else
        docker run -itd -v $PWD:/srv --link myproject-mysql:mysql --name myproject-nginx myproject-nginx
    fi
    
    # on affiche l'IP du container
    docker inspect -f '{{ '{{' }} .NetworkSettings.IPAddress }}' myproject-nginx
}

stopnginx () {
    docker stop myproject-nginx
    docker rm myproject-nginx
}

{% endhighlight %}

Et voilà, on a un environnement de dev avec trois containers : un pour mysql, un pour fpm et nginx et un dernier pour la console php.

Et depuis la version 1.3 de docker, on peut *entrer* dans un container pour débugguer (aller lire les logs d'erreur nginx par exemple) avec `docker exec -it myproject-nginx bash`.

## Container de données

Dernier détail, les bases MySQL sont stockées au milieu du projet dans var/mysql avec les droits d'un user mysql. Pour éviter cela, on peut utiliser un container de données.
C'est un container qui ne lance pas de commande mais qui a juste un système de fichiers pour stocker des données.
Pour cela, il suffit de créer un container avec `docker create` et de l'utiliser avec `--volumes-from`.

{% highlight bash %}
startmysql () {
    # données
    if ! docker inspect myproject-mysql-data 1>/dev/null 2>&1
        docker create --name myproject-mysql-data adriensamson/mysql
    fi

    # serveur mysql
    if docker inspect myproject-mysql 1>/dev/null 2>&1
    then
        if [ $(docker inspect -f '{{ '{{' }} .State.Running }}' myproject-mysql) -eq "false" ]
        then
            docker restart myproject-mysql
        fi
    else
        docker run -itd --volumes-from myproject-mysql-data --name myproject-mysql adriensamson/mysql
    fi
}
{% endhighlight %}

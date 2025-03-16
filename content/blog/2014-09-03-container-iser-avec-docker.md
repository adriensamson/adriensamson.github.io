---
layout: post
title: Container-iser avec docker
language: fr
other_languages:
    en: containerize-with-docker.html
---

Il y deux raisons principales pour lesquelles vous pourriez vouloir *container*-iser vos applications :

* un déploiement facile, cest très important si vous voulez *scaler* en ajoutant des machines dans le *cloud*
* l'isolation, c'est quand vous voulez mutualiser votre machine entre plusieurs services qui nécessitent des versions ou des configurations différentes de php, node ou ruby...

## Isolation

Tous les services que j'héberge ont au plus un utilisateur : moi-même. Donc je me fous de pouvoir *scaler*. Ce que je veux c'est isoler parce que je refuse de lancer `sudo npm install` et de recevoir la moitié de l'Internet sur mon serveur d'emails.

## Docker

[Docker](https://www.docker.com/whatisdocker/) est une surcouche facile à utiliser à [Linux Containers](http://en.wikipedia.org/wiki/LXC) même s'il pourrait supporter d'autres systèmes d'isolation dans le futur.
J'ai essayé autrfois d'utiliser LXC directement mais je ne me rappelle pas avoir réussi un seul `lxc-create`.

Docker vous aide à créer vos propres *containers* avec un `Dockerfile`. C'est une recette avec une liste de commandes à lancer à partir d'une image de base à choisir sur [Docker Hub](https://registry.hub.docker.com/).

## Choisir le bon niveau d'isolation

Quand on parle d'isolation, il faut choisir si l'on sépare absolument tout dans des *containers* différents ou si certains composant peuvent rester ensemble.
Dans une application PHP classique avec php-fpm, nginx et mysql, vous allez mettre mysql dans son propre container. Mais séparer nginx de php-fpm est excessif.


## Trucs et astuces

Déboguer ce qui ne va pas dans votre *container* est difficile au premier abord et vous apprécieriez d'avoir un *shell*. C'est pourquoi tous mes *containers* de démons lancent un *shell*. Notez qu'il faut utiliser les options `-t` et `-i` de `docker run` pour que bash ne se ferme pas immédiatement.

```dockerfile
CMD /etc/init.d/nginx start && bash
```

Vous n'avez pas besoin d'exposer les ports du *container* sur la machine hôte. La plupart du temps, ce dont vous avez réellement besoin est l'adresse IP du *container*.

```bash
docker inspect --format='{{ "{{" }} .NetworkSettings.IPAddress }}' $CONTAINER
```

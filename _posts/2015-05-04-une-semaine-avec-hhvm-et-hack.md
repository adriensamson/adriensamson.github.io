---
layout: post
language: fr
title: Une semaine avec HHVM et Hack
---

## Hack

[Hack](http://hacklang.org/) est un langage créé par Facebook au-dessus de PHP qui ajoute des fonctionnalités telles que
du [typage poussé](http://docs.hhvm.com/manual/en/hack.annotations.php), des nouvelles [formes de tableaux](http://docs.hhvm.com/manual/en/hack.collections.php) et de l'[asynchrone](http://docs.hhvm.com/manual/en/hack.async.php). 

J'ai voulu l'essayer principalement pour les apports du typage.
Et le typage, ce n'est pas seulement mettre des *type hint* qui sont vérifiés pendant l'exécution du code.
C'est aussi (et surtout) permettre une analyse statique du code qui détecte les incohérances entre les types déclarés et le code.

HHVM embarque Hack par défaut et on peut le mélanger avec du code PHP classique, il fournit aussi l'analyseur statique `hh_client`.
Pour analyser le code, il suffit de créer un fichier `.hhconfig` vide à la racine du projet et de lancer `hh_client src/`.

## Mise en place

Pour vérifier que les fichiers convertis en Hack fonctionnent toujours comme prévu, il suffit de lancer les tests.
En effet, PHPUnit fonctionne bien avec HHVM et il est tout à fait possible de tester une classe écrite dans un fichier Hack avec un test écrit dans un fichier PHP.

Facebook propose des [dépots](https://github.com/facebook/hhvm/wiki/Prebuilt-Packages-for-HHVM) pour installer facilement HHVM.
J'ai donc pu créer très rapidement une [image docker avec nginx](https://github.com/adriensamson/docker-images/tree/master/nginx-hhvm) et vérifier que mon application fonctionnait toujours.

## HHVM avec nginx et symfony

### Erreurs fatales

Le premier problème que j'ai rencontré en essayant de faire tourner une application symfony était une page blanche sur une erreur fatale.
J'ai pu retrouver l'erreur dans le profiler mais ce n'est pas très pratique.
Après un peu de [recherche](https://github.com/facebook/hhvm/issues/4818), il s'avère que c'est juste que l'*ErrorHandler* de Symfony ne fait pas de `flush()`.
Ce qui peut être corrigé très facilement en ajoutant `hhvm.server.implicit_flush = 1` dans la configuration HHVM.

Cette gestion des erreurs fatales par Symfony utilise la fonction `error_get_last()`.
Avec HHVM, cette fonction ne renvoie pas les bonnes informations de fichier et de ligne pour les erreurs fatales, alors qu'elle est correcte dans le log d'erreur natif.
J'ai donc fait une [PR](https://github.com/facebook/hhvm/pull/5221) pour corriger cela.

### Sessions

J'ai rencontré un autre problème, un peu plus tordu, au niveau des sessions.
La gestion des sessions par défaut de Symfony pose problème dès qu'il y a une propriété privée à sérialiser dans la session, c'est-à-dire dès qu'on essaye de connecter un utilisateur.
Il existe un contournement qui consiste à désactiver le session handler par défaut et à démarrer la session à la main dans `app.php`

{% highlight yaml %}
# config.yml
framework:
    session:
        handler_id: ~
{% endhighlight %}

{% highlight php %}
<?php // app_dev.php
session_save_path(__DIR__.'/../app/cache/dev/sessions');
session_start();
{% endhighlight %}

Mais c'est quand même mieux de [faire une PR](https://github.com/facebook/hhvm/pull/5212) pour corriger HHVM.

## Et ensuite ?

Ensuite, ce serait intéressant de faire passer tous les tests de Symfony avec HHVM.
Malheureusement, il y a pas mal de boulot et les tests ne sont pas forcément représentatifs de l'utilisation réelle du framework.
Il est sûrement plus simple, et surtout plus efficace, de faire fonctionner des applications complètes.

Donc si vous avez une application que vous voulez passer sur HHVM, contactez-moi !

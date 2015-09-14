---
layout: post
title: Cordova, pour des applications multi-plateformes
language: fr
---

## Cordova et PhoneGap

[Cordova](http://cordova.apache.org) est plus connu sous le nom de [PhoneGap](http://phonegap.com).
En 2011, le code de PhoneGap a été donné à la fondation Apache, et PhoneGap n'est maintenant qu'une surcouche à Cordova, ainsi qu'une plateforme de compilation SaaS : [PhoneGap Build](https://build.phonegap.com).

Cordova permet de créer des applications mobiles en HTML et Javascript pour les différentes plateformes qui existent.
Ce qui permet de déployer une application iOS ou Android sans écrire une seule ligne d'Objective-C ou de Java.

Cordova propose un système de plugins pour accéder aux fonctions natives des appareils en utilisant une API la plus commune possible entre les plateformes.
Certains plugins sont officiels et développés sous la bannière de la fondation Apache (pour accéder au système de fichiers, à l'état des connexions, …) et supportent toutes les plateformes, d'autres sont communautaires (achats in-app, …) et ne supportent que quelques plateformes (généralement iOS, Android et Windows dans cet ordre).

## Multi-plateforme

Il n'existe pas d'environnement de développement universel multi-pateforme.
Pour développer, tester et déboguer une application iOS construite avec Cordova, il faut travailler avec la plateforme `ios` sur un ordinateur MacOS avec XCode et Safari; pour une application Windows, il faut travailler sous Windows avec VisualStudio.

L'utilisation naïve de Cordova est donc de générer une application par plateforme et de travailler séparément sur les différentes applications.
Mais on perd l'intérêt principal de l'utilisation de Cordova : avoir une seule base de code pour les différentes plateformes et ne pas s'embêter à reporter à la main les corrections ou évolutions.

Pour garder une application multi-plateforme, il faut donc faire attention à ne jamais modifier ce qui est généré par cordova pour une plateforme donnée.
C'est pour cela que l'on va ignorer le dossier `platforms/` dans son gestionnaire de code et tester régulièrement que supprimer et ajouter la plateforme permet de retrouver la même chose.

De la même manière, XCode et VisualStudio étant lancés depuis un répertoire de travail spécifique à la plateforme, il ne faut les utiliser que pour lancer l'application et déboguer.
On préférera donc travailler dans son IDE préféré à la racine du projet, quitte à lancer la commande `cordova prepare` très souvent pour mettre à jour l'espace de travail de la plateforme.

## Et quand on veut des différences ?

Il arrive parfois que l'on ait besoin de faire les choses différemmment d'une plateforme à l'autre, que ce soit un besoin ergonomique ou un problème de compatibilité des plugins.

Dans ce cas on utilise le mécanisme de `merge` de cordova : lors de la phase `prepare` (qui correspond grossièrement à la copie des sources globales dans le dossier de la plateforme),
les fichiers présents dans le dossier `merges/<platform>/` remplaceront ceux qui sont globaux.

Ceci permet donc de faire diverger finement les différentes versions tout en gardant une base de code unique.


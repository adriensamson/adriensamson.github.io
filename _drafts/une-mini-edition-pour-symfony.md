---
layout: post
title: Une mini édition pour Symfony
language: fr
---

## Pourquoi ?

En créant une application Symfony à partir de l'édition standard,
j'ai souvent eu l'impression de quasiment tout supprimer (doctrine-bundle, distribution-bundle pour ne citer qu'eux) parce que je n'en avait pas l'utilité.
J'ai donc commencé à initialiser mes applications Symfony à la main en ne créant que les fichiers nécessaires : `composer.json`, `AppKernel.php`, `config.yml`, `index.php` et `console`.

Mais il y a quelques détails un peu compliqués (comme la gestion de `console --env=`) que je finis toujours pas copier-coller depuis l'édition standard. Et j'ai donc créé cette mini-édition.

## Partis pris

J'ai choisi de ne dépendre que de `symfony/symfony`. Ceci a quelques conséquences comme l'absence de gestion des logs et la gestion manuelle du `parameters.yml`.
Par contre `twig` est bien inclus, et heureuseument, parce qu'il est nécessaire pour avoir des jolies pages d'erreur et le web profiler.

J'ai repris globalement la structure de répertoires qui devrait être utilisée pour Symfony 3 : cache et logs dans `var/`, console dans `bin/`.

Au niveau de la config, il n'y a pas de `config_env.yml` par environnement mais seulement un `config.yml` global et un `config_dbg.yml` ajouté en mode debug pour le web profiler.

J'ai choisi de mettre `AppKernel.php` dans `src/`, ainsi il est géré lui-aussi par l'autoloader de composer.

Le fichier d'entrée principal dans `web` s'appelle `index.php`, ce qui permet d'être en environnement de prod par défaut. Pour passer en dev/debug, il y a `dbg.php`.


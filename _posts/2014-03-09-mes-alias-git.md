---
layout: post
title: Mes alias git
language: fr
other_languages:
    en: my-git-aliases.html
---
## Commandes les plus utilisées

Quand je travaille sur un projet chez [M6Web](http://tech.m6web.fr), je fais toujours à peu près ça :

{% highlight sh %}
git checkout master
git pull --ff-only origin master
git checkout -b my-new-feature
# Code...
git status
git add -A
git diff --staged
git commit
git push origin my-new-feature
{% endhighlight %}

Vu que j'utilise ces commandes très souvent, je les ai abbrégé pour ne faire qu'une ou deux lettres :

{% highlight sh %}
git co master
git u
git co -b my-new-feature
# Code...
git s
git a
git ds
git ci
git p
{% endhighlight %}

## Autres alias

Je suis incapable de lire la sortie de `git log` sans les options `--graph --decorate` donc j'ai ajouté `git l` pour ça.
J'ai aussi `git r` pour `git pull --rebase` et `git d` pour `git diff`.

Tous ces alias sont dans mon repo [git-utils](https://github.com/adriensamson/git-utils).

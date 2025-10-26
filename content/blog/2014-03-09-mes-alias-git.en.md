+++
title = "My git aliases"
+++
## Most used commands

When I'm working on a project at [M6Web](http://tech.m6web.fr), my workflow is almost always like this:

```bash
git checkout master
git pull --ff-only origin master
git checkout -b my-new-feature
# Code...
git status
git add -A
git diff --staged
git commit
git push origin my-new-feature
```

Since I run these commands very often, I've abbreviated them to 1 or 2 letters:
```bash
git co master
git u
git co -b my-new-feature
# Code...
git s
git a
git ds
git ci
git p
```

## Other aliases

I can't read `git log` output without `--graph --decorate` options so I added `git l` for that.
I also have `git r` for `git pull --rebase` and `git d` for `git diff`.

All these aliases are in my [git-utils](https://github.com/adriensamson/git-utils) repository.

#!/usr/bin/env sh

serve () {
    bundle exec jekyll serve $@
}

watch () {
    serve --watch $@
}

if [ $# -eq 0 ]
then
    serve
    exit
fi

$@

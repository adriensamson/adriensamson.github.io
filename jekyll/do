#!/usr/bin/env sh

serve () {
    jekyll serve $@
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

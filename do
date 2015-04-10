#!/usr/bin/env sh

serve () {
    bundle exec jekyll serve $@
    #docker run -it adriensamson/github-pages jekyll serve $@
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

#!/usr/bin/env sh

serve () {
    docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/srv -p 4000:4000 adriensamson/github-pages jekyll serve $@
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

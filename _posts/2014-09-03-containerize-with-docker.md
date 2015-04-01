---
layout: post
title: Containerize with docker
language: en
---

There are mainly two reasons why you may want to containerize your apps:

* easy deployment, that's really important if you want to scale up by adding machines in the cloud
* isolation, that's when you want to mutualize your machine between some services that may need different app (php, node, ruby...) versions or configurations

## Isolation

Almost all services I host have at most one user: myself. So I don't mind scaling to say the least. What I want is isolation because I don't want to `sudo npm install` half of the internet on my email server.

## Docker

[Docker](https://www.docker.com/whatisdocker/) is an easy-to-use wrapper to [Linux Containers](http://en.wikipedia.org/wiki/LXC) even if it may support other isolation systems in the future.
I tried to directly use LXC in the past but I can't remember of a successful `lxc-create`.

Docker helps you create your own containers with a `Dockerfile`. It's a recipe with a list of commands to run from a base image that you choose from [Docker Hub](https://registry.hub.docker.com/).

## Choose the right level of isolation

When it comes to isolation, you have to choose whether you split everything in different containers or some pieces should be kept together.
In a typical PHP application with php-fpm, nginx and mysql, you'd put mysql in its own container. But separating nginx and php-fpm is mostly overkill.

## Tips and tricks

Debugging what's wrong in your container is hard at first sight and you'd like to have a shell. That's why all my daemon containers are running a shell. Note that you must use `-t` and `-i` docker run options for bash to not exit immediately.

~~~
CMD /etc/init.d/nginx start && bash
~~~

You don't have to expose the container's ports on the host. Most of the time, What you really need is the IP address of the container.

~~~sh
docker inspect --format='{{ "{{" }} .NetworkSettings.IPAddress }}' $CONTAINER
~~~


# docker-phpfpm-various

This is a Docker container [fanat98/docker-phpfpm-various] based on [sinso/docker-phpfpm-flow].

# Maintenance
## Create dumps

You can create dumps (containing htdocs folder, share folder and database dump) with the `dump` command. There are no credentials necessary to run this command. Optionally you can pass a password. Otherwise one will be generated automatically.

* Create dump

```sh
docker exec <DOCKER-CONTAINER-NAME> dump
```

* Create dump with custom password

```sh
docker exec <DOCKER-CONTAINER-NAME> dump iWantToUseThisPasswordInsteadOfAGeneratedOne
```
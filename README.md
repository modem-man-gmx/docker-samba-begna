# docker-samba
## About

[Samba](https://wiki.samba.org) Docker image based on Alpine Linux and [crazy-max docker-samba](https://github.com/Axia-SA/docker-samba) repository.<br />
This container includes a web service discovery (wsdd, using `smbd`) to make the server discoverable by all Windows PCs on the same workgroup. Also, can recover custom user settings and passwords from samba TDB files (**T**rivial **D**ata**B**ase).

Instead build from scratch this container, you can pull it from [docker hub](https://hub.docker.com/r/cbottazzi/docker-samba) or download only the `docker-compose.yml` and the `config.yml` file on [examples/compose/](examples/compose/data/config.yml).

___

* [Features](#features)
* [Build locally](#build-locally)
* [Environment variables](#environment-variables)
* [Volumes](#volumes)
* [Ports](#ports)
* [Configuration](#configuration)
* [Import custom user passwords and preferences](#import-custom-user-passwords-and-preferences)
* [Usage](#usage)
  * [Docker Compose](#docker-compose)
  * [Command line](#command-line)
* [Notes](#notes)
  * [Status](#status)
* [Upgrade](#upgrade)
* [Contributing](#contributing)
* [License](#license)

## Features

* Easy [configuration](#configuration) through YAML
* Improve [operability with Mac OS X clients](https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X)
* This version mantains some support for legacy protocols including NetBIOS
* Backup and restore custom user passwords and settings

## Build locally

```shell
git clone https://github.com/Axia-SA/docker-samba.git
cd docker-samba

# Build image and output to docker (default)
docker buildx bake

# Build multi-platform image
docker buildx bake image-all
```

## Environment variables

* `TZ`: Timezone assigned to the container (default `UTC`)
* `SAMBA_WORKGROUP`: NT-Domain-Name or [Workgroup-Name](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#WORKGROUP). (default `WORKGROUP`)
* `SAMBA_SERVER_STRING`: [Server string](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#SERVERSTRING) is the equivalent of the NT Description field. (default `Docker Samba Server`)
* `SAMBA_LOG_LEVEL`: [Log level](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#LOGLEVEL). (default `0`)
* `SAMBA_FOLLOW_SYMLINKS`: Allow to [follow symlinks](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#FOLLOWSYMLINKS). (default `yes`)
* `SAMBA_WIDE_LINKS`: Controls whether or not links in the UNIX file system may be followed by the server. (default `yes`)
* `SAMBA_HOSTS_ALLOW`: Set of hosts which are permitted to access a service. (default `127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16`)
* `SAMBA_INTERFACES`: Allows you to override the default network interfaces list.
* `SAMBA_DISABLE_NETBIOS`: Disable NetBIOS for older connections. Values can be `yes` or `no` (default is `yes`)

> More info: https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html

## Volumes

* `/data`: Contains cache, configuration and runtime data

## Ports

* `137/udp`: NetBIOS Name Service
* `138/udp`: NetBIOS Datagram
* `139/tcp`: NetBIOS Session
* `445/tcp`: Samba Server over TCP

> More info: https://wiki.samba.org/index.php/Samba_NT4_PDC_Port_Usage

## Configuration

Before using this image you have to create the YAML configuration file `/data/config.yml` to be able to create users,
provide global options and add shares. Here is an example:

```yaml
auth:
  - user: foo
    uid: 1000
    gid: 1000
    password: bar
  - user: baz
    uid: 1100
    gid: 1200
    password_file: /run/secrets/baz_password

global:
  - "force user = foo"
  - "force group = foo"

share:
  - name: foo
    path: /samba/foo
    browsable: yes
    readonly: no
    guestok: no
    validusers: foo
    writelist: foo
    veto: no
```

`veto: no` is a list of predefined files and directories that will not be
visible or accessible:

```
/._*/.apdisk/.AppleDouble/.DS_Store/.TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/Temporary Items/Thumbs.db/
```

More info: https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#VETOFILES

A more complete example is available [here](examples/compose/data/config.yml).

## Import custom user passwords and preferences

You can also use an existing TDB files to import previous custom settings like encrypted passwords that can not be stored on files under the `password_file` parameter on `config.yml`.

To achieve this, put the `passdb.tdb` and `secrets.tdb` files (or any `*.tdb` files) on `config/`. This files will be imported while the container is being building.

> Notice: TDB files must be consistent with `config.yml` file to work properly

## Usage

### Docker Compose

Docker compose is the recommended way to run this image. Copy the content of folder [examples/compose](examples/compose)
in `/var/samba/` on your host for example. Edit the compose and configuration files with your preferences and run the
following commands:

```bash
docker-compose up -d
docker-compose logs -f
```

### Command line

You can also use the following minimal command:

```shell
docker run -d --network host \
  -v "$(pwd)/data:/data" \
  --name samba cbottazzi/docker-samba
```

## Upgrade

Recreate the container when exists an update:

```bash
docker-compose pull
docker-compose up -d
```

## Notes
### Status

Use the following commands to check the logs and status:

```shell
docker-compose logs samba
docker-compose exec samba smbstatus
```

## Contributing

Want to contribute? Awesome! The most basic way to show your support is to star the project, or to raise issues. You can also support this project by [**becoming a sponsor on GitHub**](https://github.com/sponsors/cristian1604).

Thanks again for your support, it is much appreciated! :pray:

## License

MIT. See `LICENSE` for more details.

+++
categories = ["Administration", "Hyperion"]
date = "2016-01-29T09:33:12+02:00"
description = """
Création de la première VM - notre routeur/firewall
"""
tags = ["linux", "xen", "admin", "network", "dnsmasq"]
title = "Hyperion, routeur tout-en-un: Round 3 - Tethys"
toc = true
prev = "/post/hyperion-part-3/"
next = "/post/hyperion-part-5/"
+++

Voilà, toute la tuyauterie coté dom0 est en place, il nous faut maintenant créer
le domU du routeur-firewall, nommé `tethys`.

<!--more-->

# xen-create-image
Xen est fourni avec une série d'outils pour faciliter la mise en place de VMs
(paquet `xen-tools`), utilisons les !

```sh
xen-create-image --verbose --hostname=tethys --memory=128M --vcpus=1 --size=2G --swap=128M --lvm=vg0 --nodhcp --pygrub --dist=jessie
```

Cette commande va utiliser [debootstrap][] et une série de script pour générer une
image Debian bootable. Les options sont plutôt explicite et parlent d'elle-même:
128M de RAM, 1 Virtual CPU, 2G de disque, 128M de SWAP, disque et SWAP à créer
sur `vg0`, pas de DHCP, [pygrub][] (un emulateur de GRUB en python adapté à
Xen), et la version de Debian: Jessie (Debian 8).

[debootstrap]: https://wiki.debian.org/fr/Debootstrap
[pygrub]: https://wiki.xen.org/wiki/PyGrub

Laisse la magie opérer... Devant un petit café éventuellement :wink:

À la fin, le script donnera un petit résumé, le plus important ici c'est de
copier le mot de passe root dans un coin !

# Petits ajustements
De base, `xen-create-image` prépare des VMs simples, en particulier, elles ne
possèdent qu'une seule interface réseau. Ici, on veut faire un routeur, avec X
interfaces. On va donc ajuster quelques peu le fichier de configuration de la
VMs

Le voici:

```sh
#
# Configuration file for the Xen instance tethys, created
# by xen-tools 4.5 on Mon Dec 28 07:25:34 2015.
#

#
#  Kernel + memory size
#


bootloader = '/usr/lib/xen-4.4/bin/pygrub'

vcpus       = '1'
memory      = '128'


#
#  Disk device(s).
#
root        = '/dev/xvda2 ro'
disk        = [
                  'phy:/dev/vg0/tethys-disk,xvda2,w',
                  'phy:/dev/vg0/tethys-swap,xvda1,w',
              ]


#
#  Physical volumes
#


#
#  Hostname
#
name        = 'tethys'

#
#  Networking
#
#dhcp        = 'dhcp'
vif         =	[ 
	 	'mac=00:16:3E:CA:6B:D0,bridge=brinet0', 
		'mac=00:16:3E:CA:6B:D1,bridge=brlan0',
		'mac=00:16:3E:CA:6B:D2,bridge=brap0', 
		'mac=00:16:3E:CA:6B:D3,bridge=brdmz0', 
		'mac=00:16:3E:CA:6B:D4,bridge=brcmz0', 
		'mac=00:16:3E:CA:6B:D5,bridge=brcluster0' 
		]

#
#  Behaviour
#
on_poweroff = 'destroy'
on_reboot   = 'restart'
on_crash    = 'restart'
```

La grande différence est la variable `vif`, je défini 6 interfaces réseau liées
aux 6 bridges présents sur Hyperion (Je suggère de rejetter un coup d'oeil sur
le [schéma][schm] du réseau virtuel). J'y défini aussi leur adresse MAC.

[schm]: /post/hyperion-part-3/#schéma-en-ascii

# Premier boot
Rien de plus simple:

```sh
xl create /etc/xen/tethys.cfg
```

Afin que la VMs démarre automatiquement avec Hyperion il faut faire cela:

```sh
mkdir /etc/xen/auto
ln -s ../tethys.cfg /etc/xen/auto/tethys.cfg
```

La machine a booté, on peut la voir avec `xentop`.

Théoriquement, on pourrait se connecter en SSH dessus directement, mais
actuellement, 2 choses ne vont pas: 

* Pas de DHCP, donc aucunes des 6 interfaces ne possèdent d'adresse IP
* Le serveur SSH installé par défaut n'accepte pas que root se connecte en
  utilisant un mot de passe (uniquement des clés SSH) et aucun utilisateur n'a
  été créé.
  
# Configuration réseau
Commençons pas nous connecter sur la machine. Sans SSH c'est possible car xen
fourni une console virtuelle sur port série.

Un simple `xl console tethys` et nous y voilà, login: root, password: celui
copier lors de la création de la VM. Pour quitter la console un simple `ctrl-]`
suffit.

Comme sur Hyperion, on va donner des noms un peu plus parlants que eth0, eth1,
eth2, etc...

Dans `/etc/udev/rules.d/70-persistent-net.rules`:

```sh
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="00:16:3e:ca:6b:d0", NAME="inet0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="00:16:3e:ca:6b:d1", NAME="lan0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="00:16:3e:ca:6b:d2", NAME="ap0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="00:16:3e:ca:6b:d3", NAME="dmz0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="00:16:3e:ca:6b:d4", NAME="cmz0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="00:16:3e:ca:6b:d5", NAME="cluster0"
```

Et dans la foulée, on va aussi donner des adresses IP a tout ce petit monde.

Dans `/etc/network/interfaces`:

```sh
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

auto inet0
iface inet0 inet static
	address 192.168.1.1
	netmask 255.255.255.0
	gateway 192.168.1.254

auto lan0
iface lan0 inet static
	address 10.0.0.1
	netmask 255.255.0.0		

auto ap0
iface ap0 inet static
	address 10.1.0.1
	netmask 255.255.0.0		

auto dmz0
iface dmz0 inet static
	address 10.5.0.1
	netmask 255.255.0.0

auto cmz0
iface cmz0 inet static
	address 10.6.0.1
	netmask 255.255.0.0

auto cluster0
iface cluster0 inet static
	address 10.10.0.1
	netmask 255.255.0.0
```

Et aussi, pourquoi, ajoutons notre clé SSH aux clés authorisées pour root (si
vous n'avez pas de clé SSH, utilisez `ssh-keygen`):

```sh
mkdir /root/.ssh
cat > /root/.ssh/authorized_keys
<copiez-collez votre clé publique ici (~/.ssh/id_rsa.pub) et terminez par ctrl-d>
```

Voilà, et hop ! Un reboot !

En principe, on peut maintenant se connecter en SSH sur tethys avec un `ssh root@10.0.0.1`.

# Init
Par défaut, Debian 8 est installé avec systemd, personnellement je n'ai rien
contre, il s'avère même très pratique sur les machines desktop (en plus sous
Arch Linux il n'y a que lui). Par contre pour un serveur comme `tethys`, je vais
préférer le system de boot classique: [init][].

[init]: https://fr.wikipedia.org/wiki/Init

1. `apt-get --purge install sysvinit-core`
2. `echo "co:2345:respawn:/sbin/getty hvc0 9600 linux" >> /etc/inittab` (c'est
   pour avoir la console série virtuelle avec Xen (xl console tethys))
2. `reboot`
3. `apt-get --purge remove systemd`

# routage et NAT
Bon c'est pas mal, mais ça route pas ! Par défaut linux ne route pas les paquets
entre les interfaces. On va remèdier à cela.

Dans un fichier créé pour l'occasion `/etc/sysctl.d/50-forwarding.conf`:

```sh
net.ipv4.ip_forward=1
net.ipv4.conf.default.forwarding=1
net.ipv4.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
```

Voilà, routage IPv4 et IPv6.

Ensuite, le NAT, la box du FAI ne connait rien du réseau 10.x.x.x, On va donc
faire du NAT sur `tethys` en utilisant [Netfilter][], le framework du kernel
pour tout ce qui touche de près ou de loin au firewall.

[netfilter]: https://fr.wikipedia.org/wiki/Netfilter

```sh
iptables -t nat -A POSTROUTING -o inet0 -j MASQUERADE
```

En principe, maintenant, on peut se connecter sur internet à condition
d'utiliser le DNS de la Box (192.168.1.254). On va arranger ça tout de suite.

# DNS et DHCP
Je pourrais installer [Bind][] et [DHCPD][], mais autant DHCPD ça va, autant
Bind c'est vraiment trop pour nos besoins. Il existe
mieux: [dnsmasq][]. Wikipedia dit "petits réseaux famillial" mais il peut
parfaitement gérer tout un réseau d'entreprise à lui tout seul si on a pas
besoin de fonctions avancées comme le transfert de zone, le stockage de zone
dans des bases de données, etc... Dnsmasq est typiquement un cache DNS de
résolution de nom de domaine avec DHCP intégré (il fait même TFTP et Boostrap
pour booter vos machine par le réseau). En plus, la configuration est très simple.

[bind]: https://fr.wikipedia.org/wiki/BIND
[dhcpd]: https://en.wikipedia.org/wiki/DHCPD
[dnsmasq]: https://fr.wikipedia.org/wiki/Dnsmasq

Allez !

```
apt-get install dnsmasq
```

Dans `/etc/dnsmasq.d/10core.conf` (n'importe quel nom en .conf conviendrait):

```
# The domain
domain=rxsoft.eu

# Do not read resolv.conf
no-resolv

# Upstream servers
## OpenNic (http://servers.opennicproject.org/)
### Any Cast
server=185.121.177.177
server=2a05:dfc7:5::53
server=185.121.177.53
server=2a05:dfc7:5::5353
server=185.190.82.182
server=2a0b:1904:0:53::
### FR
server=87.98.175.85
server=2001:41d0:2:73d4::100
### FR
server=5.135.183.146
server=2001:41d0:8:be92::1
### DE
server=5.9.49.12
server=2a01:4f8:161:4109::6
### IT
server=193.183.98.154
server=2a00:dcc0:eda:98:183:193:d85a:389b
### NL
server=185.133.72.100
server=2a05:b0c6:5e4::53
### RO
server=89.18.27.34
server=2001:470:1f15:235::1
## FreeDNS
#server=37.235.1.174
#server=37.235.1.177
## Google
#server=8.8.8.8
#server=8.8.4.4
## ISP box DNS
#server=192.168.1.254

# On which interface to listen for DNS/DHCP request
interface=lan0
interface=ap0
interface=dmz0
interface=cmz0
interface=cluster0
no-dhcp-interface=dmz0
no-dhcp-interface=cmz0
no-dhcp-interface=cluster0

# Don not read /etc/hosts
no-hosts
# Read this one instead
addn-hosts=/etc/hosts.local
# Expand name without dot with the local domain name in the hosts file
expand-hosts
```

* J'ai mis une longue liste de DNS "libres" pour être sûr de na pas avoir de
  coupure au niveau du DNS.
* Je lui dit de travailler sur toutes les interfaces sauf celle connectée à la
  box du FAI.
* DHCP uniquement pour le LAN et le WIFI, les autres sous réseaux seront en IP
  statique.
* Le fichier `/etc/hosts.local` sera une mini DB de nom DNS locaux, au même
  format que `/etc/hosts`.
  
Et dans `/etc/dnsmasq.d/20dhcp.conf`:

```
dhcp-range=10.0.0.10,10.0.0.200,2h
dhcp-range=10.1.0.10,10.1.0.200,2h
dhcp-option=option:dns-server,10.0.0.1
dhcp-authoritative
```

* Les plages d'adresses IP pour les sous réseau du LAN et du WIFI.
* Où se trouve le serveur DNS.
* Le DHCP est le seul du réseau.

Et voilà ! Un petit redémarrage de dnsmasq et tout l'Internet devrait s'ouvrir a
vous.

Il reste un petit quelques chose à faire, rendre les réglages Netfilter
persistants entre les reboot.

Il y a plusieurs solutions, je vais prendre la plus élémentaire: 3 lignes dans
`/etc/rc.local`. Mais il y a aussi le paquet `iptables-persistent` par exemple.

Dans `/etc/rc.local`:

```sh
# Active le NAT sur inet0
iptables -t nat -A POSTROUTING -o inet0 -j MASQUERADE

# Il y a un bug dans dnsmasq (ou dhcp-client, je suis pas sûr) qui fait que le
# checksum UDP est incorrect, ces 2 règles Netfilter arrange le problème.
iptables -t mangle -A POSTROUTING -o lan0 -p udp -m udp --dport 68 -j CHECKSUM --checksum-fill
iptables -t mangle -A POSTROUTING -o ap0 -p udp -m udp --dport 68 -j CHECKSUM --checksum-fill
```

# Le prochain post
Au [prochain post][next], Il faudra se concentrer sur les réglages kernel et
Netfilter pour la sécurité.

[next]: /post/hyperion-part-5/

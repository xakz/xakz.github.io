+++
categories = ["Administration", "Hyperion"]
date = "2016-01-16T09:20:34+02:00"
description = """
Création d'un serveur tout-en-un, avec toutes les
fonctionnalités dont un devOps peut rêver: Introduction"""
tags = ["linux", "xen", "admin", "hardware", "network"]
title = "Hyperion, routeur tout-en-un: Round 0 - Préambule"
toc = true
next = "/post/hyperion-part-2/"
+++

L'idée c'est de nous faire une machine **vraiment-tout-en-un** à pas trop
cher. Ça tombe bien on avait justement une carte mère avec son processeur plutôt
pas mal qui traînait à la maison. c'est
une [MSI B75MA-E33](https://www.msi.com/Motherboard/B75MA-E33.html) avec
un
[Celeron G1610](http://ark.intel.com/products/71072/Intel-Celeron-Processor-G1610-2M-Cache-2_60-GHz).
Alors OK, les gamers vont me huer ici, mais je rappelle que le but c'est de
minimiser la consommation en maximisant des fonctionnalités. Et il y a tout ce
qu'il faut: **1Gbps**, **USB3**, **SATA 6Gb/s**, **HDMI**, **virtualisation**,
et même un petit format pour rentrer dans tous les boîtiers.

# C koikonveu ? (ou "cahier des charges" pour les puristes)
Voilà ce que nous voulons avoir comme service basiques:

 * [Routeur](https://fr.wikipedia.org/wiki/Routeur)
 * [Firewall](https://fr.wikipedia.org/wiki/Pare-feu_(informatique))
 * [DNS](https://fr.wikipedia.org/wiki/Domain_Name_System)
 * [DHCP](https://fr.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol)
 * [Access Point Wifi](https://fr.wikipedia.org/wiki/Point_d%27acc%C3%A8s_sans_fil)
 * [IPv6](https://fr.wikipedia.org/wiki/IPv6)
 * [VPN](https://fr.wikipedia.org/wiki/R%C3%A9seau_priv%C3%A9_virtuel)
 * [QoS](https://fr.wikipedia.org/wiki/Qualit%C3%A9_de_service)
 * [Virtualisation](https://fr.wikipedia.org/wiki/Virtualisation)
 * [NAS](https://fr.wikipedia.org/wiki/Serveur_de_stockage_en_r%C3%A9seau)
 * [Proxy](https://fr.wikipedia.org/wiki/Proxy) apt-get pour nos machines
   sous [Debian](http://www.debian.org)
 * Proxy pacman pour nos machines sous [Arch Linux](https://www.archlinux.org/)
 * Et la cerise sur le gâteau, faire tourner deux [Kodi](https://kodi.tv/)
   indépendants, un sur chacune de nos télé grâce
   au [multiseat](https://en.wikipedia.org/wiki/Multiseat_configuration)
 * Le tout avec le plus de sécurité possible
 
Bien-sûr à cela s'ajouteront les service futures. Je ferai un post descriptif à
chaque fois, du moins lorsque cela en vaut la peine :wink:.

Pour les impatients, mordus de ligne de commande et assoiffés du tourne vis, vous
pouvez tout de suite passer à la [suite](/post/hyperion-part-2) si vous le souhaitez.
 
# Pourquoi faire tout ça ?
## DevOps, it's FUN !
Je sais pas vous, mais moi j'adore administrer des réseaux et des systèmes sous
**GNU/linux**, ou sous **BSD** d'ailleurs, c'est juste que j'y suis moins
habitué. Quoi de mieux pour s'amuser dans ce cas qu'une petite installation de
machines virtualisées ?

## Marre des "box" partout !
On est tous un peu dans le même cas je pense, dès que l'on commence a s'équiper
en matériel internet ou multimédia, on a tous des "box" de tout genre, une pour
internet, une pour la wifi, une pour chaque télé, une pour le NAS, etc...

Évidement, chacune de ces "box" ou presque tourne avec un firmware propriétaire
différent, sur lequel on a aucun contrôle, dont les fonctionnalités, pour un
utilisateur chevronné, laissent réellement à désirer.

Et puis bon, ça fini par s'accumuler niveau consommation électrique, 10W par ci,
5W par là, avec des alimentations que ne sont même pas
a [découpage](https://fr.wikipedia.org/wiki/Alimentation_%C3%A0_d%C3%A9coupage)
la plupart du temps, donc l'alimentation consomme autant lorsque l'appareil est
en "idle" que lorsqu'il est en pleine utilisation. Heureusement, ces dernières
années, ce dernier point s'est largement amélioré.

Exemple: la "box" ADSL:

 * Pas de [QoS](https://fr.wikipedia.org/wiki/Qualit%C3%A9_de_service).
   Résultat: si Monsieur télécharge la dernière
   ISO [Debian](http://www.debian.org) en regardant des vidéos sur Youtube pour
   passer le temps, aucune chance pour que Madame puisse jouer a un de ses jeux
   favoris en ligne sans subir des ralentissements.
 * Les ports sont en 100Mbps... sérieusement ? Résultat: Obligé de rajouter un
   switch 1Gbps en aval. Hop ! Une autre "box".
 * La configurabilité est souvent restreinte, change d'un modèle à l'autre,
   d'une mise à jour à l'autre, et même parfois, les paramètres sont remis par
   défaut lors d'une de ces mise à jour, du coup, plus d'internet... Ça a le
   dont de m'énerver quand ça arrive le matin alors que je n'ai pas encore bu
   mon café et que je m'installe devant ma machine, près a gravir des montagnes
   de code.
   
## Un raspberry pi c'est cool mais c'est lent
Personnellement, aller fouiller dans une étagère de DVD, ça me saoule, et en
plus ça prend de la place. Je préfère nettement un bon
vieux [Kodi](https://kodi.tv/) (anciennement nommé XBMC).

Donc, c'est quoi l'idée logique pour moi ? Acheter
un [raspberry pi](https://www.raspberrypi.org/) et y installer Kodi, ce que j'ai
fait. Malheureusement, certains formats vidéos sont mal supportés (pas de
décodage hardware pour certains) et l'interface graphique est vraiment lente.

Ensuite j'ai tenté avec
un [Intel NUC](http://ark.intel.com/products/78577/Intel-NUC-Kit-DE3815TYKHE),
je me suis dit: "Ça au moins c'est un vrai PC en miniature". Mais bon voilà,
croyez moi ou pas, le petit processeur Atom de la bête n'arrivais pas à décoder
le x264 au delà de 576p (c'était déjà tout juste a 576p en fait). En gros, même
soucis qu'avec le raspberry pi mais plus cher :astonished:. Par contre l'UI était
super fluide :smile:.

Et puis bon, ça nous fait encore des "box" supplémentaires dans notre
installation.

EDIT: Depuis, ils ont sorti le
[raspberry pi 3](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/),
il faut que je [teste ça](/post/raspberry-pi-3).



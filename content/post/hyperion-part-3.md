+++
categories = ["Administration", "Hyperion"]
date = "2016-01-22T13:53:21+02:00"
description = """
Mise en place de toute la tuyauterie réseau, un vrai déluge d'interface !
"""
tags = ["linux", "xen", "admin", "network", "bridge"]
title = "Hyperion, routeur tout-en-un: Round 2 - Le réseau"
toc = true
prev = "/post/hyperion-part-2/"
next = "/post/hyperion-part-4/"
+++

Haaaaa le réseau :'-) J'adore ça ! 

Au [précédant post][prev] j'avais configuré de quoi avoir un Xen qui marche mais
ça ne suffit pas car rien n'avait été fait pour que les VMs puissent avoir accès
au réseau. Il est temps de remédier à cela.

[prev]: /post/hyperion-part-2/

Tout d'abord, une petite description des contraintes: 

* Je veux que le routeur/firewall du réseau soit une VMs, pas question que ce
  soit Hyperion qui soit le routeur. Cela augmentera sensiblement la
  sécurité. Il ne s'occupera que de router et filtrer les paquets. Pour des
  raisons pratiques, j'y mettrai aussi le cache DNS et le serveur DHCP. Je
  pourrais faire des VMs séparées pour ces deux derniers mais bon, faut pas
  exagérer, c'est pas la NSA non plus.

<!--more-->

* La carte mère ne possédant pas de IOMMU, je ne peux pas faire de PCI
  passthrough avec Xen. Donc les cartes réseau physiques d'Hyperion devront être
  gérée partiellement par Hyperion. Ce n'est pas trop un soucis, j'utiliserai
  des [bridges][bridge] uniquement connectés entre le périphérique réseau est la
  VM routeur.
  
* Comme j'aime bien quand c'est compliqué :wink:, je vais faire plusieurs sous
  réseaux. Ça fera autant de bridges à gérer.

[bridge]: https://en.wikipedia.org/wiki/Bridging_(networking)

# Xen et le réseau
Pour connecter des VMs Xen on a plusieurs choix, on a le classique routage ou
le [NAT][] mais ces deux solutions sont certes simple a mettre en place mais ne
permettent pas tout ce que je souhaite. Par exemple, le DHCP ne va pas
fonctionner, et surtout hyperion devient obligatoirement le routeur, ce qui
n'est pas ce que je veux.

Ensuite il y a les linux [bridge][], très pratiques, simple, et directement
intégré à linux. Il faut les voir comme des [switch][] physiques auxquels on
viens brancher des câbles Ethernet virtuels. Ce sera notre solution.

Et enfin, pour les datacenter, on va avoir [Open vSwitch][ovs]. Là c'est du
lourd, il faut le voir comme un gros bridge distribué à travers le réseau. C'est
indispensable lorsque l'ont veux par exemple faire apparaître deux VMs tournant
dans deux serveur séparés comme appartenant au même sous-réseau, bon.. Peut-être
pas indispensable, mais vivement conseillé. C'est aussi très bien pour la live
migration de Xen (transfert d'une VM d'un serveur à un autre sans coupure). Open
vSwitch possède aussi diverses fonctionnalités pour monitorer le réseau dont
certaine sont spécifique à la virtualisation. 'fin bref, c'est la grosse bêbête
pour virtualiser son réseau. J'ai testé pour voir, ça marche très bien mais ça
m'a paru un peu lourd pour nos besoins. Je ferai peut-être un post dédié un jour
:wink:

[nat]: https://en.wikipedia.org/wiki/Network_address_translation
[switch]: https://en.wikipedia.org/wiki/Network_switch
[ovs]: https://en.wikipedia.org/wiki/Open_vSwitch

# Schéma (en ASCII !!)

Voilà un petit schéma de ce à quoi ça devrait ressembler:


```sh
                               -------------------
                          ----/                   \----
                        -/                             \-
                       (             Internet            )
                        -\                             /-
                          ----\                   /----
                               -------------------
             -------                    |                   -------            
          --/       \--                 |                --/       \--         
         /     LAN     \       +-----------------+      /    Wifi     \        
         |  physique   |       |    Box du FAI   |      |  physique   |        
         \             /       +-----------------+      \             /        
          --\       /--                 |                --\       /--         
             -------                    |                   -------            
 Hyperion       |                       |                      |        
    +-----------|-----------------------|----------------------|--------------+
    |       |  lan0  |             |  inet0  |             |  ap0  |          |
    |       \--------/             \---------/             \-------/          |
    |           |                       |                      |              |
    |/-----\ +------+              +---------+             +-------+          |
    ||veth0|-|brlan0|              | brinet0 |             | brap0 |          |
    |\-----/ +------+              +---------+             +-------+          |
    |   |       |                       |                      |              |
    |   |       |     +-----------------+                      |              |
    |-------\   |     |     +----------------------------------+              |
    |veth0-e|   |     |     |                                                 |
    |-------/   |     |     | +--------+ +--------+ +------------+            |
    |           |     |     | | brdmz0 | | brcmz0 | | brcluster0 |            |
    |           |     |     | +--------- +--------+ +------------+            |
    |dom0       |     |     |    |           |           |                dom0|
    |===========|=====|=====|====|===========|===========|====================|
    |domUs      |     |     |    |     +-----+  +--------+               domUs|
    |           |     |     |    |     |        |                             |
    | Tethys    |     |     |    |     |        |                             |
    |    +------|-----|-----|----|-----|--------|------+   +---+ +---+ +---+  |
    |    |   |lan0||inet0||ap0||dmz0||cmz0||cluster0|  |   |VM2| |VM3| |VM4|  |
    |    |   \----/\-----/\---/\----/\----/\--------/  |   +---+ +---+ +---+  |
    |    |                                             |   +---+ +---+ +---+  |
    |    |     Routeur, Firewall, DHCP, Cache DNS      |   |VM5| |VM6| |VMx|  |
    |    |                                             |   +---+ +---+ +---+  |
    |    +---------------------------------------------+   D'autres futures   |
    |                                                            VMs          |
    +-------------------------------------------------------------------------+
```

* **Moitié supérieure de la grande boîte**: Il s'agit du *dom0* de `hyperion`,
  avec ses 3 interfaces réseau physiques, `lan0`, `inet0` et `ap0` correspondant
  respectivement au réseau local, à la connexion vers l'Internet public via la
  "box" du FAI et à la carte wifi. On y voit aussi les différents [bridge][]
  nommés `brlan0`, `brinet0`, `brap0`. ces derniers servent de pont entre les
  interfaces physiques et la VM qui s'occupera du routage, j'ai nommé
  `tethys`. Il y a aussi les bridge `brdmz0`, `brcmz0` et `brcluster0`. Ces
  bridges sont là pour émuler les switchs des différents sous-réseaux virtuels
  (plus la dessus plus tard :wink:). Et enfin, il y a aussi `veth0` et `veth0-e`
  qu'il faut imaginer comme un cable réseau virtuel que je branche entre
  `brlan0` et le dom0 de `hyperion`, il permet tout simplement à `hyperion`
  d'avoir une connexion réseau (d'autre options sont possible ici, mais je
  trouve celle ci élégante et pratique).
  
* **Moitié inférieure de la grande boîte**: C'est la zone représentant les
  *domUs*, là on résideront les VMs. Pour le moment, il n'y a que `tethys` de
  prévu, ce sera notre routeur/firewall. Ce dernier possédera donc 6 interfaces
  réseau virtuelles nommées `lan0`, `inet0`, `ap0`, `dmz0`, `cmz0` et `cluster0`
  correspondant bien évidement aux bridge auxquels elles sont reliées. Les
  autres futures VMs viendront rejoindre `tethys` plus tard en prenant soin de
  les connecter au bridge voulu en fonction du sous réseau auquel je voudrai
  qu'elle appartiennent.

# Particularité pour la carte wifi
Les drivers linux de carte wifi qui se base sur le module `mac80211` permettent
de créer des cartes virtuelles additionnelles. Par exemple, cela permet
d'utiliser à la fois la carte en temps que point d'accès et à la fois en temps
que client ordinaire. Il y a aussi le mode `IBSS/ad-hoc` (connexion directe
entre deux machines) et le mode `mesh` qui est comme le mode `IBSS` mais avec la
possibilité de router les paquets de machine en machine dans le cas ou la cible
ne peux pas être atteinte directement. Il s'en sont servi au [FOSDEM][] pour
étendre le réseau wifi la première fois où j'y suis allé.

[fosdem]: https://fr.wikipedia.org/wiki/Free_and_open_source_software_developers%27_European_meeting

Dans notre cas, je vais juste créer un carte virtuelle pour le point d'accès
pour le moment. Mais j'espère bien m'amuser avec les mesh network quand
l'occasion se présentera (et vous aurez droit à un post en prime :wink:)

Je vais expliquer cette partie plus tard, pour l'instant, retenez que la carte
wifi physique s'appellera `wifi0` et la virtuelle, destinée au point d'accès
sera `ap0`. `wifi0` restera inutilisée, nous ne nous servirons que des cartes
virtuelles.

# Préparatifs
On va commencer par renommer les interfaces réseau car de base on est avec des
`eth0`, `eth1` et `wlan0`. Ça suffirait mais j'aime m'y retrouver dans mes
scripts et autres fichiers de configuration, surtout lorsqu'il y a autant de
"tuyauterie" réseau à gérer. On va tout simplement rajouter des règles `udev` en
se basant sur les adresses MAC des interfaces.

Dans `/etc/udev/rules.d/70-persistent-net.rules` (à créer si besoin) ajoutez ces
lignes:

```sh
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="Adresse_MAC_a_remplir", NAME="inet0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="Adresse_MAC_a_remplir", NAME="lan0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="Adresse_MAC_a_remplir", NAME="wifi0"
```

Vous pouvez trouver les adresses MAC en tapant `ip link`.

Ensuite, le plus simple c'est de redémarrer la machine.

Donc comme expliqué plus haut, ici je nomme les interface *physique*, pas
d'étonnement de ne pas voir `ap0` dans la liste car cette interface sera créée
ailleurs dans le processus de boot.

# Le déluge d'interfaces !
Pour les bridges, il nous faut `brctl`, un pti coup de `apt-get install
bridge-utils` et c'est bon.

Il est temps de configurer toute la partie `dom0` du réseau. Bon bin, le plus
simple c'est que je vous balance le fichier de conf bien commenté.

Le fichier `/etc/network/interfaces` (voir `man interfaces` pour la syntaxe)

```sh

# The loopback network interface
auto lo
iface lo inet loopback


############## Interfaces physiques ############
## Interface Ethernet de la carte mère. Vu que on n'utilise pas vraiment
## les interfaces (sauf veth0-e), j'utilise le mode _manual_ qui
## permet de définir les commandes qui allument et éteignent l'interface.
## Ça sera pareil pour les autres interfaces.
auto inet0
iface inet0 inet manual
	up ip link set dev $IFACE up
	down ip link set dev $IFACE down

## La carte Ethernet destinée au réseau local.
auto lan0
iface lan0 inet manual
	up ip link set dev $IFACE up
	down ip link set dev $IFACE down

## La carte wifi physique, inutilisée ici. Elle est juste ici pour être 
## exhaustif. Comme ça je l'oublie pas quand je viens changer des trucs ici.
#auto wifi0 
iface wifi0 inet manual

############# Interfaces virtuelles ###########

## La carte wifi virtuelle destinée au point d'accès.
## Voir `man iw` pour comprendre la commande. On remarque que je défini
## l'adresse MAC moi-même.
auto ap0
iface ap0 inet manual
	up iw dev wifi0 interface add $IFACE type __ap
	post-up ip link set dev $IFACE address 00:19:e0:83:6a:a0
	post-up ip link set dev $IFACE up
	pre-down ip link set dev $IFACE down
	down iw dev $IFACE del

## Ici on crée une interface Ethernet virtuelle. Il faut la voir comme
## un câble Ethernel virtuel avec deux extrémités, l'une s'appelant
## `veth0` et l'autre `veth0-e`, "e" comme extremity mais n'importe quel
## nom conviendrait.
auto veth0
iface veth0 inet manual
	up ip link add name $IFACE type veth peer name $IFACE-e
	post-up ip link set dev $IFACE up
	pre-down ip link set dev $IFACE down
	down ip link delete $IFACE

############## Les bridges ##############

## Le bridge correspondant à l'accès Internet. `man brctl` ici ;)
## J'ajoute `inet0` avec `brctl addif ...`
auto brinet0
iface brinet0 inet manual
	up brctl addbr $IFACE
	post-up brctl stp $IFACE on
	post-up brctl addif $IFACE inet0
	post-up ip link set dev $IFACE up
	pre-down ip link set dev $IFACE down
	pre-down brctl delif $IFACE inet0
	down brctl delbr $IFACE

## Le bridge du réseau local.
## J'ajoute `lan0` ainsi que `veth0` créé plus haut. L'autre extrémité,
## `veth0-e`, sera l'unique interface réseau routable du dom0 d'hyperion.
auto brlan0
iface brlan0 inet manual
	up brctl addbr $IFACE
	post-up brctl stp $IFACE on
	post-up brctl addif $IFACE lan0
	post-up brctl addif $IFACE veth0
	post-up ip link set dev $IFACE up
	pre-down ip link set dev $IFACE down
	pre-down brctl delif $IFACE lan0
	pre-down brctl delif $IFACE veth0
	down brctl delbr $IFACE

## Le bridge pour la DMZ, pas d'interface pour le moment.
auto brdmz0
iface brdmz0 inet manual
	up brctl addbr $IFACE
	post-up brctl stp $IFACE on
	post-up ip link set dev $IFACE up
	pre-down ip link set dev $IFACE down
	down brctl delbr $IFACE

## Le bridge pour la CMZ, pas d'interface non plus.
auto brcmz0
iface brcmz0 inet manual
	up brctl addbr $IFACE
	post-up brctl stp $IFACE on
	post-up ip link set dev $IFACE up
	pre-down ip link set dev $IFACE down
	down brctl delbr $IFACE

## Le bridge du sous-réseau destiné aux tests de cluster ;)
auto brcluster0
iface brcluster0 inet manual
	up brctl addbr $IFACE
	post-up brctl stp $IFACE on
	post-up ip link set dev $IFACE up
	pre-down ip link set dev $IFACE down
	down brctl delbr $IFACE

## Le bridge du réseau wifi
## Je n'ajoute pas ap0 moi-même car `hostapd` s'en occupera lui-même (plus de 
## détails là dessus plus tard)
auto brap0
iface brap0 inet manual
	up brctl addbr $IFACE
	post-up brctl stp $IFACE on
	post-up ip link set dev $IFACE up
	pre-down ip link set dev $IFACE down
	down brctl delbr $IFACE

############## Interface routable ############
## Le seul accès réseau réel pour le dom0 d'hyperion.
## C'est l'autre extrémité de `veth0`.
## Configuré en static dans le sous-réseau de `lan0` et `brlan0`.
auto veth0-e
iface veth0-e inet static
	address 10.0.0.2
	netmask 255.255.0.0
	gateway 10.0.0.1

```

Voilà, un petit reboot et toutes ces interfaces devraient apparaître.

# DMZ, CMZ, cluster0 ? c'est pourquoi faire ?
Une [DMZ][] est un sous réseau contenant les services accessibles depuis
l'extérieur comme les serveurs de mail ou les serveurs web public. L'idée est
d'avoir une zone où la confiance envers les clients qui s'y connectent est toute
relative et de paramétrer le firewall en conséquence.

Une CMZ est censée contenir les données sensible d'une organisation qui n'aurait
pas leur place dans le réseau local normal. A vrai dire, il est clair que nous
n'en avons pas besoin chez nous, mais comme je disais, faire mumuse avec les
réseau, j'adore ça :-D

Et cluster0 sera un autre sous réseau destiné à tester [Hadoop][].

Note: En réalité, le sous réseau a été intégré bien plus tard après la création
de Hyperion mais je l'ai mis ici pour ajouter un peu de piments.

[hadoop]: https://en.wikipedia.org/wiki/Apache_Hadoop
[dmz]: https://en.wikipedia.org/wiki/DMZ_(computing)

# Point d'accès wifi
Nous avons les interfaces mais le point d'accès wifi est actuellement non
fonctionnel car il nous faut un daemon pour gérer les authentifications
WPA2. Très franchement, j'aurais aimé pouvoir placer ce daemon dans une VM mais
malheureusement, sans IOMMU, je ne peux pas déléguer la carte wifi à une VM et
ce service devra tourner sur hyperion. On va faire ça avec `hostapd` (`apt-get
install hostapd`)

Ensuite la config dans `/etc/hostapd/hostapd.conf`:

```sh
ssid=ChezNous
wpa_passphrase=ShutCaySecret
interface=ap0
bridge=brap0
channel=1
driver=nl80211
hw_mode=g
logger_stdout=-1
logger_stdout_level=2

# bitfield of allowed auth algorithm (3 = 11b = both algo)
auth_algs=3

# max num of client station
max_num_sta=1024

### configure to use only WPA2
# cypher alg 
rsn_pairwise=CCMP
# only WPA2 (1 = WPA, 2 = WPA2, 3 = both)
wpa=2
# key managment alg
wpa_key_mgmt=WPA-PSK
# again some cypher settings
wpa_pairwise=TKIP CCMP
```

Suivi d'un `service hostapd restart` et on est bon ;-)

# Un dernier réglage Xen
Maintenant que nous avons nos bridges, un petit ajustement dans la configuration
de Xen s'impose.

Dans `/etc/xen/xl.conf` modifiez ces paramètres:

```sh
# Utilisation du script prédéfini pour les bridges
vif.default.script="vif-bridge"

# Bridge utilisé par défaut
vif.default.bridge="lan0"

```

Voilà pour le réseau côté `dom0`, au [prochain post][next] nous créerons enfin
cette VM destinée au routage.

[next]: /post/hyperion-part-4/

# Sources
* <http://www.tldp.org/HOWTO/Adv-Routing-HOWTO/index.html>
* <https://wiki.xen.org/wiki/Xen_PCI_Passthrough>
* <https://wiki.xen.org/wiki/Xen_Networking>
* <https://wireless.wiki.kernel.org/en/users/documentation/iw/vif>
* <http://ask.xmodulo.com/change-network-interface-names-permanently-linux.html>
* <https://wiki.archlinux.org/index.php/Software_access_point>

Et bien sûr les pages de man et les manuels des différents programmes.

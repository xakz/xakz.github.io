+++
categories = ["Administration", "Hyperion"]
date = "2016-01-18T18:23:54+02:00"
description = """
Montage de la bête, installation 
du système et mise en place de la virtualisation"""
tags = ["linux", "xen", "admin", "hardware", "network"]
title = "Hyperion, routeur tout-en-un: Round 1 - Xen"
toc = true
prev = "/post/hyperion-part-1/"
next = "/post/hyperion-part-3/"
+++

Je rappelle donc les objectifs définis lors du [précédant post][prev]:
construire un routeur/firewall/serveur de dev/double media center à moindre
coûts et avec le maximum de sécurité. Pour ce faire, j'ai prévu de faire le plus
de récup possible dans mes 3 étagères bourrées de pièces d'ordi.

[prev]: /post/hyperion-part-1/

# Mes trouvailles

 * Une [MSI B75MA-E33][b75ma] avec un [Celeron G1610][g1610].  Avec ça j'aurais
   1 port SATA 6Gbps, 3 ports SATA 3Gbps (ça suffira amplement vu que l'entonnoir
   ici sera l'ethernet), USB3, Ethernet 1Gbps, Intel Graphic HD inclu dans le
   processeur et un port HDMI (sur les deux nécessaires).
   
 * Une barrette DDR3 de 4GB. Ça sera déjà un bon début (la virtualisation, ça a
   besoin de RAM :wink:), on verra pour d'éventuels ajouts plus tard.

 * Une [NVIDIA Geforce GT620][gt620] qui va me permettre d'obtenir mon deuxième
   port HDMI.
   
 * Une carte Ethernet 1Gbps [TpLink TG-3468][tg3468]. Bé oui, va bien falloir
   que les paquets réseaux ressortent quelques part.
   
 * Une vieille carte wifi PCI (Qualcomm Atheros AR2413/AR2414 Wireless Network
   Adapter). Ça nous fera l'Access Point Wifi. Bon c'est du 802.11bg, c'est un
   peu faible, mais c'est gratuit et il y avait ce port PCI à utiliser sur la
   carte mère. Ça nous suffira, pour nous le wifi c'est uniquement de la
   navigation internet, on verra plus tard pour évoluer.

 * Quatre disques durs SATA de 3TB, 1TB, 500GB et 320GB.

 * Et bien sûr un boîtier qui va bien avec une alimentation 400W.
 

[b75ma]: https://www.msi.com/Motherboard/B75MA-E33.html
[g1610]: http://ark.intel.com/products/71072/Intel-Celeron-Processor-G1610-2M-Cache-2_60-GHz
[gt620]: http://www.geforce.com/hardware/desktop-gpus/geforce-gt-620
[tg3468]: http://www.tp-link.com/baltic/products/details/cat-11_TG-3468.html

# Photos
Alors je regrette de ne pas avoir fait de photo pendant le montage, je vous
aurais fait un petit roman photo xD

Je n'ai donc que des photos prises à la va vite alors que la machine est
complètement finie.

<div class="group">
<figure class="cap-top" style="width:49%">
 <img src="/img/hyperion.inside.jpg" alt="Intérieur d'Hyperion">
 <figcaption>
  Hyperion, monté et en fonctionnement. Faites pas attention à la poussière ;)
 </figcaption>
</figure>
<figure class="cap-top" style="width:49%">
 <img src="/img/hyperion.fan.jpg" alt="Ventillo pour les disques">
 <figcaption>
  J'ai complètement enlevé le cache de l'avant et ajouté un ventillo pour les disques.
 </figcaption>
</figure>
<figure class="cap-top" style="width:49%">
 <img src="/img/hyperion.button.jpg" alt="Bricolage du bouton">
  <figcaption>
  J'ai bricolé un bouton power accessible depuis l'arrière. Voyants compris !
  Faites pas attention à la finition xD
 </figcaption>
</figure>
<figure class="cap-top" style="width:49%">
 <img src="/img/hyperion.button.inside.jpg" alt="Bricolage du bouton (intérieur)">
  <figcaption>
   L'envers du décors.
 </figcaption>
</figure>
<figure class="cap-top" style="width:49%">
 <img src="/img/hyperion.back.jpg" alt="Arrière avec la connectique">
  <figcaption>
   L'arrière, avec toute la connectique de branchée.
 </figcaption>
</figure>
</div>

Bon rien de vraiment fantastique, en même temps, j'ai rien eu à acheter, c'est
tout de la récup. Ceci dit, maintenant que je sais que ça marche bien, ça va
devenir le pilier du réseau et la prochaine version sera plein plus étudiée à
tous les niveaux (si si, y compris l'esthétisme :wink:).

# Installation du système de base
Évidement, mon choix pour la distribution va automatiquement
à [Debian][debian]. C'est stable, connu et ce fût longtemps ma distribution pour
mes machines desktop. À vrai dire, maintenant, je préfère [Arch Linux][] pour le
desktop, mais je continue d'utiliser Debian pour mes serveurs.

[debian]: http://www.debian.org
[arch linux]: http://www.archlinux.org

Je vous passe l'installation du système de base, on trouve des [tutorials][debinst] partout
sur le net pour ça. Je vais juste faire quelques mots sur les choix de
partitionnement:

[debinst]: https://www.debian.org/releases/stable/i386/index.html.fr


* Le *3TB* possède déjà son partitionnement: 1 seule partition ext4 avec des
  données à conserver dedans. J'y ai pas touché durant l'installation.
  
* Le *1TB* est partitionné pour accueillir le système: 

| taille                  |            usage                         |
|-------------------------|------------------------------------------|
| 256MB                   | Partition de boot EFI                    |
| 256MB                   | /boot                                    |
| 15GB                    | pour le système (/)                      |
| 8GB                     | un bon gros swap                         |
| le reste (~900GB)       | Un gros espace de stockage supplémentaire|

* Le *500GB* sera utilisé pour les VMs, avec [LVM][]

* Le *320GB*, hum, rien de prévu pour le moment, peut-être des backups

[lvm]: https://en.wikipedia.org/wiki/Logical_volume_management

Comme vous voyez, on reste extrêmement simpliste dans le partitionnement. Au
moment de l'installation, je n'étais pas sûr que tout ce que je voulais faire
fonctionnerait. Je modifierai au besoin plus tard, il reste plein de place
partout de toute façon. :smile:

Et non, je n'ai pas mis de RAID, j'en avais envie mais je ne voulais pas perdre
d'espace, et certains disques sont de vieux machins plutôt lents. Un jour je
referai ça avec de gros disques neufs, le RAID6, btrfs, etc... Puis bon, c'est
pas une machine destinée à faire de la haute disponibilité. Je rappelle que les
RAID ce n'est pas du tout une backup, et si mon système de backup marche comme
prévu, en cas de panne, ce sera rapidement remis en ligne.

# Installation de Xen
Bon, on a un système de base correct, passons à [Xen][].

[xen]: https://en.wikipedia.org/wiki/Xen

Petit topo sur Xen: Il s'agit d'un hyperviseur de virtualisation qui tourne sous
la forme d'un micro kernel léger (moins de 1M de RAM). L'avantage par apport à
d'autre solution comme [VMware][], [KVM][] ([qemu][]) ou [VirtualBox][], c'est
que Xen permet de fonctionner en mode paravirtualisé (Nommé **PV** sous Xen),
c-à-d qu'il n'a pas besoin des instructions de virtualisation incluses dans les
processeurs récents ce qui permet une plus grande vitesse d'exécution.

[vmware]: https://en.wikipedia.org/wiki/VMware
[kvm]: https://en.wikipedia.org/wiki/Kernel-based_Virtual_Machine
[qemu]: https://en.wikipedia.org/wiki/QEMU
[virtualbox]: https://en.wikipedia.org/wiki/VirtualBox

Il effectue cela en utilisant les [protection rings][rings] des processeurs x86:
Le microkernel Xen tourne en Ring 0 (le plus haut niveau), le kernel de l'OS
(linux) tourne en Ring 1, et enfin les processus de l'espace utilisateur des
différentes VMs tournent en Ring 2. Ceci nécessite que le kernel des machines
invitées soit modifié pour le gérer (aucun soucis pour le kernel linux, c'est
déjà inclus).

[rings]: https://en.wikipedia.org/wiki/Protection_ring

Xen supporte aussi le mode virtualisé complet (nommé **HVM** dans Xen), utile
pour les OS ne supportant pas le mode PV (comme Windows).

Il possède aussi un mode hybride, mixant HVM pour le kernel invité, et PV pour
les périphériques (via l'installation de driver, sous Windows notamment). Cela
permet un gain en vitesse bien évidement.

Autre chose, les machine virtuelles sous Xen sont nommées **virtual domain**, il
y en a deux types: le dom0 et les domU. 

* Le dom0 c'est la machine qui gère Xen et qui a un accès physique aux
  périphériques, On vient de l'installer ;)
* Les domU sont les machines invitées qui ont accès à des périphériques
  virtualisés, on verra comment en ajouter plus tard :wink:

Xen permet aussi de [PCI passthrough][passthrough] qui permet de "donner" un
périphérique PCI à un domU, c'est plutôt génial pour ce que j'ai envie de
faire. Malheureusement, ma carte mère actuelle ne le permet pas (pas
de [IOMMU][]). Pas grave, on fera tourner Kodi directement sur le dom0, c'est
pas super pour la sécurité, mais je n'est pas le choix. La prochaine carte mère
sera meilleure ;)

[passthrough]: https://wiki.xen.org/wiki/Xen_PCI_Passthrough
[iommu]: https://en.wikipedia.org/wiki/Input%E2%80%93output_memory_management_unit

Allons-y:

```sh
apt-get install xen-system-amd64 xen-tools 
```

Ensuite il faut redéfinir l'ordre de boot pour GRUB, par défaut il continue de
booter sur le système normal. Il suffit de renommer un fichier pour cela, mais
on va utilisé `dpkg-divert` pour que les mises à jour système de changent pas
nos réglages: 

```sh
dpkg-divert --divert /etc/grub.d/08_linux_xen --rename /etc/grub.d/20_linux_xen
```

On va ensuite réduire la mémoire utilisable par le dom0. Par défaut, le dom0 a
droit à toute la mémoire, et Xen ajuste cela en cas de besoin pour les domU en
utilisant une technique appelée le [memory ballooning][ballooning].

[ballooning]: https://www.quora.com/Virtualization-What-is-memory-ballooning

Techniquement, il "vole" de la mémoire inutilisé d'un ou plusieurs dom pour la
passer à un autre. C'est très efficace pour économiser sur les barrettes de RAM,
car sur tout un datacenter de virtualisation c'est quasi impossible que toutes
les VMs utilisent toute la mémoire qui leur a été attribuée. Par contre, dans le
cas où il y a vraiment un gros besoin en RAM sur toutes les VMs, ... Bin ça va
poser problème...

Personnellement, J'ai choisi de plutôt créer des VMs avec juste ce qu'il faut de
RAM sans ballooning et elles utiliserons leur SWAP si besoin. Les VMs seront
surtout des services réseaux, ayant une utilisation mémoire assez stable, en
général 128M ou 256M suffira. C'est parfait pour mes besoins.

Donc, réduisons la RAM pour le dom0, dans le fichier `/etc/default/grub` ajoutez
cette ligne:

```sh
GRUB_CMDLINE_XEN_DEFAULT="dom0_mem=1536M"
```

Alors oui, 1.5G c'est beaucoup trop pour un simple dom0, 128M aurait
probablement suffit mais j'ai prévu un usage annexe pour le dom0, faire tourner
deux Kodi en multiseat.

Il n'y a plus qu'a faire:

```sh
update-grub
reboot
```

Voilà, si tout s'est bien passé, la machine tourne sous Xen, dans son dom0. Vous
pouvez faire `free` et vérifier que la mémoire disponible est bien de 1.5G.

Dans les outils de monitoring Xen, on trouve `xentop`, c'est comme `top` mais
pour les VMs.

# LVM
On a pas parlé du lieu où serait stocké les images disque des VMs. Pour ça il
existe [plusieurs solutions][storage] avec Xen. On peut utiliser des fichiers
basiques comme on le ferait avec VirtualBox (.raw, .qcow2 ou .vhd supporté), des
stockages distants comme [NFS][] et [iSCSI][], ou [LVM][], c'est ce dernier que
nous utiliserons. Les stockages distants vont être particulièrement utiles en
cas de datacenter de virtualisation. Ils permettent
la [live migration][migration] des VMs de serveur en serveur.

[storage]: https://wiki.xen.org/wiki/Storage_options
[nfs]: https://en.wikipedia.org/wiki/Network_File_System
[iscsi]: https://en.wikipedia.org/wiki/ISCSI
[lvm]: https://en.wikipedia.org/wiki/Logical_volume_management
[migration]: https://wiki.xenproject.org/wiki/Migration

Petite explication sur la terminologie LVM:

PV
: Physical Volume, Il s'agit tout simplement d'une partition avec le type `0x8E`
et une entête spécifique à LVM pour que le système le reconnaisse.

VG
: Volume Group, Il s'agit d'un groupe de `PVs` utilisable pour créer des
`LV`. Comme on peut le deviner, un `VG` peut s'étendre sur plusieurs disques, un
peu comme le fait le `RAID 0`.

LV
: Logical Volume, c'est une partition utilisable par `mkfs`, comme le serait
`/dev/sda1`. Elle utilise tout ou une fraction du `VG` auquel elle appartient.

## Installation
Rien de plus simple:

```sh
apt-get install lvm2
```

## Partitionnement
J'ai choisi de créer un `VG` utilisant un unique `PV` situé sur une partition
qui prendra tout le disque de 500G.

Personnellement, j'aime utiliser `cfdisk` ou parfois `fdisk`, à vous de voir
lequel vous préférez. Pensez bien à mettre le type `8E`, ce n'est pas
indispensable car LVM scan les partitions au boot peu importe leur type mais un
peu de "good practice", ça fait pas de mal.

## Création du VG
Franchement, les commandes LVM sont très agréables à utiliser, simple et propre
avec des pages de man claires. C'est pas toujours comme ça malheureusement.

Alors, c'est super simple:

```sh
vgcreate vg0 /dev/sdc1
```

Et c'est tout xD

`vgcreate` va de lui même appeler `pvcreate` pour initialiser la partition et en
faire un `PV`, et ensuite l'ajouter au nouveau `VG` nommé `vg0`.

On peut regarder l'état des `PVs`, `VGs` et `LVs` avec `pvs`, `vgs` et `lvs`:

```sh
14:39 root@hyperion /etc/xen # pvs        
  PV         VG   Fmt  Attr PSize   PFree  
  /dev/sdc1  vg0  lvm2 a--  465.76g 445.51g
14:39 root@hyperion /etc/xen # vgs
  VG   #PV #LV #SN Attr   VSize   VFree  
  vg0    1   6   0 wz--n- 465.76g 445.51g
14:39 root@hyperion /etc/xen # lvs
  LV          VG   Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  hadoop-disk vg0  -wi-ao----  10.00g                                                    
  hadoop-swap vg0  -wi-ao----   4.00g                                                    
  io-disk     vg0  -wi-a-----   4.00g                                                    
  io-swap     vg0  -wi-a----- 128.00m                                                    
  tethys-disk vg0  -wi-ao----   2.00g                                                    
  tethys-swap vg0  -wi-ao---- 128.00m
```

Vous pouvez voir que j'ai déjà quelques `LVs`. Dans tout les cas, je vous
suggère d'aller lire d'avantage sur LVM, par exemple [ici][lvmdoc]. Je ferai
peut-être un post complet dessus un jour ;-)

[lvmdoc]: https://wiki.archlinux.org/index.php/LVM

# La suite
Au [prochain post][next], on s'occupera du réseau. Il va falloir tout un post
pour ça vu la complexité. Je vous rassure, de base, avec Xen c'est très simple,
un [bridge][] et c'est bon. Mais je veux que le routeur/firewall soit virtualisé
et il faut s'occuper du point d'accès wifi aussi, donc un post complet ce sera
pas de trop.


[next]: /post/hyperion-part-3/
[bridge]: https://en.wikipedia.org/wiki/Bridging_(networking)

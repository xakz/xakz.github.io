+++
categories = ["Big Data"]
date = "2017-04-23T11:31:51+02:00"
description = "Vous voulez vous essayer au Big Data ? C'est par ici !"
tags = ["hadoop", "bigdata", "admin", "linux", "debian"]
title = "Installer un pseudo-cluster Hadoop"
toc = true
next = "/post/install-hbase/"
+++

Alors bien sûr, il y a les [VMs Cloudera][cloudera] mais elles nécessitent pas
mal de RAM et, avec leur propre *Cloudera Manager*, nous éloignent des outils
basiques de chez Apache. Même si ils font apparemment du bon boulot, après tout,
leur but, c'est de faire un peu de pub et de vendre du support.

On va plutôt partir ici sur une Debian 8 comme base et détailler les étapes pour
avoir son petit pseudo-cluster [Hadoop][] de dev.

[cloudera]: https://www.cloudera.com/downloads/quickstart_vms.html
[hadoop]: https://hadoop.apache.org/

<!--more-->

# Hardware et partitionnement
On a à la maison la machine idéale pour ce genre de chose: [Hyperion][].

Donc c'est parti pour se faire une VM Xen: *2 vcpus*, *3GB* de RAM (plus ce
serait mieux mais la machine hôte est un peu limitée), *4GB* de swap, *10GB* de
partition root (à changer selon vos besoin). Je passe les détails de
l'installation et de la configuration de base. A la fin on se retrouve juste
tout simplement avec une Debian 8 fraîchement installée et prête a servir.

[hyperion]: /categories/hyperion

# Étape 0: OpenJDK 8 et Apache BigTop
Certains paquets ont été compilés pour Java 8, il va donc nous falloir un Java 8
qui ne se trouve pas dans Debian 8, la solution: les backports !

```sh
echo 'deb http://http.debian.net/debian jessie-backports main contrib non-free' > /etc/apt/sources.list.d/jessie-backports.list
apt-get update
apt-get install openjdk-8-jdk
```

[Apache BigTop][bigtop] est un ensemble d'outils, de script de build, de paquets
pour votre distribution préférée, des recettes [Vagrant][] et aussi d'image
Docker (en beta pour le moment). Nous ce qui nous intéresse ici ce sont les
paquets Debian pré-build comme on aime :wink:

Le classique ajout de source Apt:
``` sh
wget -O- http://archive.apache.org/dist/bigtop/stable/repos/GPG-KEY-bigtop | sudo apt-key add -
wget -O /etc/apt/sources.list.d/bigtop.list http://archive.apache.org/dist/bigtop/stable/repos/debian8/bigtop.list
apt-get update
```
Et voilà, on est prêt à lancer les installations :smile:

Personnellement, je n'ajoute pas la clef GPG à apt-get, simple préférence,
j'aime pouvoir contrôler lorsqu'un paquet extérieur à Debian va s'installer.

[vagrant]: https://fr.wikipedia.org/wiki/Vagrant
[bigtop]: https://bigtop.apache.org/

# Hadoop, HDFS et YARN
Tout le stack [Hadoop][] se base sur [HDFS][] qui est un système de fichiers
distribué développé en Java. Il se compose d'un `namenode` qui s'occupe des
metadonnées, d'un `datanode` par machine qui s'occupe du stockage des données
elles-mêmes et du `secondarynamenode` qui assiste le `namenode`.

Et YARN est le gestionnaire de ressource pour le cluster, il ordonnance les
tâches sur les différentes machines du cluster. C'est une évolution de l'API
MapReduce d'origine. Il se compose d'un `resourcemanager` qui ordonnance les
tâches et d'un `nodemanager` par machine qui lance les tâches sur la machine et
remonte l'état de celle ci au `resourcemanager`.

Les pages wikipedia vous en diront bien plus, on va
juste se concentrer sur l'installation et la configuration de la bête.

[hadoop]: https://en.wikipedia.org/wiki/Apache_Hadoop
[hdfs]: https://en.wikipedia.org/wiki/Apache_Hadoop#HDFS

# Installation
``` sh
apt-get update
apt-get install hadoop-hdfs-datanode hadoop-hdfs-namenode hadoop-hdfs-secondarynamenode hadoop-mapreduce-historyserver hadoop-yarn-nodemanager hadoop-yarn-resourcemanager 
```

# Configuration
Les différents fichier de conf se trouve dans `/etc/hadoop/conf`

## core-site.xml
{{< highlight xml >}}
<configuration>
    <property>
        <!-- Indique a Hadoop d'utiliser le hdfs sur localhost -->
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
{{< /highlight >}}

## hdfs-site.xml
{{< highlight xml >}}
<configuration>
  	<property>
        <!-- Une seule réplication de donné (3 par défaut) -->
        <name>dfs.replication</name>
        <value>1</value>
	<property>
        <!-- Dossier où le serveur "namenode" stockera ses fichiers -->
		<name>dfs.namenode.name.dir</name>
		<value>/var/lib/hadoop-hdfs/namenode</value>
	</property>
	<property>
        <!-- Dossier où le serveur "datanode" stockera ses fichiers -->
		<name>dfs.datanode.data.dir</name>
		<value>/var/lib/hadoop-hdfs/datanode</value>
	</property>
</configuration>
{{< /highlight >}}

## mapred-site.xml
{{< highlight xml >}}
<configuration>
    <property>
        <!-- Défini quel framework on va utiliser pour nos MapReduce -->
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <!-- 
            Les paquets debian ont de petit soucis, il a fallu rajouter
            ces répertoires au classpath java pour qu'il s'y retrouve
        -->
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/*,$HADOOP_MAPRED_HOME/lib/*</value>
    </property>
</configuration>
{{< /highlight >}}

## yarn-site.xml
{{< highlight xml >}}
<configuration>
    <property>
        <!-- Nécessaire pour ordonnancer les tâches -->
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <!-- 
            Les paquets debian ont de petit soucis, il a fallu rajouter
            ces répertoires au classpath java pour qu'il s'y retrouve
        -->
        <name>yarn.application.classpath</name>
        <value>$HADOOP_CONF_DIR,$HADOOP_COMMON_HOME/*,$HADOOP_COMMON_HOME/lib/*,$HADOOP_HDFS_HOME/*,$HADOOP_HDFS_HOME/lib/*,$HADOOP_MAPRED_HOME/*,$HADOOP_MAPRED_HOME/lib/*,$HADOOP_YARN_HOME/*,$HADOOP_YARN_HOME/lib/*,$USS_HOME/*,$USS_CONF</value>
    </property>
</configuration>
{{< /highlight >}}

# Initialisation du pseudo-cluster HDFS
Pour fonctionner, HDFS nécessite d'être formaté et un ensemble de dossiers de
base doit être créé.

Formatage:

``` sh
/etc/init.d/hadoop-hdfs-namenode init
```

Ensuite il faut passer sur l'utilisateur *hdfs* pour initialiser tout ça, c'est
comme le *root* de HDFS. Un petit coup de `su - hdfs` pour changer
d'utilisateur. Ensuite il faut exécuter cette série de commandes:

``` sh
# Dossier temporaire utilisable par tous
hdfs dfs fs -mkdir /tmp
hdfs dfs fs -chmod -R 1777 /tmp

# les logs de YARN
hdfs dfs fs -mkdir -p /var/log/hadoop-yarn
hdfs dfs fs -chown yarn:mapred /var/log/hadoop-yarn

# Historique des MapReduce lorsque l'on utilise pas YARN (optionnel)
hdfs dfs fs -mkdir -p /user/history
hdfs dfs fs -chown mapred:mapred /user/history
hdfs dfs fs -chmod 775 /user/history

# Dossiers de travail commun pour les jobs YARN
hdfs dfs fs -mkdir -p /tmp/hadoop-yarn/staging
hdfs dfs fs -chmod -R 1777 /tmp/hadoop-yarn/staging
hdfs dfs fs -mkdir -p /tmp/hadoop-yarn/staging/history/done_intermediate
hdfs dfs fs -chmod -R 1777 /tmp/hadoop-yarn/staging/history/done_intermediate
hdfs dfs fs -chown -R mapred:mapred /tmp/hadoop-yarn/staging

# Et enfin un dossier pour l'utilisateur.
# Remplacez 'xakz' par votre nom d'utilisateur
hdfs dfs fs -mkdir -p /user/xakz
hdfs dfs fs -chown xakz:xakz /user/xakz
hdfs dfs fs -chmod 775 /user/xakz
```

Il n'y a plus qu'à tout redémarrer:

``` sh
for i in hadoop-hdfs-datanode hadoop-hdfs-namenode hadoop-hdfs-secondarynamenode hadoop-mapreduce-historyserver hadoop-yarn-nodemanager hadoop-yarn-resourcemanager; do
    service restart $i
done
```

# Tests
Il est temps de tester un peu cette installation.

Connectez vous sur votre pseudo-cluter et lancer un des exemples fournis:

```sh
ssh xakz@ip-de-votre-machine
hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 10 1000
```

Vous devriez voir une approximation du nombre pi sur la dernière ligne de la
sortie.

Vous pouvez aussi consulter l'état des jobs sur http://localhost:8088/
(remplacez localhost par l'IP des votre machine/VM)

Un autre exemple, utilisant HDFS cette fois: un grep.
Commençons par preparer l'input:

```sh
hdfs dfs -mkdir input
hdfs dfs -put /etc/services input/
hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar grep input output '.*[^0-9]5[0-9]{3}/tcp.*'
hdfs dfs -cat 'output/*'
```

Vous obtiendrez la liste des ports TCP connus dans /etc/services compris entre
5000 et 5999 :wink:


# Interfaces web utiles
* YARN -> http://localhost:8088/
* HDFS namenode -> http://localhost:50070/
* HDFS datanode -> http://localhost:50075/
* HDFS secondarynamenode -> http://localhost:50090/
* MapReduce historyserver -> http://localhost:19888/

# Encore !
Il y a encore bien d'autres outils consacrés au Big Data chez Apache. Nous nous
concentrerons sur l'installation de [HBase][] dans un [prochain post][next]

J'espère avoir pu en aider certain(e)s. Ce post fût plutôt consacré à
l'installation. Un jour prochain, peut-être, je me lancerai dans un document
bien plus vaste destiné à exposer les details de l'architecture d'un cluster
Hadoop.

[hbase]: https://en.wikipedia.org/wiki/Apache_HBase
[next]: /post/install-hbase/

# Sources
* http://hadoop.apache.org/
* https://bigtop.apache.org/index.html
* https://cwiki.apache.org/confluence/display/BIGTOP/How+to+install+Hadoop+distribution+from+Bigtop+0.5.0
* https://developer.yahoo.com/hadoop/tutorial/

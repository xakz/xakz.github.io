+++
title = "Hugo Délire !"
description = """
Ou comment se faciliter la vie pour la publication de son site
sur github.io avec Hugo (en la rendant d'abord plus compliquée)
"""
date = "2017-04-30T18:54:04+02:00"
categories = ["Coding"]
tags = ["hugo", "makefile", "git", "github-pages"]
toc = true
+++
<!--more-->
Alors, pour les nostalgiques !

{{< youtube VvqwCme7fKM >}}

En revoyant ça, je me suis dit "OMG yavait déjà de la 3D !". En même temps,
c'était aussi l'époque de la Playstation 1...

Bon, c'est pas pour ça qu'on est là ! On est des gens sérieux nous !

# github.io
Pour ceux qui connaissent pas, github offre gratuitement un service permettant
de publier des sites statique, appelé [Github Pages][ghp], pour un site
personnel ou un site lié à un projet hébergé sur github. Je connais pas
l'historique exacte mais le service existe depuis 2008. Date à
laquelle [Jekyll][] a lui aussi vu le jour chez Github donc je suppose que
depuis le début les Github Pages sont liées a Jekyll. Oui car on peut se
contenter de push ses sources Jekyll sur son repository et github.io va
automatiquement générer le site pour nous. Mais c'est pas ce qu'on va
faire... Ce serait trop simple.

[ghp]: https://en.wikipedia.org/wiki/GitHub_Pages
[jekyll]: https://en.wikipedia.org/wiki/Jekyll_(software)

# Hugo
Non, ce qu'on va faire c'est utiliser les Github Pages mais avec un autre
générateur de site statique: [Hugo][]. Il fait la même chose que Jekyll, un peu
différemment bien sûr, mais en gros on est un peu sur le même principe: Ecrire
ses post de blog en [markdown][] avec une entête spéciale nommée "Front Matter"
pour y mettre les métadonnées (titre, date, tags, etc..) et Hugo (ou Jekyll, ou
un autre) s'occupe de générer tout le site. Je résume très grossièrement ici,
mais ce n'est pas le sujet du post. Promis j'en ferai un pour expliquer le
fonctionnement de Hugo :wink:

[hugo]: https://gohugo.io/
[markdown]: http://daringfireball.net/projects/markdown/

Alors pourquoi Hugo et pas un autre ? Bin, pas toujours facile de répondre a ça,
pourquoi il y en a qui préfère le reglisse aux fraise tagada, et d'autres qui
préfèrent le chocolat au caramel... Mais je sais que j'ai quand même quelques
raisons d'ordre pragmatiques:

* Il est écrit en [Go][] et j'aime la mascotte du Go ! (j'aime le langage aussi :wink:)
* Il est plus rapide, **vraiment** plus rapide (40ms pour ce blog entier). Go est
  un langage compilé, ça aide beaucoup je pense.
* Je connais déjà le langage de template du Go, c'est plus facile pour moi de
  customizer mon thème.
* Sûrement d'autre trucs, mais on verra ça pour le post consacré a Hugo. Faut
  pas hésiter à arrêter pappy Xakz quand il se perd dans ses histoires hors
  sujet de la guerre 14-18.

[go]: https://golang.org/

# Cette fois on commence pour de vrai
Alors, comment on se sert des Github Pages ? Je passe dessus rapidement vu qu'il
y a largement ce qu'il faut en documentation sur [Internet][ghphelp].

[ghphelp]: https://help.github.com/categories/github-pages-basics/

Pour une page d'utilisateur ou d'organisation, il faut créer un dépôt git nommé
nom-utilisateur.github.io. Pour moi, l'URL complète c'est
donc: <https://github.com/xakz/xakz.github.io> Ensuite la branche `master`
(celle par défaut donc) sera la branche publiée sur <http://xakz.github.io/>

Et pour une page de projet, il suffit de rajouter une branche `gh-pages`.

Seulement voilà, ces branches `master` ou `gh-pages` sont là pour stocker votre
site statique complètement généré (sauf si on utilise Jekyll). Hors, il y a les
sources (le markdown toussa) du site aussi à stocker quelques part et ce serait
déplorable de faire un second dépôt git pour cela.

Donc la solution c'est de créer un branche orpheline dans le même repo. Il faut
voir ça comme d'avoir 2 dépôts sans commit commun dans le même dépôt. Très pratique
je doit dire.

Voilà comment faire:

1. Créez un dépôt git nommé `votre-pseudo.github.io` sur github

2. Clonez le à la maison: `git clone
   git@github.com:votre-pseudo/votre-pseudo.github.io.git`
   
3. Créz la nouvelle branche orpheline:
```sh
git checkout --orphan source
git reset --hard
git commit --allow-empty -m 'Initialize source branch'
```

4. Un pti push pour être bien: `git push -u origin source`

Nous avons maintenant une branche `master` utilisée pour la publication du site
et une branche `source` utilisée pour le "code source" du site.

Je suggère aussi de définir la branche `source` comme branche par défaut dans
les paramètres de votre dépôt (à faire sur le site github). Ainsi ce sera la
branche clonée lors d'un `git clone`.

# Git worktree
Depuis 2015 et sa version 2.5, git permet de travailler sur plusieurs branches
simultanément grâce aux worktree (`git help worktree`). Alors la fonctionnalité
est encore notée comme expérimentale mais comme on va bosser sur deux branches
totalement indépendantes, il n'y a vraiment aucun risque, même si on utilise des
submodules.

Hugo, et les autres générateurs de site statique, envoient leur sortie vers un
sous dossier (configurable). Nous allons donc définir un sous dossier comme
étant un worktree git pour la branche `master`, dans le cas de Hugo, le dossier
par défaut s'appelle `public`:

```sh
git worktree add public master
```

Le dossier est créé et contient le contenu de la branche `master` ainsi q'un
fichier `.git` indiquant à git où se trouve le `gitdir`.

# Et voilà
On est près a bosser maintenant. Exemple type de procédure, On se trouve dans le
dossier contenant la branche `source` (ex: `~/projects/xakz.github.io`):

1. On édite ou crée un nouveau post: `hugo new post/super-post.md`
2. On pense a se relire et a paufiner :wink:
3. On sauvegarde le fichier
4. On régénère le site: `hugo`
5. On vérifie le resultat sur son navigateur: `firefox public/index.html`
6. On commit: `git add .` puis `git commit -m 'Mon super post'` (ici on commit
   sur la branche `source`)
7. On push (éventuellement): `git push` (c'est toujours la branche `source`)
8. On va dans le dossier `public`: `cd public` (là c'est la branche `master`)
9. On commit: `git add .` puis `git commit -m 'Nouveau super post'`
10. On envoie sur github: `git push`

Evidement l'étape 5 peut être avantageusement remplacée par le système de
LiveReload de Hugo (`hugo serve`), mais il faudra quand même régénérer le site
avec `hugo` (étape 4) car le LiveReload travaille uniquement en RAM, il ne crée
pas de fichier.

Alors vous me direz: "Mouais, 10 étapes, c'est pas ce qui a de plus simple". Et
je répondrais que c'est bel et bien vrai, c'est le lot de tout utilisateur de
git, ce gestionnaire de code source est génial mais compliqué et chaque
opération en apparence simple nécéssite souvent plusieurs commandes. Il faut
savoir qu'à la base git fût conçu pour être utilisé par des outils de plus haut
niveau, il devait juste servir de système de stockage avec les hash, toussa
toussa. Mais voilà, il a bien évolué depuis.

Mais j'ai une solution ! Un Makefile ! En réalité un script shell suffirait mais
j'aime bien les Makefile, c'est propre et flexible.

Le voici:

{{< gist xakz bf382b2211a9a9fe5364575de6ff3c85 >}}

c'est assez simple d'utilisation:

* `make` pour régénérer le site
* `make publish` pour envoyer sur les Github Pages
* `make help` pour une aide sur les differentes "target" disponibles

Pour les commit sur la branche `source`, ça reste à vous de le faire, difficile
d'anticiper tous les cas de figure dans un Makefile pour cette partie.

Il gère aussi l'initialisation juste après un `git clone` pour les submodules et
le worktree `master` dans le dossier `public`.

Il n'est pas parfait, mais fonctionne très bien.

# git-ghp
En fait, ce procédé, avec la branche orpheline et le worktree semble tellement
courant pour les Github Pages que je ne suis dit qu'un petit plugin git serait
bien utile. Alors j'ai amorcé un dépôt prévu à cet effet.

Allez voir, j'ai peut-être terminé depuis: https://github.com/xakz/git-ghp


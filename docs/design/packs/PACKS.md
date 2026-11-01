# Elio — 5 packs d'interface (A à E)

Maquettes **statiques** : rien n'a changé dans l'application. Chaque pack est appliqué à toutes les pages pour pouvoir choisir **page par page**.

- Galerie de comparaison : ouvrir [`index.html`](index.html) dans un navigateur (une ligne par page, une colonne par pack ; clic = image en grand, lien « HTML » = la maquette).
- Images : `png/<pack>-<page>.jpg` (1440 × 1000 ; `-dark` = mode sombre ; `mobile-*` = 390 px).
- Régénérer : `docs/design/packs/build.sh` (Python 3, Tailwind du projet, Chrome, ImageMagick).

| Pack | Nom | Idée | Pour qui |
|---|---|---|---|
| **A** | Console | Barre latérale fixe, tableaux denses, fiche à onglets — l'interface actuelle, affinée. | Ceux qui vivent dans l'outil : beaucoup d'information par écran. |
| **B** | Cartes | Navigation en haut, cartes aérées, grands espaces ; chaque serveur est une carte, accueil « Bonjour Alice ». | Lecture rapide et agréable de l'état du parc. |
| **C** | Opérations | Tout part de « À traiter » : boîte de réception des problèmes, liste et détail côte à côte, recherche centrale. | L'astreinte : on traite les problèmes un par un sans changer de page. |
| **D** | NOC | Mur de supervision, très dense, monospace, coins droits, pensé pour le sombre et les grands écrans. | Écran d'équipe, nuit, beaucoup de serveurs. |
| **E** | Éditorial | Minimal et typographique (serif), peu de cadres, filets fins, résumé du parc écrit en phrases. | Un outil calme qu'on lit comme un rapport. |

Pages : Connexion, Vue d'ensemble, Parc, Fiche serveur, Fiche serveur — Ports, Paquets, Ports, Sondes, Trousseau, Activité, Tâches, Paramètres — Extensions ; en sombre : Vue d'ensemble, Parc, Fiche serveur ; mobile : Parc, Fiche serveur.

## Ton choix

Remplis la colonne « Pack » (A à E) ; tu peux aussi mélanger (« B, avec la densité de A »). Je l'appliquerai ensuite page par page.

| Page | Pack | Remarques |
|---|---|---|
| Connexion | | |
| Vue d'ensemble | | |
| Parc (liste / grille) | | |
| Fiche serveur | | |
| Paquets | | |
| Ports | | |
| Sondes | | |
| Trousseau | | |
| Activité | | |
| Tâches | | |
| Paramètres | | |
| Mobile | | |
| Mode sombre | | |

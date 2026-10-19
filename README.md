# 🍕 Night Shift at Pip's — jeu d'horreur Roblox (inspiré de FNAF)

> Tu es le gardien de nuit de **PIP'S PARTY PALACE**. De minuit à 6 h, les mascottes s'animent.
> Répare les fusibles, ramasse les jetons, livre les objets… puis **fuis par la porte d'entrée**.

Jeu **coop de 1 à 8 joueurs**, nuits courtes (5 min), progression de la nuit 1 à 5 puis mode **Nightmare** infini.
Toute la map 3D, les animatroniques, l'interface et les effets sont **générés par code** : aucun asset externe
à importer, le jeu marche dès l'ouverture dans Roblox Studio.

---

## ✨ Ce qui rend le jeu unique

La plupart des jeux FNAF sur Roblox sont soit des copies du "bureau avec caméras", soit des
"chasses" génériques. Ici, **chaque mascotte a UNE règle simple**, et la nuit ajoute une règle à la fois :

| Mascotte | Règle | Comment survivre |
|---|---|---|
| 🐻 **Bruno l'Ours** (nuit 1+) | Chasse **à la vue** | Casse la ligne de vue, cache-toi dans un casier |
| 🫎 **Maple l'Élan** (nuit 2+) | **Aveugle**, entend la course, les réparations, les capsules | **Marche** quand elle est proche, lance un leurre |
| 🐧 **Pip le Pingouin** (nuit 3+) | Ne bouge **que dans le noir** | Garde ta **lampe torche** braquée sur lui |
| 🃏 **Jinx le Bouffon** (nuit 4+) | Sort quand la **boîte à musique** s'arrête | Remonte la boîte à musique au bureau de sécurité |

Mécaniques originales :
- **Fantômes utiles** : un joueur attrapé devient fantôme, traverse les murs et peut **révéler les mascottes** (touche Q) pour son équipe. Personne n'attend sans rien faire.
- **Résurrection par l'équipe** : chaque objectif terminé ressuscite tous les fantômes → l'entraide est récompensée.
- **Évasion finale** : quand toutes les tâches sont faites, les portes s'ouvrent → course jusqu'au parking (bonus).
- **Le lobby est le parking du restaurant** : on voit l'enseigne néon et on entre physiquement dans le bâtiment.
- **Jumpscare 3D** : gros plan de la mascotte rendu en direct (ViewportFrame), pas une image fixe.

## 🎮 Facile à prendre en main

- Contrôles : `F` lampe · `Shift` courir · `1/2/3` objets · `E` interagir · `Q` (fantôme) révéler. Boutons tactiles sur mobile.
- **Liste des tâches** toujours visible à gauche + **marqueurs 3D** avec distance vers le prochain objectif.
- Tutoriel en 4 écrans au premier lancement (+50 tickets), panneau "Meet the Mascots" dans le lobby.
- Indices de danger lisibles : **les lumières clignotent** quand une mascotte approche, vignette rouge, bandeau "X IS CHASING YOU — RUN!".

## 🎁 Loot

- **Pendant la nuit** : tickets au sol, piles, **Prize Capsules** (Commun → Légendaire) contenant des objets
  (🔋 pile, 🥤 soda de vitesse, 🧸 leurre), des paquets de tickets ou un cosmétique rare.
- **Dans le lobby** : le **Prize Counter** (gacha à tickets, Basique 100 / Deluxe 350) donne des cosmétiques permanents :
  couleurs de faisceau de lampe, traînées, titres au-dessus de la tête. Doublons remboursés.
- **Garde-robe** pour équiper, **récompense quotidienne** avec série (jusqu'à 7 jours), classement global.

## 💰 Monétisation (prête à brancher)

| Type | Offre | Prix conseillé |
|---|---|---|
| Game Pass | **VIP Guard** : x2 tickets + badge doré | 199 R$ |
| Game Pass | **Pro Flashlight** : batterie +70 %, faisceau plus fort | 149 R$ |
| Game Pass | **Lucky Charm** : chances Épique/Légendaire x2 | 249 R$ |
| Dev Product | **Instant Revive** (achat impulsif quand on est fantôme) | 25 R$ |
| Dev Product | **Power Surge** : batterie pleine + soda pour **toute l'équipe** (annoncé à tous = achat social) | 49 R$ |
| Dev Product | 500 / 2000 tickets | 49 / 149 R$ |

Ajoute aussi les **serveurs privés** (Paramètres du jeu → Monétisation) et active les **Premium Payouts** (automatique).
Les reçus sont traités de façon **idempotente** (pas de double crédit) et sauvegardés immédiatement.

---

## 🚀 Lancer le jeu

### Option A — le plus simple (sans rien installer)
1. Ouvre **`build/PipsNightShift.rbxlx`** dans Roblox Studio (double-clic ou *Fichier → Ouvrir*).
2. Clique **Play** ▶️. La map se génère au lancement (c'est normal que l'Explorer soit presque vide en mode édition).
3. Pour tester à plusieurs : onglet *Test* → *Clients and Servers* → 2-4 joueurs.

### Option B — avec Rojo (pour développer)
```bash
rokit install          # ou aftman install (installe Rojo 7.7.1)
rojo serve             # puis plugin Rojo dans Studio → Connect
# ou générer le fichier place :
rojo build -o build/PipsNightShift.rbxlx
```

### Avant de publier
1. *Fichier → Publier sur Roblox*.
2. *Paramètres du jeu → Sécurité* : active **Enable Studio Access to API Services** (sauvegardes & classement).
3. Crée tes Game Passes / Developer Products / Badges sur [create.roblox.com](https://create.roblox.com), puis colle les IDs dans
   **`src/shared/Config.lua`** (`Config.GamePasses`, `Config.Products`, `Config.Badges`). Tant qu'un ID vaut `0`, l'offre affiche "Coming soon".
4. Ajoute des sons (Creator Store → Audio, filtrer "par Roblox" pour être sûr qu'ils soient publics) dans `Config.Sounds`
   : jumpscare, ambiance, musique de poursuite, battement de cœur… Ça change énormément l'immersion.
5. Optionnel : mets l'ID de ton groupe dans `Config.GroupId` (bonus de 150 tickets pour les membres → fait grossir ton groupe).
6. Rebuild (`rojo build …`) ou synchronise, puis republie.

Tout l'équilibrage (durées, vitesses, récompenses, prix) est dans `Config.lua`, `Nights.lua` et `Mascots.lua`.

---

## 🗂️ Structure du code

```
src/
├── shared/                 (ReplicatedStorage.Shared)
│   ├── Config.lua          ← TOUT le réglage + IDs monétisation/badges/sons
│   ├── Nights.lua          ← tâches et mascottes de chaque nuit
│   ├── Mascots.lua         ← stats & règle de chaque animatronique
│   ├── Cosmetics.lua       ← cosmétiques + probabilités du Prize Counter
│   ├── Items.lua           ← objets de nuit + table de loot des capsules
│   └── Remotes.lua         ← RemoteEvents/Functions
├── server/                 (ServerScriptService.Server)
│   ├── Main.server.lua     ← point d'entrée : éclairage, collisions, services
│   ├── MapBuilder.lua      ← génère la pizzeria (11 salles) + parking/lobby
│   ├── AnimatronicBuilder  ← modèles 3D des 4 mascottes
│   ├── AnimatronicService  ← IA (pathfinding, vue, ouïe, gel à la lumière)
│   ├── RoundService        ← boucle Intermission → Nuit → Résultats
│   ├── QuestService        ← fusibles, jetons, livraisons, boîte à musique, sortie
│   ├── LootService         ← tickets, piles, capsules, Prize Counter
│   ├── PlayerService       ← lampe torche, casiers, objets, fantômes, cosmétiques
│   ├── DataService         ← sauvegarde DataStore + classement
│   └── MonetizationService ← passes, produits, groupe, amis, badges
└── client/                 (StarterPlayerScripts.Client)
    ├── Main.client.lua
    ├── UI.lua              ← HUD + boutique + Prize Counter + garde-robe + guide
    ├── Controls.lua        ← clavier/tactile/manette, sprint, lampe
    ├── Effects.lua         ← lumières qui clignotent, vignette, sons
    ├── Jumpscare.lua       ← jumpscare 3D
    └── Markers.lua         ← marqueurs d'objectifs
```

Le plan de croissance pour viser **250 joueurs simultanés** est dans **[docs/LANCEMENT.md](docs/LANCEMENT.md)**.

> ⚖️ Les personnages, le nom et le lieu sont **originaux** (aucune marque FNAF utilisée) : c'est indispensable
> pour éviter une suppression du jeu pour violation de droits d'auteur.

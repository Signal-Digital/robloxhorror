# 📈 Plan de lancement — objectif 250 joueurs simultanés (CCU)

250 CCU sur Roblox, c'est atteignable pour un jeu d'horreur coop bien emballé, mais **le jeu seul ne suffit pas** :
l'algorithme de recommandation de Roblox pousse les jeux qui ont de bonnes métriques sur un petit trafic initial.
Le plan ci-dessous sert à obtenir ce premier trafic, puis à le garder.

## 1. Les métriques que Roblox regarde (et ce que le jeu fait déjà pour elles)

| Métrique | Cible réaliste | Leviers déjà dans le code |
|---|---|---|
| Rétention J1 | > 15 % | Récompense quotidienne avec série, progression des nuits, cosmétiques à collectionner |
| Temps de session | > 15 min | Nuits de 5 min enchaînées automatiquement, mode Nightmare infini, fantômes actifs (pas d'attente morte) |
| Taux de "play" sur la vignette | > 4 % | → dépend de ton icône / miniatures (voir §2) |
| Revenu / visite | > 0,5 R$ | Revive impulsif, Power Surge social, VIP x2, Lucky Charm |
| Joueurs par serveur | 4-8 | Bonus +20 % avec un ami, bouton Inviter, tâches qui récompensent le travail d'équipe |

## 2. L'emballage (le plus important pour démarrer)

**Titre** (court, mot-clé + promesse) — exemples :
- `Night Shift at Pip's 🍕 [HORROR]`
- `Survive Pip's Pizzeria 👻`

Mets un emoji et, à chaque mise à jour, un tag : `[NIGHT 6!]`, `[NEW MASCOT]`, `[HALLOWEEN]`.

**Icône** : le visage d'UNE mascotte en très gros plan (Pip le pingouin aux yeux bleus brillants marche très bien),
fond sombre, contraste fort. Fais une capture du jumpscare dans Studio et retouche-la.

**Miniatures (3 minimum)** : 1) la mascotte qui surgit du noir dans le faisceau de la lampe, 2) l'enseigne néon
"PIP'S PARTY PALACE" vue du parking, 3) un groupe de joueurs qui fuit par la porte d'entrée. Ajoute 1 vidéo de 30 s.

**Description** : 3 lignes max en haut ("Survive 5 nights with your friends! Each mascot has ONE rule…"),
puis la liste des mises à jour.

**Genre** : Horror. Active la **traduction automatique** (Paramètres → Localisation) : le jeu est en anglais pour
toucher le plus grand public, Roblox traduit automatiquement en français, espagnol, portugais…

## 3. Le trafic initial

1. **Semaine 0 — test fermé** : 10-20 amis / membres Discord, corrige les bugs, mesure la durée des sessions.
2. **Publicité sponsorisée Roblox** (Ads Manager) : commence petit (≈ 1 000-3 000 R$ sur 3-5 jours) ciblant
   "Horror" 9-17 ans, puis double le budget sur la miniature qui a le meilleur taux de clic.
3. **TikTok / YouTube Shorts** : le jumpscare 3D est fait pour être filmé. Publie 1 short/jour pendant 2 semaines :
   réaction au jumpscare, "la règle secrète de Pip", évasion de justesse. Mets le nom du jeu dans la vidéo.
4. **Créateurs de contenu** : contacte des petits YouTubeurs horreur Roblox (5k-50k abonnés), offre-leur le VIP.
5. **Groupe Roblox** : `Config.GroupId` donne 150 tickets aux membres → le groupe grossit, et chaque annonce
   de mise à jour (shout) ramène les joueurs.

## 4. Garder les joueurs (rythme de mises à jour)

Les jeux qui atteignent puis tiennent 250 CCU mettent à jour **toutes les 1-2 semaines** au début :

- **v1.1** : Nuit 6 avec une 5ᵉ mascotte (ex. "Taffy la Pieuvre" qui éteint les lumières des salles).
- **v1.2** : nouvelle salle (sous-sol / ball pit), nouveaux cosmétiques Légendaires.
- **v1.3** : événement limité (Halloween / Noël : capsules spéciales, cosmétiques qui disparaissent après l'event → urgence).
- **v1.4** : mode "Hardcore" (1 vie, pas de revive) avec badge exclusif, idéal pour les vidéos.
- Ajoute un **code promo** à chaque update (ex. "NIGHT6" = 100 tickets) diffusé sur Discord/TikTok.

## 5. Monétisation : réglages conseillés

- Garde les prix de `Config.ShopCatalog` (ils sont dans les fourchettes qui convertissent bien chez les 9-15 ans).
- Le **Revive à 25 R$** est l'achat n°1 de ce genre de jeu : il apparaît au moment exact où le joueur est frustré.
  Un bouton "💖 REVIVE NOW" s'affiche automatiquement sous le bandeau fantôme dès que l'ID est renseigné.
- Active les **serveurs privés** (≈ 50-100 R$/mois) : les groupes d'amis adorent.
- Ne vends jamais d'avantage écrasant : les passes accélèrent, ils ne garantissent pas la victoire → pas de frustration.

## 6. Checklist avant la mise en ligne

- [ ] IDs de passes / produits / badges dans `Config.lua`
- [ ] Sons ajoutés dans `Config.Sounds` (jumpscare, ambiance, poursuite, battement de cœur)
- [ ] Accès API activé (sauvegarde + classement)
- [ ] Testé sur **mobile** (émulateur Studio : iPhone & tablette) — plus de 50 % des joueurs Roblox sont sur mobile
- [ ] Questionnaire de maturité rempli (horreur légère → "Mild"/"Moderate" selon ton intensité)
- [ ] Icône + 3 miniatures + description
- [ ] Groupe Roblox + Discord créés

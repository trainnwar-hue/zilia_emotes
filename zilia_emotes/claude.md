\# EMOTES.md — Système d'emotes (addon Zilia / Roa Admin System)



Module autonome ajouté à l'addon décrit dans `CLAUDE.md`. Testé en solo, \*\*pas encore intégré\*\* au serveur.

Code GLua, conventions du projet : préfixes hongrois, tabulations, double quotes,

noms réseau/hooks `Roa:AdminSys:\*`. Les textes en jeu sont en français.



\## Fichiers et rôles

| Fichier | Realm | Rôle |

|---|---|---|

| `lua/dev/shared/sh\_emotes\_config.lua` | shared | \*\*Seul fichier de config\*\* : `LookPitch`, `ThrowKey`, `BlockedBindKeys`, `Categories`, `List` |

| `lua/dev/shared/sh\_emotes.lua` | shared | Validation de la liste, cache des séquences, état, calcul de phase, `CalcMainActivity`, `StartCommand` (saut/annulation), encapsulation de `GM:GrabEarAnimation` |

| `lua/dev/server/sv\_emotes.lua` | server | Messages réseau, validations, start/stop, annulation, R = arrêt instantané |

| `lua/dev/client/cl\_emotedata.lua` | client | Échelle UI (`ZiliaEmotes.S`), favoris et raccourcis (`data/ziliadata/emotes.json`), `ToggleEmote`, déclenchement des raccourcis |

| `lua/dev/client/cl\_emotecamera.lua` | client | Orbite, zoom molette, flou directionnel, verrouillage et restauration de la vue |

| `lua/dev/client/cl\_emotepreview.lua` | client | Aperçu au survol (`DModelPanel` + copie des vêtements mergés) |

| `lua/dev/client/cl\_emotemenu.lua` | client | Interface (touche P, catégories, étoile, icône raccourci) |



\*\*Fichiers de test uniquement (à NE PAS intégrer)\*\* :

\- `lua/autorun/zilia\_emotes\_load.lua` (loader temporaire) ;

\- `lua/dev/server/sv\_testbody.lua` (commande `zilia\_testbody`, applique `homme\_base` + vêtements) ;

\- copie de `lua/entities/ent\_modular\_part/`.



\*\*Ordre de chargement\*\* : config → `sh\_emotes` → `sv\_emotes` | client : `cl\_emotedata` en premier,

puis `cl\_emotecamera`, `cl\_emotepreview`, `cl\_emotemenu`.



\## Namespace

Global unique `ZiliaEmotes`. API entre fichiers :

\- \*\*Shared\*\* : `List`, `ByID`, `GetSequence`, `GetDuration`, `GetLookPitch`, `GetState`, `GetActive`, `GetPhase`.

\- \*\*Server\*\* : `OnEmoteCommand`.

\- \*\*Client\*\* : `S`, `UpdateScale`, `IsPokemon`, `IsFavorite`, `ToggleFavorite`, `GetBind`, `SetBind`,

&#x20; `IsBindKeyAllowed`, `IsPlaying`, `ToggleEmote`, `CreatePreview`, `DestroyPreview`, `SetPreviewTarget`.



\## Config d'une emote

```lua

{ID = "arms\_crossed", Category = "poses", Name = "Bras Croisé", Loop = "nb\_d21\_lobby\_win\_loop"}

```

\- `Start`, `Loop` et `End` sont optionnels (au moins un requis).

&#x20; - `Loop` seul : continu jusqu'à l'annulation.

&#x20; - `Start`, `Loop`, `End` : `End` joué à l'arrêt.

&#x20; - Sans `Loop` : `Start` puis `End`, puis arrêt automatique.

\- `ID` est la clé persistée chez les joueurs (favoris, raccourcis) : \*\*ne jamais la renommer\*\*.

\- `LookPitch` est optionnel (regard ; négatif = vers le haut, -89 au maximum).



\## Fonctionnement

\- \*\*Synchronisation\*\* :

&#x20; - état stocké dans les NW vars `ZiliaEmote` (index), `ZiliaEmoteStart` et `ZiliaEmoteStop` (CurTime) ;

&#x20; - côté serveur, `GetState` est remplacée par une lecture du champ Lua `pPlayer.tZiliaEmoteState` (performances) ;

&#x20; - même principe que `ForceDeathAnim` dans `animation.lua`.

\- \*\*Animation\*\* :

&#x20; - `CalcMainActivity` renvoie `ACT\_INVALID, nSequence` ;

&#x20; - `SetCycle` est appelé à chaque image ;

&#x20; - la phase est calculée uniquement à partir du temps, donc identique sur le serveur, chez les clients et dans l'aperçu.

\- \*\*Réseau\*\* (client → serveur uniquement) :

&#x20; - `Roa:AdminSys:RequestEmote` (UInt 10 bits) et `Roa:AdminSys:StopEmote` ;

&#x20; - limités à un message toutes les 0,3 s ;

&#x20; - le serveur vérifie : vivant, au sol, `MOVETYPE\_WALK`, pas `IsPoke`, pas `InCombat`, séquences présentes sur le modèle.

\- \*\*Annulation\*\* :

&#x20; - seulement par déplacement, saut et accroupi (commandes du jeu, donc indépendant du clavier), puis passage par `End` s'il existe ;

&#x20; - \*\*R (`KEY\_R`, touche physique de lancer de Pokéball)\*\* arrête instantanément, sans `End` (hook serveur `PlayerButtonDown`) ;

&#x20; - les autres touches passent et n'annulent pas.

\- \*\*Saut\*\* :

&#x20; - retiré tant que la touche est enfoncée ;

&#x20; - côté client, `StartCommand` modifie la commande envoyée : le saut est donc remplacé par le signal `IN\_BULLRUSH` (bouton inutilisé), ajouté \*\*à chaque commande\*\*.

\- \*\*Vue\*\* :

&#x20; - pendant l'emote, les angles envoyés sont figés (`pitch = LookPitch`, yaw de départ) : corps, tête et vêtements immobiles pour tous ;

&#x20; - la souris pilote une caméra séparée (orbite) ;

&#x20; - verrouillage et restauration dans `CreateMove` (qui tourne même menu ouvert) ; souris dans `InputMouseApply` ;

&#x20; - vue d'origine restaurée (`SetEyeAngles`) à la fin, ou dès que R est pressé.

\- \*\*Mode Pokémon\*\* (`GetNWBool("IsPoke")`) : le menu ne s'ouvre pas (aucun message), les raccourcis sont inactifs.

\- \*\*Raccourcis\*\* :

&#x20; - refusées : `BlockedBindKeys` (K, L, M, R, J, P), les touches liées à `+forward`, `+back`, `+moveleft`, `+moveright`, `+jump`, `+duck`, ainsi qu'Échap et Retour arrière ;

&#x20; - une touche correspond à une seule emote.

\- \*\*Geste du chat\*\* (main à l'oreille) : coupé pendant l'emote, en encapsulant `GM:GrabEarAnimation` (la fonction d'origine est appelée sinon).



\## Décisions et pièges (ne pas refaire)

\- Ne pas utiliser `SetRenderAngles` dans `PrePlayerDraw` : décalage entre le corps et les vêtements. On fige les angles de vue à la place.

\- Ne pas utiliser `DrawMotionBlur` (effet « filtre Garry's Mod ») : flou directionnel maison sur `\_rt\_FullFrameFB`.

\- Vêtements = `ent\_modular\_part` : le bonemerge est appliqué \*\*côté client\*\* dans son `cl\_init.lua`. `prop\_dynamic` ne fonctionne pas.

\- `PlayerButtonDown` ne tourne pas côté client en solo 1 joueur : tester avec 2 joueurs maximum ou plus.

\- L'aperçu ignore les armes (`IsWeapon()`) parmi les entités mergées.

\- Après une modification de la config : \*\*changement de map\*\*, pas de rechargement à chaud (les index seraient perdus).



\## À faire à l'intégration

1\. Supprimer le loader temporaire et ajouter les `include`/`AddCSLuaFile` dans `roa\_admin\_system\_load.lua`. Ne pas copier les fichiers de test.

2\. \*\*Demander le code de la troisième personne du serveur\*\* : risque de conflit `CalcView` (Garry's Mod n'utilise que la première vue renvoyée).

3\. Vérifier que `FixAnimSpeed` (vitesse forcée à 1.2) n'accélère pas les emotes (normalement neutralisé par `SetCycle`).

4\. Vérifier qu'aucun système n'utilise déjà la touche P, et si `pPlayer.InCombat` existe côté serveur.

5\. Optionnel : regrouper `DrawFilledStar`, `DrawCross` et `StyleScrollBar` (en double avec `cl\_music.lua`) ; remplacer les polices locales par `ZPFont`.



\## Réglages fréquents

\- \*\*`cl\_emotecamera.lua`\*\* :

&#x20; - caméra : `CAMERA\_DISTANCE`, `CAMERA\_MIN\_DISTANCE`, `CAMERA\_MAX\_DISTANCE`, `CAMERA\_PIVOT\_HEIGHT`, `CAMERA\_RAISE`, `CAMERA\_ANGLE\_SMOOTHING` ;

&#x20; - flou : `BLUR\_STRENGTH`, `BLUR\_MAX\_PIXELS`, `BLUR\_SAMPLES`.

\- \*\*`cl\_emotepreview.lua`\*\* : `PREVIEW\_W`, `PREVIEW\_H`, `PREVIEW\_FRAMING`, `PREVIEW\_LOOPS`, `COLOR\_PREVIEW\_BG`.

\- \*\*Config\*\* : `LookPitch`, `ThrowKey`, `BlockedBindKeys`.


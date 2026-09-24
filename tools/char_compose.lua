-- Character-token COMPOSER -- the item icon-composer (tools/icon_compose.lua), one register up.
--
--     & "E:\LOVE\lovec.exe" . char-compose            # every character -> vendor/compose-preview/chars/
--     & "E:\LOVE\lovec.exe" . char-compose assets      # ... publish into assets/chars/, skipping real art
--     & "E:\LOVE\lovec.exe" . char-compose assets force # ... and overwrite even where real art exists
--
-- SAME PHILOSOPHY AS ITEMS: an item's icon is a pure function of the tags it already declares (family +
-- element + class + tier), so a new item costs zero art. A character token is the same idea for the
-- board: the ~37 creatures, enemies and NPCs that will never earn a painted portrait don't wait on a
-- commission and don't sit forever as the bare initial-in-a-disc fallback (ui/battle_map.lua drawUnits) --
-- they get a distinct, legible token drawn from fields the blueprint already carries. The named cast
-- still drops in a painted head crop later; `assets` mode SKIPS any id that already has real art on disk,
-- exactly the way icon-build leaves purchased art alone (docs/art-assets.md, "compose, don't commission").
--
-- Three baked layers, three data channels, none of them a commission:
--
--   1. BASE   a silhouette. Guessed in two tiers, like icon-map: a direct creature/name match first
--             (a boar token looks like a boar), then a `kind` fallback (humanoid/beast/elemental/
--             construct/demon/undead/object). `kind` is itself derived from the blueprint, or set
--             explicitly as `kind = "beast"` to correct a guess -- the overrides.lua pattern.
--   2. TINT   the silhouette is recoloured by element (elementals), else by kind, else class/steel.
--   3. BADGE  a gold disc for a boss/general; ordinary units carry none.
--
-- There is DELIBERATELY no baked frame. A token's border is its battlefield SIDE -- blue for ours, red
-- for theirs -- and side is a runtime fact the blueprint cannot know (one archer token serves a party
-- archer and an enemy one). So the board draws that frame itself, in the unit's side colour, around the
-- token (ui/battle_map.lua drawUnits). Baking a class-of-shelf colour here would only fight it. The
-- token is a plate + silhouette (+ a boss's gold disc); the frame lands at draw time.
--
-- The base slugs are canonical game-icons picks (reuse, not commission). Output mirrors icon-compose:
-- vendor/compose-preview/chars/ by default, so a prototype run can never clobber the shipped set; only
-- the explicit `assets` arg writes assets/chars/.

local Registry = require("models.registry")
local Class = require("models.class")
local Source = require("tools.icon_source")

local M = {}

local RESVG = "vendor/bin/resvg.exe"
local PREVIEW_ROOT = "vendor/compose-preview/chars"
local ASSET_ROOT = "assets/chars"
local RENDER_SIZE = 256

-- 1a. Direct creature/object silhouettes, matched as a substring of the blueprint id. Ordered by
-- specificity: a longer, more specific key is tried before a shorter one it contains (dire_bear before
-- bear is moot -- both land on the bear -- but demon_lord must not be shadowed by a stray "demon" pick
-- that loses the head). First match in this list wins, so keep the specific ones up top.
local CREATURE_MATCH = {
    { "boar", "caro-asercion/boar" },
    -- THE TWO BEARS ARE NOT ONE BEAR, and the ordering note this pair used to carry ("dire_bear before
    -- bear is moot -- both land on the bear") stopped being true the day a bear anybody fights existed.
    -- The Dire Bear is CARGO, a shape a hunter wears; character_bear is a body on the road. They are
    -- separate blueprints for the reason the Gralloch was authored, so they may not be one picture.
    { "dire_bear", "delapouite/bear-head" }, -- the shape keeps the head it has always shipped
    { "bear", "sparker/bear-face" },         -- ...and the animal gets its own face
    -- Before "wolf" only because it must be before the `beast` KIND fallback, which is the wolf's head:
    -- a wyrm matching nothing here fell through to it and came out pixel-identical to a wolf grunt.
    { "wyrm", "delapouite/spiked-dragon-head" },
    { "wolf", "lorc/wolf-head" },
    { "hawk", "lorc/hawk-emblem" },
    { "raven", "lorc/raven" },
    -- THE TWO STAGS ARE NOT ONE STAG, on the two bears' rule above and for the same reason: the
    -- Ancient Stag is a body on the road and the Meandering Stag is the apex above it, and a pair of
    -- blueprints that a player meets separately may not be one picture. Both of these must sort ABOVE
    -- the bare "stag" key, which their ids contain.
    --
    -- The apex takes the WHOLE ANIMAL rather than a head, which is the one silhouette decision here
    -- that is about the fight: this thing is never standing in front of you long enough to be a face.
    { "meandering_stag", "caro-asercion/deer" },
    -- ...and what it becomes is not a deer at all. It keeps nothing of the animal's outline, because
    -- the whole beat is that something else is looking out of it.
    { "vengeful_spirit", "lorc/spark-spirit" },
    { "stag", "lorc/stag-head" },
    { "pig", "lorc/pig-face" },
    { "ogre", "delapouite/ogre" },
    { "imp", "lorc/imp-laugh" },
    { "demon", "lorc/daemon-skull" },
    { "golem", "delapouite/rock-golem" },
    { "zombie", "sbed/death-skull" },
    { "ghost", "lorc/ghost" },
    { "spirit", "lorc/ghost" },
    { "vigil", "lorc/spectre" },
    { "blightstake", "lorc/spectre" },
    { "scarecrow", "lorc/scarecrow" },
    { "straw", "lorc/scarecrow" },
    { "totem", "delapouite/totem" },
    { "banner", "delapouite/flag-objective" },
    { "standard", "delapouite/flag-objective" },
    -- The escort/defend NPCs the road and flight legs are fought over. They are classless humanoids, so
    -- without a name of their own they collapse onto the rank swordman -- the very look the units guarding
    -- them wear. A cornered civilian reads as a raised-hands plea; the caravan reads as the wagon it is (a
    -- thing to escort, tinted wood by `kind = "object"` on its blueprint, not steel). The caravan MASTER
    -- keeps the default body: he holds at the gate as one more figure in the line, not the rolling column.
    { "caravan_driver", "delapouite/caravan" },
    { "survivor", "sbed/help" },
}

-- 1b. Humanoid silhouette by class -- the fallback when nothing in CREATURE_MATCH fires and the body is
-- a person. Class is the same vendor-shelf field items key their frame on, and this table is the ONE
-- place a discipline earns a body of its own: each of the seven shelves (docs/classes.md) reads as a
-- different armed person, so an archer (hunter) never wears the knight's silhouette. Keep this list to
-- the seven live classes -- a key no character carries (the old cleric/ranger/archer) is dead weight,
-- and a class with no entry silently collapses onto HUMANOID_DEFAULT, which is how every discipline but
-- fighter used to come out an identical swordman.
local CLASS_SILHOUETTE = {
    fighter = "delapouite/sword-brandish",   -- wrath: the raised blade, mid-swing
    knight = "delapouite/knight-banner",     -- sloth: the wall that holds its post
    rogue = "darkzaitzev/hooded-figure",     -- greed: the hood
    hunter = "delapouite/archer",            -- gluttony: the bow at draw
    mage = "delapouite/wizard-face",         -- pride: the caster
    priest = "lorc/prayer",                  -- lust: the supplicant
    alchemist = "lorc/bubbling-flask",       -- envy: the borrowed brew, not a blade
}
-- The neutral rank-and-file body: a classless humanoid enemy (bandit, champion) and any class with no
-- silhouette of its own. Deliberately NOT the fighter's sword-brandish, so a mook reads as a mook and a
-- wrath-shelf combatant reads as the discipline.
local HUMANOID_DEFAULT = "cathelineau/swordman"

-- The player's own avatar (the classless "Stranger" survivor). A plain standing figure of its own,
-- so YOUR body on the board reads as a person and not one more rank swordman. It is the one blueprint
-- with TWO runtime sprites -- body 1/2, chosen at creation (states/prologue.lua builds
-- assets/chars/avatar_<body>.png) -- and both use this figure; the composed token is a placeholder for
-- the eventual painted portrait, which is where the two bodies actually differ. run() emits both files.
local AVATAR_SILHOUETTE = "delapouite/person"
local AVATAR_BODIES = { "assets/chars/avatar_1.png", "assets/chars/avatar_2.png" }

-- The imposing figure for a boss/general who has NO class and no creature look of their own -- the seven
-- sin generals are exactly this: `boss = true`, classless, and otherwise indistinguishable from a rank
-- swordman. An overlord's horned helm reads "this is the one to kill" at a glance, and the gold frame the
-- boss already earns ties it together. A boss WITH a class keeps its role silhouette (a fighter boss still
-- reads fighter) and a boss that is a demon/beast keeps its creature -- only the generic humanoid is lifted.
local BOSS_SILHOUETTE = "delapouite/overlord-helm"

-- 1b-bis. DISCIPLINE silhouette -- the one place a *discipline* earns a body distinct from its class.
-- CLASS_SILHOUETTE gives a whole shelf one body (all seven mage-disciplines would otherwise share the
-- wizard); this table gives each of the 37 disciplines (docs/disciplines-plan.md) its own game-icons
-- shape, so a Necromancer never wears the plain mage token. Reviewed shape-by-shape with the author.
-- It is applied ONLY to a discipline's `exemplar` character (the reverse index below), keyed off the
-- pointer and never a loose substring -- so a "demon_champion" is not mistaken for the Champion, and each
-- discipline owns exactly one board body.
local DISCIPLINE_SILHOUETTE = {
    -- fighter subclasses
    barbarian = "delapouite/enrage",      warlord = "lorc/tattered-banner",
    -- knight subclasses
    sentinel = "lorc/shield-echoes",      bulwark = "delapouite/vibrating-shield",
    -- rogue subclasses. The Thief wears the purse it takes; the Mammonite wears the hand PAYING one,
    -- which is the whole difference between them (data/classes/mammonite.lua) -- and neither is
    -- Aurea's coins-pile below, a hoard rather than a transaction.
    assassin = "lorc/backstab",           thief = "lorc/shiny-purse",
    -- The contract, not the coin. The thief already owns the purse and Aurea the coins-pile, and the
    -- Mammonite is neither of them stealing harder: it is a collections contractor whose paperwork is
    -- impeccable and whose work is entirely legal (data/characters/character_mammonite.lua).
    mammonite = "delapouite/contract",
    -- hunter subclasses
    druid = "lorc/werewolf",              beastmaster = "lorc/hound",       trapper = "lorc/mantrap",
    -- mage subclasses
    elementalist = "delapouite/prism",    summoner = "lorc/magic-portal",   necromancer = "delapouite/skull-staff",
    -- priest subclasses
    monk = "lorc/meditation",             exorcist = "lorc/holy-symbol",
    -- alchemist subclasses
    poisoner = "lorc/poison-bottle",      bombardier = "lorc/grenade",
    -- multiclasses
    champion = "lorc/laurel-crown",       duelist = "sbed/duel",            skirmisher = "lorc/barbed-spear",
    battlemage = "lorc/lightning-saber",  crusader = "delapouite/cross-shield", warbrewer = "lorc/beer-stein",
    vanguard = "lorc/broken-shield",      warden = "delapouite/watchtower", spellbreaker = "lorc/shatter",
    paladin = "delapouite/templar-shield", plague_knight = "delapouite/plague-doctor-profile",
    poacher = "lorc/wolf-trap",           ninja = "darkzaitzev/ninja-head", inquisitor = "lorc/templar-eye",
    saboteur = "delapouite/dynamite",     shaman = "lorc/totem-mask",       totemist = "delapouite/totem",
    herbalist = "delapouite/herbs-bundle", theurge = "delapouite/heaven-gate", artificer = "delapouite/walking-turret",
    apothecary = "delapouite/remedy",
}

-- 1b-ter. CHARACTER silhouette -- the narrowest tier, and the last one added. The three tiers below it
-- each hand a WHOLE BUCKET one body: every knight-class blueprint came out the same knight-banner, every
-- classless boss the same overlord-helm, every demon the same daemon-skull. That is correct for the
-- generic template at the head of each bucket and wrong for everyone else in it -- 51 of the 107
-- blueprints resolved to just 15 pictures, so the seven sin generals were one image, and Rowan, the
-- Forsworn Captain and the Road-Knight were another. Several blueprints already say in prose that they
-- must not converge (character_greywatch_captain: "the silhouettes must not converge").
--
-- So: a bucket's silhouette stays the property of the GENERIC body at its head (character_knight keeps
-- knight-banner, character_bandit the rank swordman, character_demon_grunt_tutorial the daemon skull), and every
-- other occupant is lifted out by name here. Keyed by tokenId, exact match -- never a substring -- so it
-- behaves like the discipline tier and cannot fire on a lookalike id.
--
-- tests/char_compose_spec.lua asserts the resulting invariant directly: no two blueprints resolve to the
-- same silhouette, except the deliberate aliases below.
local CHARACTER_SILHOUETTE = {
    -- THE HIRING HALL'S THIRTY-EIGHT. Each is a named version of a discipline whose exemplar keeps its
    -- own body (the exemplars are still the unnamed things you meet on a floor), so every one of these
    -- would otherwise fall through to its CLASS silhouette and land pixel-identical to the six other
    -- heroes off the same shelf. Each wears what it actually DOES instead -- the relic's verb where
    -- there is one, the discipline's where there is not.
    brann = "lorc/axe-swing",                       -- the Red Account: swung out of a hole he dug
    marek = "lorc/crossed-sabres",                  -- the order, not the arm that carries it out
    ilse = "lorc/bordered-shield",
    dov = "delapouite/brick-wall",                  -- Doorstone: he closes doors
    vess = "lorc/hidden",
    pim = "delapouite/robber",
    cass = "delapouite/money-stack",
    mira = "lorc/leaf-swirl",
    tola = "lorc/paw-print",
    sela = "delapouite/cage",
    nio = "lorc/fire-silhouette",
    isa = "lorc/magic-swirl",
    cael = "lorc/skull-crack",
    sunho = "delapouite/monk-face",
    nell = "delapouite/holy-water",
    zosia = "lorc/poison-gas",
    pol = "lorc/bombing-run",
    aldo = "delapouite/champions",
    elio = "delapouite/fencer",
    fen = "delapouite/running-shoe",
    garan = "delapouite/spell-book",
    osric = "delapouite/prayer-beads",
    hilde = "delapouite/beer-bottle",
    dray = "delapouite/hammer-break",
    corin = "delapouite/barrier",
    ivo = "lorc/silence",
    solene = "lorc/shield-reflect",
    grell = "lorc/biohazard",
    rask = "lorc/bolas",
    miro = "darkzaitzev/ninja-heroic-stance",
    calla = "lorc/gavel",
    nix = "delapouite/detonator",
    ondo = "lorc/tornado",
    tuva = "lorc/rune-stone",
    sorrel = "delapouite/forest-camp",
    ilan = "lorc/candle-flame",
    wick = "delapouite/factory-arm",
    ansel = "delapouite/medicine-pills",

    -- Off the rank swordman. The escortee is the trade he leads, not a mook; the homunculus is a made
    -- thing; the Breachward is the big grunt its own comment calls it; and the Trapper is the Bolas it
    -- throws (the ability that IS its job -- data/items/ability/ability_bolas.lua).
    caravan_master = "lorc/trade",
    homunculus = "lorc/frankenstein-creature",
    siege_breaker = "delapouite/brute",
    trapper = "delapouite/hunting-bolas",

    -- Off the rogue's hood. Kaen's whole read is the decoys (Shadowclone), so he wears two shadows.
    -- The Bandit Chief used to fall through to the classless BOSS lift; the bestiary pass made him a
    -- Thief (docs/bestiary.md), which handed him the rogue's hood and put him pixel-identical to the
    -- generic rogue. He wears what he actually does instead -- the Undercroft does not kill you, it
    -- prices you, and the fist of coins is his Shakedown.
    clem = "lorc/cloak-dagger",
    kaen = "lorc/two-shadows",
    bandit_chief = "lorc/profit",

    -- Off the hunter's drawn bow.
    kaya = "delapouite/bow-string",

    -- Off the objective flag: the Banner keeps it, the March Standard is the other standing marker.
    field_standard = "delapouite/vertical-banner",

    -- Off the knight banner, which character_knight (the generic template) keeps. This bucket was the
    -- worst offender -- eight bodies, one picture -- and the line's whole thesis is that they differ:
    -- the oath kept (Rowan), the order in good standing, the ones who took Acedia's terms, and the
    -- nineteen who refused them.
    rowan = "cathelineau/swordwoman",
    bastion_sworn = "delapouite/attached-shield",   -- sword, shield, brace: what the order sells
    forsworn_knight = "lorc/spears",                -- the spear IS its tactical job
    forsworn_captain = "delapouite/centurion-helmet",
    grey_knight = "delapouite/black-knight-helm",   -- knightly forms, no colours anyone can place
    greywatch_captain = "delapouite/guards",        -- he holds the camp, and has for fifteen years
    greywatch_refuser = "delapouite/rusty-sword",   -- still in the forms, struck off the rolls

    -- Off the overlord helm, which stays with the rank classless boss (the Bandit Chief). The seven
    -- generals are the game's marquee kills and each is a SIN -- so each reads as its own.
    general_wrath = "delapouite/angry-eyes",
    general_wrath_demon = "lorc/flame-claws",       -- Ira's phase two: the bargain come due, made flesh
    general_pride = "delapouite/imperial-crown",
    general_greed = "delapouite/coins-pile",
    general_envy = "lorc/voodoo-doll",              -- the Unborn: a made effigy of a person
    general_gluttony = "lorc/gluttony",
    gula_the_apex = "delapouite/t-rex-skull",       -- Gula's phase two: the apex of the wood, and what it ate
    general_lust = "lorc/pentagram-rose",           -- the pacted Saint
    general_sloth = "delapouite/broken-wall",       -- the Bastion's own wall, given way

    -- Off the rock golem, which the Crucible Golem keeps. The discard is the same made thing as the
    -- homunculus above and must not read as it: what the Crucible's cargo IS on the board is the one
    -- detail the quest gives it, and the detail is the eyes.
    ordnance_sentry = "sbed/turret",
    homunculus_discard = "delapouite/blindfold",

    -- Off the fighter's raised blade, which character_fighter (the generic) keeps.
    saber = "lorc/saber-slash",
    -- ALIAS, and the one deliberate duplicate in this file: character_saber_bout is Saber herself as the
    -- debut bout fields her (a shallow copy of the companion blueprint), so she must READ as Saber. She
    -- also inherits def.sprite, so both ride one file -- nothing extra is rendered for her.
    saber_bout = "lorc/saber-slash",

    -- Off the Totemist's totem: the discipline exemplar keeps it, the planted object gets the carved head.
    totem = "lorc/totem-head",

    -- THE CROWN AT THE BOTTOM OF THE BARROWS, and the one body down there that gets an entry. The
    -- Skeleton King is the only skeleton in the game that is its OWN blueprint rather than a living one
    -- with something done to it, and the board is supposed to say so before he takes a turn: every other
    -- body on that floor is a silhouette the player has seen alive, and this is the one that is not.
    -- Without a line here he would fall through to the undead bucket's head (sbed/death-skull) and read
    -- as generic chaff at the exact moment he most needs to read as the end of something.
    the_skeleton_king = "lorc/crowned-skull",

    -- THE REST OF THE ORCHARD'S DEAD, AND THEY WEAR THE SILHOUETTE THEY DIED IN. Each one extends a
    -- living blueprint and rides that body's own token (they name the same `sprite`, so the composer
    -- writes the file once and they ride along) -- and what separates them on the board is the bone SKIN
    -- applied at draw time, not a picture of their own.
    --
    -- THEY NEED A LINE HERE ANYWAY, and the reason is worth writing down because it is not obvious: a
    -- humanoid's silhouette is resolved from its CLASS, and a corpse declares no class -- an undead has
    -- no shelf (docs/bestiary.md), so the inherited one is cleared on every one of these blueprints. That
    -- drops them straight through to the undead bucket's head, where all three land on sbed/death-skull
    -- together with the zombie. So the class lookup they can no longer reach is restated here, by hand,
    -- which is also the honest way to say it: this is a dead KNIGHT, and it is shaped like one.
    skeleton_knight = "delapouite/knight-banner",
    barrow_lord = "delapouite/knight-banner",
    skeleton_archer = "delapouite/archer",

    -- (THE BONE ORCHARD'S DEAD ARE OTHERWISE ABSENT FROM THIS TABLE. They are not bodies of their
    -- own -- each one EXTENDS a living blueprint and inherits its `sprite`, so the Skeleton Knight is
    -- drawn from the knight's own token and the Skeleton Archer from the archer's. What makes them read
    -- as dead is the bone SKIN (see the SKIN table below), applied at draw time off the aspect item they
    -- carry. Giving them silhouettes here would be undoing the thing that makes them worth having.)

    -- Off the generic mage / alchemist bodies.
    gyeom = "lorc/wizard-staff",
    ren = "lorc/standing-potion",

    -- Off the daemon skull, which the rank Demon Grunt keeps. The horde is a ladder -- bomblet, champion,
    -- lord -- and the ladder should be visible on the board.
    --
    -- THE `_tutorial` IS PART OF THE KEY, because these keys are tokenId(blueprint id) and Act 0's four
    -- demons carry the suffix now (data/characters/character_demon_imp_tutorial.lua says why). Drop it
    -- and the entry stops matching -- silently, since an unmatched body just composes off its race base.
    -- The Demon Lord is the rift's and keeps its bare id.
    demon_bomblet_tutorial = "delapouite/inferno-bomb", -- a demon bred hollow and filled with fire
    demon_champion_tutorial = "delapouite/devil-mask",
    demon_lord = "caro-asercion/tarot-15-the-devil",

    -- Off the priest's supplicant. NOT a nun's face: the Cathedral brands her fallen and she walks out
    -- of it, so a habit is the one thing her token must not be. Hands, lit -- what she DOES, on the same
    -- rule the Gluttony and Envy circles below follow.
    xin = "lorc/glowing-hands",

    -- THE CAVED COMPANIONS USED TO BE ALIASED HERE -- seven of them, each pointing at its own base so a
    -- companion the player had spoiled read as herself when the Hollow Crown turned her. Both the
    -- blueprints and models/temptation.lua that produced them are cut, so the aliases went with them.

    -- Off the spectre, which the Gaunt Vigil (a hooded iron figure) keeps. The Blightstake is a planted
    -- stake that spits something foul, not a ghost.
    blightstake = "lorc/mucous-pillar",

    -- Off the wolf head, which the rank Wolf keeps.
    wolf_alpha = "lorc/wolf-howl",
    -- ...and off BOTH of those, which is the whole reason this row exists: "white_wolf" matches the
    -- "wolf" row in CREATURE_MATCH and would come out pixel-identical to a grunt, while the two icons
    -- that actually read as a great wolf are already spoken for (wolf-howl by the alpha, direwolf by
    -- the Wolfsong Spirit). The teeth are the honest mark anyway -- her blow lands once per wolf
    -- standing with her (weapon_white_wolf_fangs.lua), so what she IS on a board is a count of bites.
    white_wolf = "lorc/bestial-fangs",
    -- "sow" shares no substring with "bear", so she matches nothing in CREATURE_MATCH and lands on the
    -- `beast` KIND fallback -- the wolf grunt's own head. Named here rather than given a row, because she
    -- is ONE body and a "sow" substring row would sweep in whatever is written next. The full animal
    -- rather than a head: she is the only 2x2 bear, and the fight is her bulk arriving.
    sow = "cathelineau/polar-bear",

    -- WHAT IS LEFT OF THE GLUTTONY CIRCLE. Its four creatures are deleted (2026-09-22) and its
    -- lieutenant went with the other six the same day; the apex is what remains. It is a `beast`, so
    -- without a name here it would land on the `beast` KIND fallback, which is the wolf grunt's head. It
    -- wears what it DOES rather than what it is, on the same rule the Hiring Hall's thirty-eight follow.
    --
    -- The seven lieutenants keep their rows below and in the tables that follow. A row is looked up by
    -- id, so a row for a body that is not on disk composes nothing and costs nothing -- and it is the
    -- silhouette an author reaching for that name again would otherwise have to re-pick. The rows are
    -- the_gralloch, the_suppliant, the_tally, second_water, the_anvil, the_late_watch and marginalia.
    the_sated = "delapouite/stomach",      -- what it has eaten IS the silhouette
    the_gralloch = "lorc/meat-hook",       -- named for Gula's tool, and wearing it (body deleted)

    -- THE MERE. Four nagas and a boss, and they are the first faction to hit this table from the
    -- HUMANOID side rather than the creature side: `race = "naga"` rolls up to `kind = "humanoid"`
    -- (data/races/naga.lua), so without a name here each of them would collapse onto its CLASS
    -- silhouette and come out pixel-identical to the plain rogue, fighter and mage. That is the right
    -- fallback for a bandit and exactly wrong for a serpent -- the whole point of the race axis is that
    -- what a body IS and what it DOES are different questions, and this table answers the first.
    --
    -- Each wears what it does, on the rule the Gluttony circle above follows.
    shoalkin = "delapouite/sand-snake",        -- low, quick, and there are several
    fen_lancer = "delapouite/magic-trident",   -- the fen's own spear, reaching out of the water
    tidecaller = "lorc/sea-serpent",           -- the thing in the channel that is calling the weather
    undertow = "delapouite/kraken-tentacle",   -- it does not chase you; it reaches and takes
    nethrys = "delapouite/mermaid",            -- the only one of them with a face worth drawing

    -- THE ENVY CIRCLE. Glass, all of it -- an `elemental`, three `construct`s and the mini sin -- which
    -- without names here would collapse onto two kind fallbacks between them.
    glass_mote = "lorc/crystal-shine",
    glass_eater = "lorc/crystalize",
    mimic_of_ash = "lorc/mirror-mirror",   -- it gives back what was aimed at it
    the_second_self = "lorc/glass-heart",  -- wearing one of yours, and hollow behind it
    the_unwanted = "lorc/crystal-cluster", -- it is already several things
    second_water = "lorc/frozen-orb",      -- the thinner wash, poured off and kept

    -- THE LUST CIRCLE. Both demons, so without names here they would land on one kind fallback and the
    -- alpha would be the chaff drawn larger -- and the two of them are the same bird on purpose, so the
    -- tint and the frame separate them by nothing a player reads at board size. The silhouette is the
    -- only axis left: the flock is a harpy, she is the carrion version of it.
    harpy = "lorc/harpy",
    lamia = "delapouite/cobra",
    elder_lamia = "lorc/snake",        -- the same animal, all of it in frame
    harpy_matriarch = "lorc/vulture", -- the same bird, grown -- an alpha that is not a second animal

    -- THE THIRD ANIMAL, AND IT IS NOT ONE. Three rungs of one line, and the silhouette has to carry the
    -- ladder because the tint and the frame do not: the lesser is a shape with wings, the succubus is
    -- the same shape holding something, and the Abbess is the one the other two are copies of.
    lesser_succubus = "delapouite/bat",
    succubus = "lorc/temptation",
    succubus_abbess = "lorc/angel-wings", -- the rite took CLEANLY: she is what it makes when nothing goes wrong

    -- THE GARDEN (2026-09-23). Three more lines, all `demon`, so every one of them needs a name here or
    -- the whole garden lands on the daemon skull. Each line's ladder reads in its silhouette: the root,
    -- the flower that eats, the one that sits in the church; the small green thing, the tree that walks,
    -- the tree she cannot leave; and the mushroom folk by what each of them does.
    mandrake = "delapouite/beet",                 -- a root with a face, pulled half out of the floor
    alraune = "delapouite/carnivorous-plant",     -- the flower, and what the flower is for
    alraune_anchoress = "lorc/lotus-flower",      -- seated, and never getting up
    nymph = "delapouite/butterfly-flower",
    dryad = "caro-asercion/willow-tree",
    hamadryad = "delapouite/deku-tree",           -- the tree has the face now
    swooncap_puffer = "lorc/mushroom",            -- the plain one; the one that pops
    swooncap_verger = "delapouite/mushroom-house", -- big enough to stand in front of anything
    swooncap_thurifer = "lorc/spotted-mushroom",  -- the one with something coming off it
    sapling = "delapouite/seedling",
    heartwood_tree = "lorc/pine-tree",            -- a yew, as near as the set comes

    -- THE SPIDER LINE (Gluttony). Each its own row: a CREATURE_MATCH on "spider" would seat the spider
    -- and the spiderling on one silhouette, which char_compose_spec refuses.
    giant_spider = "carl-olsen/spider-face",
    the_larder_mother = "skoll/long-legged-spider",
    spiderling = "delapouite/spider-eye",
    larder_husk = "delapouite/spider-bot",        -- the empty skin, still spider-shaped

    -- THE MANTICORE (Gluttony's seat). A man's face on a winged lion is the Greek sphinx's outline
    -- exactly, which is nearer the animal than any lion or wyvern in the set.
    manticore = "delapouite/greek-sphinx",

    -- THE CHIMERA (Gluttony's seat): the lion is the body, and each head wears its own animal -- a head
    -- is drawn only on the turn strip, where it has to be told from the other two at a glance.
    chimera = "lorc/lion",
    chimera_goat = "skoll/goat",
    chimera_serpent = "delapouite/rattlesnake",

    -- THE WYVERNS (Gluttony's seat). Three dragon heads for a two-legged dragon, one per rung -- the
    -- Wyrm already holds the spiked one.
    wyvern = "lorc/dragon-head",
    wyvern_alpha = "faithtoken/dragon-head",
    the_highwing = "lorc/dragon-spiral",

    -- THE SABERTOOTHS (Gluttony's approach). The one cat skull in the set for the pride, and a tiger's
    -- head for the Longfang who leads it.
    sabertooth = "lorc/saber-tooth",
    the_longfang = "delapouite/tiger-head",

    -- ...AND THE THIRD ELEMENTAL THE KEEP MADE. The other two need nothing here and must not get it:
    -- character_fire_elemental and character_wind_elemental carry their element word in the id, so
    -- `elementOf` seats them on ELEMENT_SILHOUETTE and ELEMENT_TINT exactly as it always has -- and
    -- tests/char_compose_spec pins the fire one's flame and its #ef7d4a by name.
    --
    -- The whirl has no element word in it at all, which is correct (an id holding both "fire" and
    -- "wind" would pick between them through `pairs`, and that order is not stable --
    -- [[hash-order-flips-on-a-new-require]]) and leaves it falling to KIND_SILHOUETTE.elemental, which
    -- IS carl-olsen/flame -- pixel-identical to the fire elemental and a straight failure of "no two
    -- characters resolve to the same silhouette". So it is named here, and tinted below.
    whirl_elemental = "lorc/flame-spin", -- the two of them met: a fire with a chimney's worth of air under it

    -- THE WRATH CIRCLE. Two elementals, two demons and a beast, which without names here would collapse
    -- onto three kind fallbacks between them.
    ember_spit = "lorc/small-fire",
    cinder_kin = "lorc/burning-embers",
    forge_wretch = "lorc/flaming-claw",
    the_unquenched = "lorc/fire-breath",   -- it drinks the board and breathes it back
    rift_born = "sbed/lava",               -- the seam, not the thing that came out of it
    the_anvil = "lorc/anvil-impact",       -- a thing that exists to be struck

    -- WHAT IS LEFT OF THE SLOTH CIRCLE. Its four lesser bodies are deleted (2026-09-22); the general's
    -- ground and the mini sin are what remain.
    the_long_winter = "lorc/icicles-fence",   -- the ground it leaves, not the shape it has
    the_late_watch = "lorc/frozen-block",     -- a relief that came too late to be one

    -- THE PRIDE CIRCLE. Four constructs and two humanoids, all of them armour of one sort or another.
    gilded_page = "lorc/armor-vest",
    gilded_sworn = "lorc/visored-helm",
    standard_bearer = "lorc/trophy",       -- it carries the honour, not the weapon
    the_gallery = "lorc/mailed-fist",      -- there is always another suit
    the_peerless = "lorc/spartan",         -- it holds a door, alone, on principle
    marginalia = "lorc/quill-ink",         -- lesser writing beside the real text

    -- WHAT IS LEFT OF THE GREED CIRCLE. Its five bodies are deleted (2026-09-22) and the mini sin is
    -- what remains. The mimic stays: it was the coffer-crawler's cousin that learned to stay still, and
    -- it is keyed by exact id, which keeps it clear of character_mimic_of_ash above -- two unrelated
    -- bodies whose ids share a word.
    mimic = "delapouite/mimic-chest",
    the_tally = "delapouite/war-pick",           -- a record of what is owed, collected

    -- WHAT IS LEFT OF THE LUST CIRCLE. Its five bodies are deleted (2026-09-22) and the mini sin is
    -- what remains.
    the_suppliant = "lorc/fluffy-flame",         -- a bowl held out for a very long time
    wolfsong_spirit = "lorc/direwolf",

    -- THE ROAD'S OWN APEX. A boar lord and the thing wearing him, neither of which any rule above
    -- reaches: "the_unseeing" holds no creature word, so both fell through to the `beast` KIND
    -- fallback and came out pixel-identical to a wolf grunt (the same trap the wyrm hit, two
    -- paragraphs up in CREATURE_MATCH).
    the_unseeing = "lorc/boar-tusks",      -- the lord, not the animal: the ordinary boar keeps `boar`
    the_turning = "lorc/infested-mass",    -- what is wearing him by the end, and it is not a boar

    -- THE FEN'S OOZES. Both are `beast`, so without names here they would land on the wolf grunt's head
    -- together -- and the obvious pick (delapouite/slime) is already the Tallow Hound's, which is the
    -- collision this table exists to catch.
    --
    -- Picked by LEGIBILITY AT TOKEN SIZE, which decided against two closer readings. sbed/slow-blob
    -- would have said the thing the blueprint cares about (slow is its whole balance) and renders as an
    -- amoeba that reads like a cog; cathelineau/transparent-slime is the honest puddle and is outline
    -- only, so it nearly vanishes against the plate at 64px. The daemon is filled, dripping, and
    -- unmistakable across a board -- at the cost of a face on a body whose own file says it has no
    -- plan, which is a trade worth making for a silhouette nobody has to squint at.
    slime = "lorc/gooey-daemon",
    king_slime = "lorc/burst-blob",   -- a blob mid-burst, which is the only thing it does that a
                                      -- common slime does not (data/traits/trait_split.lua) -- and it
                                      -- is faceless, so the pair differ in shape and not only in size
}

-- Reverse index: the character key a discipline names as its `exemplar` -> the discipline id. Built from
-- the discipline blueprints so the mapping lives in one place (data/classes/*.lua) and a repointed
-- exemplar follows automatically. A character that is no discipline's exemplar is simply absent here, and
-- reads by creature/class/kind as before.
local EXEMPLAR_DISCIPLINE = {}
for did, ddef in pairs(Class.defs) do
    if ddef.exemplar then EXEMPLAR_DISCIPLINE[ddef.exemplar] = did end
end

-- The discipline whose exemplar is character `id` (tokenId form, no `character_` prefix), or nil.
local function disciplineFor(id)
    return EXEMPLAR_DISCIPLINE["character_" .. id]
end

-- 1c. Elemental silhouette by element word in the id.
local ELEMENT_SILHOUETTE = {
    fire = "carl-olsen/flame",
    ice = "lorc/snowflake-1",
    lightning = "lorc/lightning-arc",
    earth = "lorc/stone-block",
    water = "sbed/water-drop",
    wind = "lorc/whirlwind",
}

-- 1d. Silhouette by KIND, the last resort once name and class have missed.
local KIND_SILHOUETTE = {
    humanoid = HUMANOID_DEFAULT,
    beast = "lorc/wolf-head",
    elemental = "carl-olsen/flame",
    construct = "delapouite/rock-golem",
    demon = "lorc/daemon-skull",
    undead = "sbed/death-skull",
    object = "delapouite/flag-objective",
}

-- 2. TINT -- element first (shared table with the elementals' silhouette), then a per-kind wash.
local ELEMENT_TINT = {
    fire = "#ef7d4a", ice = "#7fc6ec", lightning = "#f3d24a",
    earth = "#c9a06a", water = "#6fa8d8", wind = "#cfe3d6",
}
local KIND_TINT = {
    humanoid = "#dce1e6", -- steel
    beast = "#c9a06a",
    elemental = "#dce1e6",
    construct = "#b7bcc2",
    demon = "#c07fd0",
    undead = "#9fb8a0",
    object = "#c9b58a",
}
local STEEL = "#dce1e6"

-- 3. BADGE -- the boss/general disc colour. There is no class/kind FRAME any more: a token's border is
-- its runtime side (blue/red), drawn by the board, not the vendor shelf it was bought from. See the
-- header note and ui/battle_map.lua drawUnits.
local BOSS_GOLD = "#e6c14a"

local function projectPath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

-- The element word carried in an id ("fire_elemental" -> "fire"), or nil.
local function elementOf(id)
    for element in pairs(ELEMENT_SILHOUETTE) do
        if id:find(element, 1, true) then return element end
    end
    return nil
end

-- The body KIND: an explicit blueprint override wins; otherwise derived. A `class` says humanoid; the
-- id's own words say the rest. Deliberately coarse -- this only has to pick a silhouette bucket, and a
-- wrong guess is corrected with one `kind =` line rather than art.
local function kindOf(def, id)
    if def.kind then return def.kind end
    if id:find("elemental", 1, true) then return "elemental" end
    if id:find("demon", 1, true) then return "demon" end
    if id:find("golem", 1, true) or id:find("sentry", 1, true) or id:find("totem", 1, true) then
        return "construct"
    end
    if id:find("ghost", 1, true) or id:find("spirit", 1, true) or id:find("zombie", 1, true)
        or id:find("vigil", 1, true) or id:find("blightstake", 1, true) then
        return "undead"
    end
    if id:find("banner", 1, true) or id:find("standard", 1, true) or id:find("straw", 1, true) then
        return "object"
    end
    if def.class then return "humanoid" end
    return "humanoid" -- most portraitless enemies are people; a beast is caught by CREATURE_MATCH above
end

-- The silhouette slug: creature/name match first, then class (humanoid) or element (elemental), then the
-- kind bucket. Mirrors icon-map's "name first, family fallback".
local function slugFor(def, id)
    if id:find("avatar", 1, true) then return AVATAR_SILHOUETTE end
    -- A named body wins over EVERY guess below it: the guesses hand a whole bucket one picture, and this
    -- is where an occupant that is not the bucket's generic head is lifted out. Exact key, no substring.
    if CHARACTER_SILHOUETTE[id] then return CHARACTER_SILHOUETTE[id] end
    -- A discipline's exemplar reads as its DISCIPLINE first of all -- ahead of the creature and class
    -- passes -- so each of the 37 disciplines owns a distinct board body. Keyed off the exemplar pointer,
    -- so it never fires on a lookalike id (a "demon_champion" is not the Champion).
    local disc = disciplineFor(id)
    if disc and DISCIPLINE_SILHOUETTE[disc] then return DISCIPLINE_SILHOUETTE[disc] end
    for _, row in ipairs(CREATURE_MATCH) do
        if id:find(row[1], 1, true) then return row[2] end
    end
    local kind = kindOf(def, id)
    if kind == "humanoid" then
        -- Class wins (a fighter boss still reads fighter); then a classless boss is lifted to the
        -- overlord figure; then the plain rank-and-file swordman.
        if def.class and CLASS_SILHOUETTE[def.class] then return CLASS_SILHOUETTE[def.class] end
        if def.boss then return BOSS_SILHOUETTE end
        return HUMANOID_DEFAULT
    end
    if kind == "elemental" then return ELEMENT_SILHOUETTE[elementOf(id)] or KIND_SILHOUETTE.elemental end
    return KIND_SILHOUETTE[kind] or HUMANOID_DEFAULT
end

-- 2b. TINT by NAMED BODY -- the tint half of CHARACTER_SILHOUETTE above, and it exists for the same
-- reason: a body the element scan cannot read falls to a whole bucket's wash. The Whirl Elemental is
-- the only occupant, and it is a real miss rather than a preference -- it is made of fire and air and
-- its id can name only one of them, so the scan finds neither and it comes out the pale grey every
-- unclassifiable elemental wears. Tinted as the fire it mostly is.
local CHARACTER_TINT = {
    whirl_elemental = "#ef7d4a", -- ELEMENT_TINT.fire: it is a fire with air under it
}

local function tintFor(def, id)
    if CHARACTER_TINT[id] then return CHARACTER_TINT[id] end
    local element = elementOf(id)
    if element and ELEMENT_TINT[element] then return ELEMENT_TINT[element] end
    local kind = kindOf(def, id)
    return KIND_TINT[kind] or STEEL
end

-- The recoloured foreground for one silhouette slug. Both the surgery and the choice of WHICH SET
-- answers the slug live in tools/icon_source.lua -- a commissioned glyph under art/bases/ wins over the
-- vendored game-icons one, so this composer names no source either.
local function foreground(slug, tint)
    local inner, err = Source.foreground(slug, tint)
    if not inner then return nil, err end
    return inner
end

-- 4. SKIN -- a token composed AGAIN, as something that happened to the body.
--
-- The one thing the three channels above cannot say. Base, tint and badge are all facts a blueprint
-- declares once and never changes; a skin is a body's own token drawn as what it has BECOME, and the
-- only thing in the game that does that is the skeleton aspect (data/items/utility/utility_marrowlight.lua).
-- Marrowlight is not a class and not a transform -- your knight is still your knight -- so an anonymous
-- skeleton token would have said the one thing about it that is false. The crossing of "which body" and
-- "what happened to it" is 201 pictures nobody is going to draw, and that is precisely the problem this
-- file exists to solve: the silhouette is kept, the treatment is applied, and a new body costs no art.
--
-- Written as `<token>_<skin>.png` beside every token, which is the contract Character.spriteOf reads --
-- it derives the variant off the blueprint's own `sprite` path and falls back to the plain token when
-- there is no file, so a half-built assets/ costs a skeleton its bone picture and nothing else.
local SKIN = {
    bone = {
        -- Old bone. Warm on purpose, and pitched away from BOTH of its neighbours: the humanoid steel
        -- above it (#dce1e6) is a cold near-white that reads as the SAME token at board size, and the
        -- undead kind wash (#9fb8a0) is a green-grey rot. Those are three different claims -- an
        -- ordinary body, a thing that was raised, and a body that is now a skeleton -- and a player
        -- who meets all three on one board has to tell them apart at a glance, on a 48px tile, without
        -- reading the mark.
        tint = "#d8c49a",
        -- Grave-dark under it: the plate is the one part of the token that is not the body, so darkening
        -- it is how the whole tile reads as changed without touching the silhouette.
        plate = "#12141c",
        -- And the mark. A skull struck in the low corner, diagonally opposite the boss disc, on its own
        -- dark ground so it reads over a busy silhouette. Marks stack by SHAPE, not hue: a boss skeleton
        -- carries a gold circle up here and a skull down there, and neither is the other's colour.
        mark = "sbed/death-skull",
    },
    -- THE SAME BONE, MARKED. A Barrow Lord is a dead knight standing in a room of dead knights, and the
    -- one thing a player must be able to see about him is WHICH ONE HE IS -- his whole fight is that the
    -- two bodies beside him stay down and he does not. Drawn identically he would be a rules quiz.
    --
    -- So the treatment is the bone one plus a crown, and the mark is deliberately the BOSS DISC's
    -- geometry rather than another skull: two marks that stack on one token separate by SHAPE, never by
    -- hue, so a crowned skeleton reads as "that one" at a glance and a crowned skeleton that is also a
    -- boss still reads as both.
    crowned = {
        tint = "#d8c49a",
        plate = "#12141c",
        mark = "lorc/crown",
        markTint = "#e6c14a", -- the boss gold, borrowed on purpose: rank is rank
    },
}

-- Compose the baked layers into one 512x512 SVG. Everything here is a function of `def`/`id` -- plus
-- `skin`, which is a function of the item the body is carrying rather than of the body. No frame is
-- drawn -- the border is the runtime side, added by the board (see the header note).
local function compose(def, id, skin)
    local coat = skin and SKIN[skin]
    local tint = coat and coat.tint or tintFor(def, id)
    local boss = def.boss and true or false

    local inner, err = foreground(slugFor(def, id), tint)
    if not inner then return nil, err end

    local parts = { '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">' }

    -- Backing plate, so the token reads on any tile.
    parts[#parts + 1] = string.format(
        '<rect x="24" y="24" width="464" height="464" rx="72" fill="%s"/>',
        (coat and coat.plate) or "#1b1f25")

    -- The silhouette, tinted, centred at ~64%.
    parts[#parts + 1] = string.format(
        '<g transform="translate(92 92) scale(0.64)" fill="%s">%s</g>', tint, inner)

    -- Badge: a gold disc, top-right, only for a boss/general -- the one baked mark of rank, since the
    -- frame that used to also thicken for a boss is now the runtime side border.
    if boss then
        parts[#parts + 1] = string.format(
            '<circle cx="396" cy="116" r="60" fill="%s" stroke="#12151a" stroke-width="12"/>', BOSS_GOLD)
    end

    -- A skin's MARK, last so it sits over the silhouette rather than under it. Low-left, which is the
    -- corner the boss disc does not use.
    if coat and coat.mark then
        local markTint = coat.markTint or coat.tint
        local glyph = foreground(coat.mark, markTint)
        if glyph then
            parts[#parts + 1] = string.format(
                '<circle cx="124" cy="396" r="80" fill="%s" stroke="#12151a" stroke-width="10"/>',
                (coat and coat.plate) or "#1b1f25")
            parts[#parts + 1] = string.format(
                '<g transform="translate(60 332) scale(0.25)" fill="%s">%s</g>', markTint, glyph)
        end
    end

    parts[#parts + 1] = "</svg>"
    return table.concat(parts)
end

local function ensureDir(rel)
    local built
    for part in rel:gmatch("[^/]+") do
        built = built and (built .. "/" .. part) or part
        if not love.filesystem.getInfo(built) then
            os.execute(string.format('mkdir "%s" 2>nul', projectPath(built):gsub("/", "\\")))
        end
    end
end

local function writeFile(rel, text)
    local file, err = io.open(projectPath(rel), "w")
    if not file then return nil, tostring(err) end
    file:write(text)
    file:close()
    return true
end

-- Rasterize a staged SVG to PNG via resvg (the cmd.exe quoting dance is icon_compose's).
local function rasterize(svgRel, pngRel)
    local cmd = string.format('"%s" "%s" "%s" --width %d --height %d',
        projectPath(RESVG):gsub("/", "\\"),
        projectPath(svgRel):gsub("/", "\\"),
        projectPath(pngRel):gsub("/", "\\"),
        RENDER_SIZE, RENDER_SIZE)
    local ok = os.execute('""' .. cmd:sub(2) .. '"')
    return ok == 0 or ok == true
end

-- The character id a blueprint file yields under Registry.load: the filename key, minus the
-- `character_` prefix. Used for the staging SVG name and the preview gallery filename.
local function tokenId(key)
    return (key:gsub("^character_", ""))
end

function M.run(args)
    if not love.filesystem.getInfo(RESVG) then
        print("resvg not found at " .. RESVG)
        print("run:  powershell -ExecutionPolicy Bypass -File tools\\icons\\fetch.ps1")
        return
    end

    local toAssets, force = false, false
    for _, a in ipairs(args or {}) do
        if a == "assets" then toAssets = true end
        if a == "force" then force = true end
    end

    local defs = Registry.load("data/characters", "data.characters")
    local keys = {}
    for key in pairs(defs) do keys[#keys + 1] = key end
    table.sort(keys)

    ensureDir(toAssets and ASSET_ROOT or PREVIEW_ROOT)
    ensureDir(PREVIEW_ROOT .. "/staging")

    -- In `assets` mode the token must land at the EXACT path the blueprint loads (def.sprite), not at
    -- <id>.png -- several blueprints share one file (demon_bomblet -> demon_imp.png, field_standard ->
    -- march_standard.png), and a token written to <id>.png would be orphaned while the game keeps loading
    -- the shared path and finding nothing. So each distinct def.sprite is composed once, from the first
    -- blueprint (sorted) that names it; a borrower rides along on the owner's token. Preview mode has no
    -- such contract -- it is a gallery -- so it composes every id to its own <id>.png.
    local rendered, skipped, failures, doneTarget = 0, 0, {}, {}
    for _, key in ipairs(keys) do
        local def = defs[key]
        local id = tokenId(key)
        local target = toAssets and def.sprite or (PREVIEW_ROOT .. "/" .. id .. ".png")

        if toAssets and not target then
            -- A body with no sprite path names no file to fill; the board shows its letter token instead.
            skipped = skipped + 1
        elseif toAssets and doneTarget[target] then
            skipped = skipped + 1 -- a shared file already composed by its first namesake this run
        elseif toAssets and not force and love.filesystem.getInfo(target) then
            doneTarget[target] = true
            skipped = skipped + 1 -- real art already on disk; leave it (as icon-build leaves purchased art)
        else
            local svg, err = compose(def, id)
            if not svg then
                failures[#failures + 1] = id .. " -- " .. tostring(err)
            else
                local stageRel = PREVIEW_ROOT .. "/staging/" .. id .. ".svg"
                local wrote, werr = writeFile(stageRel, svg)
                if not wrote then
                    failures[#failures + 1] = id .. " -- cannot stage: " .. tostring(werr)
                elseif rasterize(stageRel, target) then
                    rendered = rendered + 1
                    if toAssets then doneTarget[target] = true end
                    -- ...AND THE SAME BODY IN EVERY SKIN (see SKIN above). Written here rather than in
                    -- a second pass so a variant can never be composed from a token that failed, and so
                    -- the two files are always the same body drawn on the same day.
                    --
                    -- EVERY body, not a chosen few: `wearerSkin` is an item field and the grid is open
                    -- (docs/classes.md -- anyone may carry anything), so the set of bodies that can wear
                    -- the aspect is the roster plus every humanoid in the bestiary plus whatever a
                    -- future scene hands a charm to. Picking a subset here would be a guess that fails
                    -- silently, as a bare letter disc, on the one body nobody thought of.
                    for skinName in pairs(SKIN) do
                        local skinTarget = target:gsub("%.png$", "_" .. skinName .. ".png")
                        if skinTarget == target or doneTarget[skinTarget] then
                            -- nothing: not a .png target, or already written by a shared namesake
                        elseif toAssets and not force and love.filesystem.getInfo(skinTarget) then
                            doneTarget[skinTarget] = true
                            skipped = skipped + 1 -- real art already on disk; leave it, as above
                        else
                            local skinSvg = compose(def, id, skinName)
                            local skinStage = PREVIEW_ROOT .. "/staging/" .. id .. "_" .. skinName .. ".svg"
                            if skinSvg and writeFile(skinStage, skinSvg) and rasterize(skinStage, skinTarget) then
                                rendered = rendered + 1
                                if toAssets then doneTarget[skinTarget] = true end
                            else
                                failures[#failures + 1] = id .. " (" .. skinName .. ") -- compose failed"
                            end
                        end
                    end
                else
                    failures[#failures + 1] = id .. " -- resvg failed"
                end
            end
        end
    end

    -- The avatar's ADDITIONAL bodies. The blueprint names only body 1 (def.sprite = avatar_1.png), so
    -- the loop above never writes avatar_2.png -- yet states/prologue.lua loads it for a body-2 player,
    -- who would otherwise fall back to the bare letter token. Emit every avatar body from the one
    -- blueprint (same figure); assets mode only, since preview already galleried the avatar once.
    if toAssets and defs["character_avatar"] then
        for _, target in ipairs(AVATAR_BODIES) do
            if doneTarget[target] then
                -- body 1 already came through the main loop above; nothing more to do
            elseif not force and love.filesystem.getInfo(target) then
                doneTarget[target] = true
                skipped = skipped + 1 -- real art already on disk; leave it
            else
                local svg = compose(defs["character_avatar"], "avatar")
                local stageRel = PREVIEW_ROOT .. "/staging/" .. target:match("([^/]+)%.png$") .. ".svg"
                if svg and writeFile(stageRel, svg) and rasterize(stageRel, target) then
                    rendered = rendered + 1
                    doneTarget[target] = true
                else
                    failures[#failures + 1] = target .. " -- avatar body compose failed"
                end
            end
        end
    end

    print("")
    print(string.format("  composed %d token(s) into %s/", rendered, toAssets and ASSET_ROOT or PREVIEW_ROOT))
    if toAssets then print(string.format("  skipped  %d (real art on disk, shared file, or no sprite path -- `force` overwrites art)", skipped)) end
    print(string.format("  failed   %d", #failures))
    print("")
    for _, f in ipairs(failures) do print("  fail: " .. f) end
    if not toAssets then
        print("")
        print("  (preview only -- run `. char-compose assets` to publish into assets/chars/)")
    end
end

-- The pure guessing logic, exposed for tests/char_compose_spec.lua. These touch no love API, so the
-- spec exercises the whole "which silhouette/tint does this blueprint resolve to" contract headlessly
-- -- the same way the item pipeline's family/class picks are regression-guarded. The
-- BOSS/HUMANOID/DEFAULT slugs are exposed too so a test names the constant rather than a bare string.
M.kindOf = kindOf
M.slugFor = slugFor
M.tintFor = tintFor
M.elementOf = elementOf
M.tokenId = tokenId
M.disciplineFor = disciplineFor
M.HUMANOID_DEFAULT = HUMANOID_DEFAULT
M.BOSS_SILHOUETTE = BOSS_SILHOUETTE
M.DISCIPLINE_SILHOUETTE = DISCIPLINE_SILHOUETTE
M.CHARACTER_SILHOUETTE = CHARACTER_SILHOUETTE

return M

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
local Discipline = require("models.discipline")
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
    { "dire_bear", "delapouite/bear-head" },
    { "bear", "delapouite/bear-head" },
    -- Before "wolf" only because it must be before the `beast` KIND fallback, which is the wolf's head:
    -- a wyrm matching nothing here fell through to it and came out pixel-identical to a wolf grunt.
    { "wyrm", "delapouite/spiked-dragon-head" },
    { "wolf", "lorc/wolf-head" },
    { "hawk", "lorc/hawk-emblem" },
    { "raven", "lorc/raven" },
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
    -- which is the whole difference between them (data/disciplines/mammonite.lua) -- and neither is
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
-- knight-banner, character_bandit the rank swordman, character_demon_grunt the daemon skull), and every
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

    -- Off the generic mage / alchemist bodies.
    gyeom = "lorc/wizard-staff",
    ren = "lorc/standing-potion",

    -- Off the daemon skull, which the rank Demon Grunt keeps. The horde is a ladder -- bomblet, champion,
    -- lord -- and the ladder should be visible on the board.
    demon_bomblet = "delapouite/inferno-bomb",      -- a demon bred hollow and filled with fire
    demon_champion = "delapouite/devil-mask",
    demon_lord = "caro-asercion/tarot-15-the-devil",

    -- Off the priest's supplicant.
    amana = "cathelineau/nun-face",

    -- THE CAVED COMPANIONS, and they are all aliases on purpose -- the same argument saber_bout makes
    -- above, made seven more times. A caved companion is not a new body: she is the companion the
    -- player spoiled across her own class line, wearing her dead general's relic and fighting for the
    -- Hollow Crown at the Gate (models/temptation.lua). She has to READ as herself, because that is the
    -- entire beat -- the woman who has been at your shoulder for twenty hours is standing on the other
    -- side of the board, and what tells the player is her side and her name, not a costume.
    --
    -- Without these lines each one falls through to its CLASS bucket and collides with that class's
    -- generic template (Rowan's caved form wore character_knight's banner, Clem's the generic rogue's
    -- hood), which is the exact failure the bucket rule exists to prevent -- and it would also be the
    -- wrong picture: a generic knight is the one thing she is not.
    --
    -- They inherit def.sprite from their base too, so both ride one composed file and nothing extra is
    -- rendered for any of them.
    rowan_caved = "cathelineau/swordwoman",
    saber_caved = "lorc/saber-slash",
    amana_caved = "cathelineau/nun-face",
    kaya_caved  = "delapouite/bow-string",
    gyeom_caved = "lorc/wizard-staff",
    clem_caved  = "lorc/cloak-dagger",
    ren_caved   = "lorc/standing-potion",

    -- Off the spectre, which the Gaunt Vigil (a hooded iron figure) keeps. The Blightstake is a planted
    -- stake that spits something foul, not a ghost.
    blightstake = "lorc/mucous-pillar",

    -- Off the wolf head, which the rank Wolf keeps.
    wolf_alpha = "lorc/wolf-howl",
    -- The wild fauna added with the warband pass. Both would otherwise fall into a bucket already
    -- occupied: a carrion crawler matches nothing in CREATURE_MATCH and lands on the `beast` fallback,
    -- which is the wolf grunt's own head; a wyrmling matches "wyrm" and comes out pixel-identical to the
    -- druid's Wyrm. Named here rather than by adding CREATURE_MATCH rows, because both are ONE body
    -- rather than a family and a substring row would sweep in whatever is written next.
    carrion_crawler = "delapouite/grasping-slug", -- low, many-legged, and interested in the floor
    wyrmling = "lorc/dragon-breath",              -- read as the cone, which is the only thing it does

    -- THE GLUTTONY CIRCLE. Five creatures and a mini sin, every one of them `beast` -- so without a name
    -- here all six would land on the `beast` KIND fallback together, which is the wolf grunt's head. Each
    -- wears what it DOES rather than what it is, on the same rule the Hiring Hall's thirty-eight follow.
    gorge_fly = "delapouite/fly",
    bogswallow = "delapouite/swallower",   -- the grip, not the animal: it holds rather than chases
    tallow_hound = "delapouite/slime",     -- rendered down and still walking
    grendlemaw = "lorc/jawbone",           -- it is a mouth with a fen attached
    the_sated = "delapouite/stomach",      -- what it has eaten IS the silhouette
    the_gralloch = "lorc/meat-hook",       -- named for Gula's tool, and wearing it

    -- THE ENVY CIRCLE. Glass, all of it -- an `elemental`, three `construct`s and the mini sin -- which
    -- without names here would collapse onto two kind fallbacks between them.
    glass_mote = "lorc/crystal-shine",
    glass_eater = "lorc/crystalize",
    mimic_of_ash = "lorc/mirror-mirror",   -- it gives back what was aimed at it
    the_second_self = "lorc/glass-heart",  -- wearing one of yours, and hollow behind it
    the_unwanted = "lorc/crystal-cluster", -- it is already several things
    second_water = "lorc/frozen-orb",      -- the thinner wash, poured off and kept

    -- THE WRATH CIRCLE. Two elementals, two demons and a beast, which without names here would collapse
    -- onto three kind fallbacks between them.
    ember_spit = "lorc/small-fire",
    cinder_kin = "lorc/burning-embers",
    forge_wretch = "lorc/flaming-claw",
    the_unquenched = "lorc/fire-breath",   -- it drinks the board and breathes it back
    rift_born = "sbed/lava",               -- the seam, not the thing that came out of it
    the_anvil = "lorc/anvil-impact",       -- a thing that exists to be struck

    -- THE SLOTH CIRCLE. Three elementals, an undead, a beast and a humanoid mini sin.
    rime_gnat = "lorc/ice-cube",
    drift_thing = "delapouite/frozen-body",
    hollow_sleeper = "lorc/hood",             -- somebody who stopped, not weather
    the_winter_hart = "caro-asercion/deer-head",
    the_long_winter = "lorc/icicles-fence",   -- the ground it leaves, not the shape it has
    the_late_watch = "lorc/frozen-block",     -- a relief that came too late to be one

    -- THE PRIDE CIRCLE. Four constructs and two humanoids, all of them armour of one sort or another.
    gilded_page = "lorc/armor-vest",
    gilded_sworn = "lorc/visored-helm",
    standard_bearer = "lorc/trophy",       -- it carries the honour, not the weapon
    the_gallery = "lorc/mailed-fist",      -- there is always another suit
    the_peerless = "lorc/spartan",         -- it holds a door, alone, on principle
    marginalia = "lorc/quill-ink",         -- lesser writing beside the real text

    -- THE GREED CIRCLE. A beast, a construct, two demons, a beast and an object.
    coin_chitter = "delapouite/two-coins",
    coffer_crawler = "delapouite/cave-entrance", -- a shell you have to open
    assayer = "delapouite/gold-stack",           -- it is reading your purse, not you
    the_gilt_wyrm = "lorc/dragon-head",
    the_hoard = "lorc/cash",                     -- it IS the pile
    the_tally = "delapouite/war-pick",           -- a record of what is owed, collected

    -- THE LUST CIRCLE. A beast, an undead and three demons.
    petal_drift = "lorc/three-leaves",
    bloom_wraith = "lorc/haunting",              -- `spectre` is the Gaunt Vigil's; this is the grove's
    chorister = "lorc/love-howl",                -- the call, not the singer
    the_hartwood_bride = "lorc/flowers",
    the_beloved = "lorc/heart-inside",
    the_suppliant = "lorc/fluffy-flame",         -- a bowl held out for a very long time
    wolfsong_spirit = "lorc/direwolf",
}

-- Reverse index: the character key a discipline names as its `exemplar` -> the discipline id. Built from
-- the discipline blueprints so the mapping lives in one place (data/disciplines/*.lua) and a repointed
-- exemplar follows automatically. A character that is no discipline's exemplar is simply absent here, and
-- reads by creature/class/kind as before.
local EXEMPLAR_DISCIPLINE = {}
for did, ddef in pairs(Discipline.defs) do
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

local function tintFor(def, id)
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

-- Compose the baked layers into one 512x512 SVG. Everything here is a function of `def`/`id`. No frame
-- is drawn -- the border is the runtime side, added by the board (see the header note).
local function compose(def, id)
    local tint = tintFor(def, id)
    local boss = def.boss and true or false

    local inner, err = foreground(slugFor(def, id), tint)
    if not inner then return nil, err end

    local parts = { '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">' }

    -- Backing plate, so the token reads on any tile.
    parts[#parts + 1] = '<rect x="24" y="24" width="464" height="464" rx="72" fill="#1b1f25"/>'

    -- The silhouette, tinted, centred at ~64%.
    parts[#parts + 1] = string.format(
        '<g transform="translate(92 92) scale(0.64)" fill="%s">%s</g>', tint, inner)

    -- Badge: a gold disc, top-right, only for a boss/general -- the one baked mark of rank, since the
    -- frame that used to also thicken for a boss is now the runtime side border.
    if boss then
        parts[#parts + 1] = string.format(
            '<circle cx="396" cy="116" r="60" fill="%s" stroke="#12151a" stroke-width="12"/>', BOSS_GOLD)
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

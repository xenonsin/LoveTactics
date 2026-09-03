-- Class growth: the level-up half of the character progression system. Characters do not carry
-- individual XP -- every roster member's level tracks the player's global `prestige` (see
-- Player.syncLevels). What makes two same-level characters differ is HOW you played them: each
-- character banks technique under the class or discipline of every item it casts
-- (Character.recordTechnique, fired from Combat.useItem), and each level-up apportions its stat gains
-- across everything banked since the last one. A knight you keep casting Fireball with grows into a
-- battlemage, in proportion to how much Fireball. Inspired by Fire Emblem growth rates + FFT job
-- emergence, realized through the "anyone can carry anything" gear philosophy (models/item.lua).
--
-- Growth is DETERMINISTIC (fixed per-level gains per class, no RNG) -- prestige-lockstep gives no way
-- to grind away a bad roll, so permanence favors predictability. Gains are BAKED into char.stats
-- (into `.max` for resource stats) and the running total kept in char.growth, so a save that stores
-- only the accumulated delta re-bakes on load without replaying history.
--
-- Blueprints live in data/growth/<class>.lua -- a flat table of per-level stat gains, one file per
-- Item.CLASSES entry. Pure logic (no love.graphics), so it loads under the headless tests.

local Registry = require("models.registry")
local Character = require("models.character")

local Growth = {}

Growth.defs = Registry.load("data/growth", "data.growth")

-- The growth class used when a character has never cast a class-tagged item and declares no innate
-- `class` (a class-less summon, say). Must name a real data/growth/<id>.lua file.
Growth.NEUTRAL_CLASS = "fighter"

-- How fast an ENEMY's output climbs per level. Both of the tables the common enemy stock grows on --
-- fighter (the NEUTRAL_CLASS default) and champion -- carry `damage = 3`, so this is the rate every
-- scaled attacker's swing gains on you.
--
-- It matters because mitigation is SUBTRACTIVE with a floor of 1 (Combat.mitigatedDamage): incoming
-- damage is `blow - defense`, so a class whose pool and armour together grow slower than the blow does
-- gets relatively frailer every level, and is eventually one-shot. That is not a tuning wobble, it is
-- divergence -- it always arrives, the only question is at which level. Before this rule landed, a mage
-- (health +2, no defense growth at all) was one-shot by a champion-table attacker at level 13.
Growth.ENEMY_DAMAGE_GROWTH = 3

-- How closely ordinary enemies track the player's level. Below 1 they lag, and the company sits
-- permanently ahead of the common stock -- which is the only way stat scaling can express "we have
-- grown", because it CANNOT express "we are pulling away".
--
-- That limit is structural, not a tuning failure, and it is worth stating so nobody spends an
-- afternoon looking for the knob: with both sides growing linearly and mitigation subtracting, the
-- exchange converges to a constant. Every lag setting merely picks WHICH constant. Measured against
-- the live combat model, hits an enemy needs to fell a knight:
--
--     player level      1:1      x0.9     x0.8
--          10            8        10       13
--          46            7        10       14
--
-- The one policy that genuinely diverges is a hard ceiling -- stop scaling enemies at level N -- and it
-- diverges catastrophically: once the player's defense passes the frozen blow, damage falls to the
-- floor of 1 and a knight needs 302 hits. That is the original no-scaling bug wearing a hat, so a
-- ceiling is deliberately NOT how this is done.
--
-- 0.9 is a felt edge without free fights. Real growth within a run comes from gear, abilities,
-- disciplines and roster -- the things stat curves cannot flatten.
Growth.ENEMY_LEVEL_LAG = 0.9

-- The survivability a growth table buys per level: pool plus armour, on one damage channel.
-- `magical` reads the magic side (health + magicDefense) instead of the physical one.
function Growth.survivability(def, magical)
    if not def then return 0 end
    return (def.health or 0) + (def[magical and "magicDefense" or "defense"] or 0)
end

-- THE RULE, enforced over every table by tests/growth_spec.lua: a class must gain at least as much
-- survivability per level as a scaled enemy gains attack. Meet it and time-to-kill holds flat at every
-- level and at any LEVEL_CAP; miss it and the class has an expiry date.
--
-- Deliberately a floor, not an equality. A knight buying far more than the minimum is a knight, and the
-- exchange stays stable because the surplus only slows the fight -- it never inverts it.
function Growth.meetsSurvivabilityFloor(def, magical)
    return Growth.survivability(def, magical) >= Growth.ENEMY_DAMAGE_GROWTH
end

-- How fast an ENEMY's ARMOUR climbs per level -- the mirror of ENEMY_DAMAGE_GROWTH above, and the
-- number the rule below is measured against.
--
-- 2 because the commonest stock the player fights is knight-table -- 15 character blueprints declare
-- `class = "knight"`, more than any other -- and that table gains `defense 2` a level. ENEMY_LEVEL_LAG
-- pulls the effective rate to about 1.8; this rounds up, so a class sitting at PARITY gains a little
-- on armour each level rather than precisely tying it.
--
-- This is the parity mark, NOT the enforced minimum -- see LETHALITY_FLOOR.
Growth.ENEMY_ARMOR_GROWTH = 2

-- The enforced minimum: every class must get BETTER at hurting things, however slowly.
--
-- One, not parity, and the gap between the two numbers is a design statement rather than a compromise.
-- A class below parity does fall behind enemy armour on the stat sheet -- a bulwark gaining 1 against
-- armour gaining ~1.8 loses ground every level -- and that is allowed, because stat growth is not the
-- only thing carrying a build. GEAR is, and gear now provably scales: an item's magnitude is held to
-- its archetype's level at the gate that opens it (models/balance.lua, docs/balance.md), so a wall's
-- damage comes from the weapon in its hands and keeps pace whether or not its table does.
--
-- What the floor forbids is a class that can NEVER improve at all. `bulwark` and `sentinel` gained
-- exactly nothing offensively, forever, which is not "a wall that buys damage elsewhere" -- it is a
-- build whose damage converges on the floor of 1 no matter what the player does with it.
Growth.LETHALITY_FLOOR = 1

-- What a growth table buys per level in ATTACK, on whichever channel it actually fights with. Unlike
-- survivability, which must clear on both channels because an enemy may come at you either way, a
-- class needs only ONE way to hurt things: a mage's `damage` is 0 and that is correct, not a gap.
function Growth.lethality(def)
    if not def then return 0 end
    return math.max(def.damage or 0, def.magicDamage or 0)
end

-- THE OFFENSIVE MIRROR OF THE RULE ABOVE, and it was missing for most of this project's life.
--
-- Mitigation is subtractive, so the argument runs identically in both directions. The defensive half
-- was reasoned out: a class whose pool and armour grow slower than the enemy's blow gets relatively
-- frailer every level and is eventually one-shot. The offensive half is the same sentence reflected --
-- a class whose ATTACK grows slower than the enemy's ARMOUR gets relatively weaker every level, and
-- its damage converges on the floor of 1. That is not a tuning wobble either; it is the same
-- divergence, and it always arrives.
--
-- It was arriving. `knight` gained 1 attack a level against knight-stock armour gaining ~1.8, so a
-- player who committed to that one house fell behind by ~0.8 a level for the whole campaign -- and the
-- knight shelf is the sword, spear and mace the starting company is handed. It sits at parity now.
-- `bulwark` and `sentinel` gained NOTHING, ever, and sit at the floor.
--
-- Deliberately a floor, not an equality, exactly as its twin is: a class buying far more attack than
-- the minimum is a striker, and the exchange stays stable because the surplus only shortens the fight
-- rather than inverting it. And deliberately a LOW floor -- a wall is allowed to lose ground on the
-- stat sheet, because its weapon does not (see LETHALITY_FLOOR).
--
-- `mammonite` passes at 1 and would fail a parity bar, correctly: its own table says "a mammonite's
-- output is priced in coin, not in Power -- The Gilded Wound folds none of its bearer's damage stat in
-- at all", so points spent here would buy that build nothing. A growth table can pay for lethality
-- somewhere other than this stat, and the floor is set low enough not to argue with one that does.
function Growth.meetsLethalityFloor(def)
    return Growth.lethality(def) >= Growth.LETHALITY_FLOOR
end

-- A character's ceiling, and how fast prestige walks toward it. Levels are DERIVED from the player's
-- global prestige (Player.syncLevels) rather than earned per character, so without a cap a character's
-- level is just the campaign's prestige total. Prestige is a flat payout per quest completed
-- (Quest.PRESTIGE_PER_QUEST), so a 42-quest campaign totals exactly 84 -- and New Game+ carries it
-- forward (Player.newGamePlus resets only the quest ledger), so a second run reaches 168.
--
-- THOSE TOTALS ARE HELD BY THE PAYOUT, NOT BY THIS FILE. The campaign was 92 quests paying 1 apiece
-- until the retired board took 49 of them; the payout went to 2 so the two numbers this cap is tuned
-- against -- where a campaign ends, and whether a second one reaches the ceiling -- did not move.
--
-- At 2 prestige per level the campaign ends at level 42, comfortably UNDER the cap. That is deliberate:
-- a cap reached before the last quest leaves a dead stretch where finishing a quest grants nothing,
-- which is exactly what a cap should avoid. The remaining levels are headroom New Game+ grows into, so
-- the ceiling does its real job -- bounding a prestige total that otherwise never stops -- without ever
-- being felt as a wall on a first playthrough.
--
-- 2, not 3, because the payout flattened. The campaign used to pay 138 prestige over 92 quests (1, 2 or
-- 3 apiece, back-loaded) and 3-per-level landed level 46. Flat payouts pay a round number, so holding 3
-- would have quietly ended the campaign a dozen levels short; 2 reproduces the old endpoint. What
-- changed is not the destination but the REGULARITY -- a level at a fixed number of quests, always,
-- instead of scattered wherever the authored weights happened to cross a threshold.
--
-- At 42 quests paying 2 apiece that cadence is a level EVERY quest, where it was every second quest at
-- 92 paying 1. The regularity is the property being held, not the interval: a campaign half as long
-- whose every stop advances the company is the same promise kept at the new length.
Growth.LEVEL_CAP = 50
Growth.PRESTIGE_PER_LEVEL = 2

-- The level a character sits at for a given global prestige. The single owner of that mapping: the
-- roster, enemy scaling (states/battle.lua), and the advancement bar all read levels through here, so
-- there is one curve to retune rather than three.
function Growth.levelForPrestige(prestige)
    local raw = 1 + math.floor(((prestige or 1) - 1) / Growth.PRESTIGE_PER_LEVEL)
    return math.max(1, math.min(Growth.LEVEL_CAP, raw))
end

-- Prestige still owed before the next level lands, and how far into the current step we are -- what the
-- post-quest advancement bar fills (ui/panels/advancement.lua). Returns `into, span` where `into` is
-- 0..span-1, or nil at the cap, which has no next level to fill toward and must not render as a bar
-- frozen just short of full.
function Growth.prestigeIntoLevel(prestige)
    if Growth.levelForPrestige(prestige) >= Growth.LEVEL_CAP then return nil end
    return ((prestige or 1) - 1) % Growth.PRESTIGE_PER_LEVEL, Growth.PRESTIGE_PER_LEVEL
end

-- ---------------------------------------------------------------------------
-- Enemy scaling
-- ---------------------------------------------------------------------------

-- The level a combatant the player did not bring fights at. Enemies and escorted allies are minted
-- from blueprints and grown through the SAME tables the roster uses -- an enemy knight at level 12 is
-- computed exactly like a player knight at level 12 -- so there is no second balance surface to keep
-- in sync. Without this they stayed at blueprint level 1 forever while the roster climbed, which is
-- what let a demon grunt fall to the 1-damage floor against a knight by prestige 9.
--
-- A FLOOR is authored, and scaling takes over above it. Two independent floors, because they say
-- different things:
--
--   `def.floorLevel` on a blueprint   this CREATURE is never weaker than this, wherever it turns up.
--                                     A champion that reads as a wall early keeps that identity in
--                                     every encounter, without each quest having to remember to say so.
--   `battleFloor` on a fight          this FIGHT is never easier than this, whoever walks into it.
--                                     Keeps a story beat from being walked on a replay or in New Game+.
--
-- Whichever of the two floors and the player's tracked level is highest wins. Clamped to LEVEL_CAP so
-- everything stays inside the range the survivability floor above is verified over.
--
-- `scaling = false` opts out entirely -- no floor, no climb, blueprint-exact. Reserved for units whose
-- precise arithmetic is load-bearing rather than merely tuned (the prologue's grunt, whose claw maths
-- the parry lesson is built on).
function Growth.combatantLevel(def, playerLevel, battleFloor)
    if def and def.scaling == false then return 1 end

    -- Ordinary stock lags; anything that declares a floor of its own is a NAMED thing -- an elite, a
    -- boss, a fight's centrepiece -- and tracks the player exactly. That split is the whole reason the
    -- lag is safe to have: the trash becomes a victory lap and the named fight is still a fight.
    local tracked = playerLevel or 1
    if not (def and def.floorLevel) then
        tracked = 1 + math.floor(Growth.ENEMY_LEVEL_LAG * (tracked - 1))
    end

    local level = math.max((def and def.floorLevel) or 1, battleFloor or 1, tracked)
    return math.max(1, math.min(Growth.LEVEL_CAP, level))
end

-- Mint a combatant already grown to the level this fight puts it at. The counterpart to
-- Character.instantiate for everyone who is not on the player's roster.
-- WHAT A BOSS IS AUTHORED AT. A named centrepiece is written as the fight it is at the END of its
-- line -- Gula is 240 health, 20 damage and 15 defense because that is what she is at the bottom of
-- the Hunter's Lodge, at level thirteen.
--
-- The per-level blend below cannot express that shape. It adds what a CLASS gains a level (four health
-- for her house), which is right for the bodies it was built for and hopeless for a boss: measured,
-- the seven generals move 240 -> 288 across twelve levels while a party member moves 70 -> 142. Flat
-- against a company that doubles. That was survivable while each general appeared exactly once, at
-- slot ten, at the level they were written for.
--
-- The descent broke that. The circles are dealt in a fresh order every run, so the SAME general has to
-- be a fair fight on floor 1 and on floor 7 -- and on floor 1 a level-1 company cannot scratch fifteen
-- defense, let alone chew 240 health. Not hard: arithmetically impossible, because mitigation is
-- subtractive.
--
-- So such a body scales MULTIPLICATIVELY toward its reference level instead of additively away from
-- base. The authored numbers stay the numbers at the level they were authored for -- the campaign's own
-- capstone fights are untouched, and so is the deepest floor of a descent -- and everything shallower
-- reads as a younger, smaller version of the same thing.
--
-- OPTED INTO BY BLUEPRINT, through `referenceLevel`, and NOT off `boss`. That was the first attempt and
-- it was wrong: `boss` means "immune to execute and to Charm" here, and thirty-nine bodies carry it
-- including every companion -- so keying the curve to it rescaled half the bestiary and broke
-- balance_spec's threat and time-to-kill bands on bodies that were never set-pieces. A field that says
-- WHAT LEVEL THE NUMBERS WERE WRITTEN FOR is also the more honest thing to write down than a boolean:
-- a body authored for a different depth can simply say so.
Growth.BOSS_REFERENCE_LEVEL = 13 -- what a body means by `referenceLevel = true`-ish authoring; the default

-- What a boss keeps at level 1, as a share of its authored self -- and it is TWO shares, because
-- mitigation here is subtractive and the two sides of a fight do not answer a multiplier the same way.
--
-- Measured with one share of 0.4 on everything: the party dropped every boss in three or four rounds
-- at every depth (right), and every boss needed SEVENTY hits to drop a party member on floor 1
-- (useless). Cutting a 20-damage blow to 8 does not remove 60% of it, it removes almost all of it,
-- because the coat it lands on subtracts first -- eight against a starting company's armour is a
-- scratch. Durability scales; the blow barely can.
--
-- So the shallow boss is a smaller, thinner version of itself that still hits like the thing it is.
-- That is also the right read of what a younger Gula would be: less of her, not gentler.
Growth.BOSS_FLOOR_SHARE = 0.4      -- health, and what it hides behind
Growth.BOSS_FLOOR_SHARE_HIT = 0.75 -- ...and what it swings, which cannot be cut nearly as far

-- Which stats a boss curve touches: the POWER ones, split by which side of the exchange they sit on.
-- Movement, speed and the resource pools are the body's tactical shape rather than its strength, and
-- scaling them would make a shallow boss slow and spell-less -- a different creature, not a younger one.
local BOSS_DURABILITY = { "health", "defense", "magicDefense" }
local BOSS_OFFENCE = { "damage", "magicDamage" }

local function shareAt(level, floorShare, ref)
    ref = ref or Growth.BOSS_REFERENCE_LEVEL
    if (level or 1) >= ref then return 1 end
    local t = ((level or 1) - 1) / math.max(1, ref - 1)
    return floorShare + (1 - floorShare) * t
end

function Growth.bossShare(level, ref) return shareAt(level, Growth.BOSS_FLOOR_SHARE, ref) end
function Growth.bossHitShare(level, ref) return shareAt(level, Growth.BOSS_FLOOR_SHARE_HIT, ref) end

-- THE CLASS LEVEL A SPAWNED BODY FIGHTS AT, on the same 0..CLASS_LEVEL_CAP ladder a player's bodies
-- climb (Discipline.classLevel), spread across the whole level range.
--
-- WHY AN ENEMY NEEDS ONE AT ALL. A class level scales what an item does for the body holding it
-- (Combat.classScaled). Left at nought, every enemy in the game would swing at the item's authored
-- magnitude forever while a committed player body swung at the top of the span -- so the scalar would
-- be a player-only power gain across the entire bestiary, and every ratio docs/balance.md is measured
-- against would move at once.
--
-- IT IS DERIVED FROM THE LEVEL THIS BODY WAS ALREADY GOING TO FIGHT AT, which is the whole of why this
-- is safe. Growth.combatantLevel already blends the fight's floor, the body's own declared floorLevel
-- and the player's level under ENEMY_LEVEL_LAG; reading the class level off its result introduces no
-- new dependency on the party and inherits the lag, so ordinary stock still trails the company here
-- exactly as it trails it everywhere else.
--
-- STAMPED AS CAREER TECHNIQUE rather than as a class level of its own, so there is ONE ledger and one
-- reader. A second field saying "this body is Knight 5" could disagree with the technique that is
-- supposed to mean the same thing, and Discipline.classLevel would have to choose between them.
local function stampClassLevel(char, level)
    local Discipline = require("models.discipline")
    local key = Growth.jobOf(char)
    local span = math.max(1, Growth.LEVEL_CAP - 1)
    local n = math.floor(Discipline.CLASS_LEVEL_CAP * math.max(0, (level or 1) - 1) / span + 0.5)
    char.technique = char.technique or {}
    local earned = Discipline.classLevelCost(n)
    if earned > (char.technique[key] or 0) then char.technique[key] = earned end
end

function Growth.spawn(id, playerLevel, battleFloor)
    local def = Character.defs[id]
    local char = Character.instantiate(id)
    local level = Growth.combatantLevel(def, playerLevel, battleFloor)
    Growth.resolve(char, level)
    stampClassLevel(char, level)

    -- Applied AFTER the blend, so a boss still gains what its levels gave it and the curve is a scale
    -- over the result rather than a replacement for it.
    local ref = def and def.referenceLevel
    if ref and level < ref then
        local function scale(stats, share)
            for _, stat in ipairs(stats) do
                local value = char.stats[stat]
                if type(value) == "table" then
                    -- A resource pool: scale the ceiling and open full, exactly as instantiate left it.
                    value.max = math.max(1, math.floor((value.max or 0) * share))
                    value.current = value.max
                elseif type(value) == "number" then
                    char.stats[stat] = math.max(0, math.floor(value * share))
                end
            end
        end
        scale(BOSS_DURABILITY, Growth.bossShare(level, ref))
        scale(BOSS_OFFENCE, Growth.bossHitShare(level, ref))
    end
    return char
end

local function isResourceStat(name)
    for _, stat in ipairs(Character.RESOURCE_STATS) do
        if stat == name then return true end
    end
    return false
end

-- Every key in `tally` holding a positive amount, SORTED. Sorted because what follows sums floats over
-- them, and float addition is not associative: `pairs()` order holds still within one build and is
-- promised by nothing across two, so an unsorted sum is the same character with different stats on
-- another machine. models/build.lua promises `(id, tally, level)` rebuilds identically anywhere and
-- models/state_hash.lua compares peers mid-duel, so that is a real failure, not a theoretical one.
local function sortedKeys(tally)
    local keys = {}
    for key, amount in pairs(tally or {}) do
        if (amount or 0) > 0 then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys
end

-- The class leading a usage tally, with `innate` (the blueprint's own class) as both tie-breaker and
-- fallback. Shared by the readings below so they can never drift apart in how they settle a tie.
-- THE JOB A BODY IS DECLARED IN, which is the one thing that decides how it grows.
--
-- IT USED TO BE A TALLY OF WHAT THE BODY HAD SWUNG. A level was apportioned across every house cast
-- since the last one (Growth.shares) and baked as a blend, with the fractions carried in
-- char.growthCarry until they added up to a point. That machinery is gone, and the argument that
-- retired it is worth keeping: a body that grows by what it happened to hold has no answer to "what is
-- she", and the answer to that question is exactly what a job system is for. Declaring it makes growth
-- a decision rather than a readout of one.
--
-- WHAT DID NOT MOVE WITH IT is the class LEVEL (Discipline.classLevel), which still follows the items
-- actually used -- Combat.awardTechnique banks against the class of the thing in the hand. The two
-- readings are deliberately different questions: the badge says how this body grows, the hands say what
-- it has got good at. A body declared knight while casting mage gear takes knight growth and mage class
-- levels, and holds both.
--
-- Falls back to the innate class, then to NEUTRAL_CLASS, so an enemy minted by Growth.spawn with no
-- declaration at all grows exactly as it did before.
-- Each candidate is tried in turn rather than being coalesced into one lookup: a declared job whose id
-- has gone stale under a rename must fall through to the innate class, not past it to the neutral
-- default. Coalescing first and checking once looked identical and quietly demoted every body whose
-- declaration had drifted.
function Growth.jobOf(char)
    if char then
        if char.job and Growth.defs[char.job] then return char.job end
        if char.class and Growth.defs[char.class] then return char.class end
    end
    return Growth.NEUTRAL_CLASS
end

-- Bake `gains` (whole points, per stat) into `char`: add to the running total (char.growth) and to the
-- live stat -- the resource `.max` for health/mana/stamina, the number itself for everything else.
local function bake(char, gains)
    char.growth = char.growth or {}
    for stat, amount in pairs(gains) do
        char.growth[stat] = (char.growth[stat] or 0) + amount

        local live = char.stats and char.stats[stat]
        if type(live) == "table" and isResourceStat(stat) then
            -- Resource pool: raise the ceiling. `current` is refilled to max on hub entry
            -- (Player.restore), so nudging it up here keeps a just-leveled unit from reading as hurt.
            live.max = live.max + amount
            live.current = math.min((live.current or live.max) + amount, live.max)
        elseif type(live) == "number" then
            char.stats[stat] = live + amount
        end
    end
end

-- Apply one level's worth of `class` growth to `char`, whole and undiluted. The single-class path,
-- kept for callers that mean exactly one table. Returns the per-stat gains applied; unknown class is a
-- no-op.
function Growth.applyLevel(char, class)
    local def = Growth.defs[class]
    if not def then return {} end

    local gains = {}
    for stat, amount in pairs(def) do gains[stat] = amount end
    bake(char, gains)
    return gains
end

-- What the next level would add, per stat, if it landed right now -- `{ health = 2, damage = 1 }`.
-- The character sheet's forecast (ui/panels/party.lua), answering what the declared job on the line
-- above it actually buys.
--
-- Side-effect-free, so a panel may call it every frame, and it is not an ESTIMATE of the coming level:
-- it reads the same table Growth.resolve will apply, so the forecast cannot drift from the outcome.
--
-- THE CARRY IS GONE WITH THE BLEND. A share-weighted sum of several tables produced fractions, so a
-- remainder had to ride in char.growthCarry until it added up to a point -- which is why a forecast
-- could legitimately differ between two levels that grew identically. One table of whole numbers has no
-- remainder to carry, so the forecast is now the same every level and says so.
function Growth.previewLevel(char)
    if not char then return {} end
    local gains = {}
    for stat, amount in pairs(Growth.defs[Growth.jobOf(char)] or {}) do gains[stat] = amount end
    return gains
end
-- Catch `char` up to `targetLevel`. Idempotent: never runs backward, so calling it again at the same
-- level does nothing. Returns { fromLevel, toLevel, class, levels, gains } when the character actually
-- advanced, or nil when it was already caught up. `class` is the job the growth was taken from, which
-- is now the job the body is DECLARED in rather than a reading of what it swung.
--
-- WHAT THIS USED TO DO, because the shape of the function still carries the marks. A level was
-- apportioned across everything cast since the last one and baked as a share-weighted blend, with the
-- remainder carried in char.growthCarry and a per-key ledger of credited levels written to
-- char.growthBy. All three are retired: the blend because growth is a declaration now (Growth.jobOf),
-- and growthBy because the class level it fed is read off cumulative technique instead
-- (Discipline.classLevel), which is one ledger where there were two that could disagree.
--
-- Levels already credited are still never revisited, so a stat can only ever go UP. That mattered more
-- under the blend -- re-apportioning history against a changed reading could have taken max health off
-- a body that switched direction -- and it holds here for the same reason: a player who re-declares a
-- job keeps everything the old one grew.
--
-- The technique checkpoint stays. It is no longer what growth reads, but it is what the battle summary
-- reports a level against (Character.techniqueSinceLevel), and it is a SNAPSHOT rather than a wipe:
-- the ledger is also the wallet and the class level, so clearing it would pay for a level by deleting
-- money and history.
--
-- A multi-level jump (a roster catching up on load) applies the job's table once PER LEVEL rather than
-- as one batch, so three levels at once land exactly where three separate levels would.
function Growth.resolve(char, targetLevel)
    char.level = char.level or 1
    if char.level >= targetLevel then return nil end

    local fromLevel = char.level
    local class = Growth.jobOf(char)

    -- Checkpoint: from here on the level-up reading is the delta above these amounts.
    char.techniqueAtLevel = char.techniqueAtLevel or {}
    for key, amount in pairs(char.technique or {}) do
        char.techniqueAtLevel[key] = amount
    end

    local totalGains = {}
    while char.level < targetLevel do
        char.level = char.level + 1
        for stat, amount in pairs(Growth.applyLevel(char, class)) do
            totalGains[stat] = (totalGains[stat] or 0) + amount
        end
    end

    return { char = char, fromLevel = fromLevel, toLevel = char.level, class = class,
             levels = char.level - fromLevel, gains = totalGains }
end

return Growth

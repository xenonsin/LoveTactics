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

function Growth.spawn(id, playerLevel, battleFloor)
    local def = Character.defs[id]
    local char = Character.instantiate(id)
    local level = Growth.combatantLevel(def, playerLevel, battleFloor)
    Growth.resolve(char, level)

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
local function leaderOf(tally, innate)
    local best, bestCount = nil, 0
    for class, count in pairs(tally or {}) do
        -- A tie settles by name. The innate class breaks a genuine tie below, but only when it is
        -- itself one of the leaders -- two OTHER classes level with each other leave that check
        -- unfired, and "first-seen" over pairs() is not an answer: the order holds still within one
        -- build and is promised by nothing across two. This picks the growth table a level-up
        -- applies, so an unstable reading is the same character with different stats on another
        -- machine, which is also how a normalized duel roster would fail to agree with itself.
        if count > bestCount or (count == bestCount and best and class < best) then
            best, bestCount = class, count
        end
    end
    -- A tie (or no casts): prefer the character's own innate class if it is itself among the leaders,
    -- otherwise use it as the declared fallback.
    if innate and (tally or {})[innate] == bestCount then
        best = innate
    end
    return best or innate or Growth.NEUTRAL_CLASS
end

-- What this character IS, over its whole career: the most-earned key across the cumulative ledger.
--
-- NOT PLAYER-FACING any more. This was the character sheet's title, and it read "Growing as Hunter"
-- directly above a column showing the delta since the last level-up -- two true statements about two
-- different windows of time, with nothing on screen to say which was which. The sheet names the present
-- now (Growth.creditClass, via Party.growthShares) and the career leader is shown nowhere, because no
-- decision reads it. What survives is models/save.lua, which needs a single key to attribute the levels
-- of a save written before per-class crediting existed; migration is exactly the job winner-take-all
-- over a career ledger is still right for.
function Growth.dominantClass(char)
    return leaderOf(char.technique, char.class)
end

-- What this character has earned toward its next level, per key: the delta since the last level-up
-- (Character.techniqueSinceLevel). Reading the cumulative ledger here instead would price a change of
-- direction against the character's entire history -- a veteran taking up a new discipline would have
-- to out-cast everything it had ever done before one level followed it, so experimenting would get
-- steadily more expensive the longer a character survived. Against the recent reading the cost of
-- turning is constant: one level's worth of casting buys one level, at level 3 or level 40 alike.
function Growth.sinceLevel(char)
    local since = {}
    for _, key in ipairs(sortedKeys(char and char.technique)) do
        local delta = Character.techniqueSinceLevel(char, key)
        if delta > 0 then since[key] = delta end
    end
    return since
end

-- The single key leading that reading. Kept as the HEADLINE for a level-up summary ("as Knight") and
-- for the growthBy ledger's fallback; the stats themselves are blended, not credited to it.
function Growth.creditClass(char)
    return leaderOf(Growth.sinceLevel(char), char.class)
end

-- How one level's growth is apportioned: `{ [key] = share }` summing to 1 over what this character has
-- been casting since it last levelled.
--
-- THIS REPLACES WINNER-TAKE-ALL. A level used to be credited entirely to the leader and the rest of the
-- reading discarded, so casting knight 11 and mage 10 threw away all ten mage casts -- 51% of the play
-- deciding 100% of the level, with no gradient anywhere: every cast worthless except the one that
-- crossed the threshold. Now every cast moves the blend, which is also what makes the number on the
-- character sheet mean something. It used to be purely ordinal (only `count > bestCount` was ever
-- read), so "Knight 14" meant "more than 11" and nothing else.
--
-- Falls back to the innate class at share 1.0 when nothing has been cast -- the same fallback chain
-- leaderOf uses (innate, else NEUTRAL_CLASS), so an enemy minted by Growth.spawn with no ledger at all
-- grows exactly as it did before.
function Growth.shares(char)
    local since = Growth.sinceLevel(char)
    local keys = sortedKeys(since)

    local total = 0
    for _, key in ipairs(keys) do total = total + since[key] end
    if total <= 0 then
        return { [leaderOf(nil, char and char.class)] = 1 }, 1
    end

    local shares = {}
    for _, key in ipairs(keys) do shares[key] = since[key] / total end
    return shares, total
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

-- One level of blended growth as `gains, carry`: the whole points each stat takes, and the fractional
-- remainder left over. Each stat is the share-weighted sum across the class tables added to whatever
-- was already carried, and whatever does not come out whole is CARRIED rather than rounded away. Over a
-- career the carry pays out in full, so a 50/50 knight/mage is exactly half of each table's total and
-- not a rounding artefact of either.
--
-- Whole numbers at every step because the stats they bake into are integers and a save stores the
-- accumulated delta (see the module header). Carrying rather than rounding is what lets the shares be
-- fractional without the stats ever being.
--
-- PURE: it writes to neither argument, and that is load-bearing rather than tidiness. The character
-- sheet forecasts the coming level every frame it is open (Growth.previewLevel), so this arithmetic is
-- run far more often to ASK than to apply -- a version that banked its remainder as it went would
-- advance a character by looking at them. It is also why the forecast cannot drift from the outcome:
-- there is one implementation, not a preview beside it.
local function blendGains(shares, carry)
    -- Sorted, for the reason sortedKeys exists: this sums floats.
    local keys = {}
    for key in pairs(shares or {}) do keys[#keys + 1] = key end
    table.sort(keys)

    local pending = {}
    for stat, amount in pairs(carry or {}) do pending[stat] = amount end
    for _, key in ipairs(keys) do
        local def = Growth.defs[key]
        if def then
            local share = shares[key]
            for stat, amount in pairs(def) do
                pending[stat] = (pending[stat] or 0) + amount * share
            end
        end
    end

    -- Spend the whole part, keep the remainder. A stat whose whole part is zero keeps its whole
    -- accumulation, which is the same statement -- `amount - 0` -- and is why one branch covers both.
    local gains, rest = {}, {}
    for stat, amount in pairs(pending) do
        local whole = math.floor(amount)
        if whole ~= 0 then gains[stat] = whole end
        rest[stat] = amount - whole
    end
    return gains, rest
end

-- Apply one level's worth of blended growth to `char`, banking the remainder in char.growthCarry.
--
-- The survivability floor needs no separate defence here: survivability is LINEAR in a growth table
-- (Growth.survivability sums two of its fields), so a convex combination of tables that each clear
-- Growth.meetsSurvivabilityFloor clears it too. Blending cannot reopen the hole that rule closes.
function Growth.applyLevelBlend(char, shares)
    local gains, carry = blendGains(shares, char.growthCarry)
    char.growthCarry = carry
    bake(char, gains)
    return gains
end

-- What the next level would add, per stat, if it landed right now -- `{ health = 2, damage = 1 }`, and
-- only the stats actually taking a whole point. The character sheet's forecast (ui/panels/party.lua),
-- answering the question the percentages beside it raise but cannot settle: 33% Alchemist of WHAT.
--
-- Side-effect-free, so a panel may call it every frame. It reads the same shares and the same carry
-- through the same arithmetic Growth.resolve will use, so this is not an estimate of the coming level;
-- it is the coming level, computed early.
--
-- HONEST ABOUT THE CARRY, which is the whole reason this cannot be eyeballed off a growth table. A stat
-- earning 0.5 a level arrives as +1 every OTHER level, so a forecast that ignored the remainder would
-- promise a point that is not coming this time and then look broken when it failed to land. It also
-- means the forecast legitimately CHANGES between two levels that grew identically -- that is the carry
-- becoming visible, which is the first time it ever has been.
--
-- Nothing cast since the last level still forecasts a level: one arrives on prestige regardless, and
-- Growth.shares answers the innate class at 1.0 for exactly that case. The sheet drops its "growing as"
-- clause there (it would be a claim the player did not earn) but the stat gains are real and shown.
function Growth.previewLevel(char)
    if not char then return {} end
    local gains = blendGains(Growth.shares(char), char.growthCarry)
    return gains
end

-- Catch `char` up to `targetLevel`. Idempotent: never runs backward, so calling it again at the same
-- level does nothing. Returns { fromLevel, toLevel, class, shares, levels, gains } when the character
-- actually advanced, or nil when it was already caught up. `class` is the headline (the leading key);
-- `shares` is how the gains were actually apportioned.
--
-- The advance is apportioned across EVERYTHING cast since the last level (Growth.shares), and the
-- reading is then checkpointed, so the next level measures from here rather than from zero. Three
-- consequences worth knowing:
--
--   * Every cast moves the result. The old rule credited the whole level to the leader and discarded
--     the rest, so there was no gradient anywhere -- only the cast that crossed the threshold mattered,
--     and 51% of the play decided 100% of the level.
--   * A blend emerges WITHIN a level, not merely across a career, and still in whole numbers: the
--     fractions ride in char.growthCarry until they add up to a point (Growth.applyLevelBlend).
--   * Levels already credited are never revisited, so a stat can only ever go UP. Re-apportioning
--     history against the current reading would be the alternative, and it would mean a character that
--     changed direction could LOSE max health on a level-up -- unshippable.
--
-- The checkpoint is a SNAPSHOT of the ledger, not a wipe of it. The ledger is also the wallet and the
-- career title now (Character.recordTechnique), so clearing it would pay for a level by deleting money
-- and history; "consumed" is expressed as "the delta is measured from here".
--
-- A multi-level jump (a quest paying several prestige, a roster catching up on load) applies the same
-- share vector once PER LEVEL rather than as one batch, so the carry accumulates level by level and
-- three levels at once land exactly where three separate levels would.
function Growth.resolve(char, targetLevel)
    char.level = char.level or 1
    if char.level >= targetLevel then return nil end

    local fromLevel = char.level
    local since = Growth.sinceLevel(char)
    local shares = Growth.shares(char)
    local class = leaderOf(since, char.class) -- the headline for a level-up summary

    -- Checkpoint: from here on the level-up reading is the delta above these amounts.
    char.techniqueAtLevel = char.techniqueAtLevel or {}
    for key, amount in pairs(char.technique or {}) do
        char.techniqueAtLevel[key] = amount
    end

    local totalGains = {}
    while char.level < targetLevel do
        char.level = char.level + 1
        for stat, amount in pairs(Growth.applyLevelBlend(char, shares)) do
            totalGains[stat] = (totalGains[stat] or 0) + amount
        end
    end

    -- The per-key ledger of levels credited: monotonic, and the only record of HOW a character was
    -- built rather than merely how far. Credited in SHARES, so a level split 52/48 books 0.52 and 0.48
    -- instead of booking the whole level to the winner -- which keeps this ledger agreeing with the
    -- stats it summarizes. Discipline.level floors it for the shelf gate.
    local levels = char.level - fromLevel
    char.growthBy = char.growthBy or {}
    for key, share in pairs(shares) do
        char.growthBy[key] = (char.growthBy[key] or 0) + share * levels
    end

    return { char = char, fromLevel = fromLevel, toLevel = char.level, class = class,
             shares = shares, levels = levels, gains = totalGains }
end

return Growth

-- Tests for the bestiary contract (docs/bestiary.md): the ladder every body stands on, and the rule
-- that decides which bodies carry a shelf.
--
-- Both fields this pins are DECLARED LABELS, not multipliers -- nothing in the engine derives a stat
-- from either, and that is deliberate (docs/bestiary.md, "the ladder already in the data"). A tier that
-- generated numbers would quietly break the beats each blueprint's header spends twenty lines
-- defending. What the labels buy is exactly this file: a body that drifts out of the band it claims,
-- or an Elite that claims a discipline and carries none of it, fails the build instead of being found
-- by the next person to read the folder.
--
-- The rule underneath the whole thing:
--
--   > Bodied chaff -- humans and humanoids -- carry priced, lootable, shareable gear.
--   > Creature chaff -- beasts, summons, constructs -- carry natural weapons only, and NEVER a
--   > discipline item. A wolf is not a Beastmaster; a wolf is what a Beastmaster has.
--
-- Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Class = require("models.class")
local Item = require("models.item")

local tests = {}

-- The body kinds a blueprint may declare. `humanoid` is the one that carries a shelf; everything else
-- is a creature, a machine or a prop, and the item rules below split on exactly that line.
local KINDS = {
    humanoid = true, beast = true, demon = true, undead = true,
    construct = true, elemental = true, object = true,
}

-- The rungs, and the health band each one claims. Widened from the prose bands in docs/bestiary.md,
-- which were written off a sort of the folder and left real gaps between them (there was nothing
-- covering 31-37, 71-83 or 116-154, and bodies live in all three). These are contiguous, so every
-- health value has exactly one legal rung and the assertion below is a real constraint rather than a
-- band a body can fall between.
--
-- Rung 0 is not on the ladder at all: a prop, an escortee, or a shape worn by Wild Shape. It is
-- DECLARED rather than absent so that "this body does not fight" and "nobody has labelled this body"
-- stay different states -- a new blueprint that forgets the field fails, a plank that will never fight
-- says so in one line.
-- MOVED to models/balance.lua as Balance.HEALTH_BANDS, and read from there. The rescale pass
-- (tools/balance_rescale.lua) moves health to land a body inside its time-to-kill band, and a tool
-- that could not see this contract would break it -- as it did, cutting a tier-3 captain to 58 health
-- and clean through the 81 floor, turning this suite red while the balance suite went green. One
-- owner, so the two cannot disagree. The contract is still stated here, in the assertion below.
local BANDS = require("models.balance").HEALTH_BANDS

-- Every item id in a blueprint's starting grid. Entries may be an id, a { id, count } stack, or
-- false/nil for an empty cell.
local function kitOf(def)
    local out = {}
    for _, entry in ipairs(def.startingItems or {}) do
        if type(entry) == "string" then out[#out + 1] = entry
        elseif type(entry) == "table" and entry.id then out[#out + 1] = entry.id end
    end
    return out
end

tests[#tests + 1] = { name = "every character declares a real kind", fn = function()
    for id, def in pairs(Character.defs) do
        assert(def.kind, id .. ": no `kind`. Every body declares what it IS -- humanoid/beast/demon/"
            .. "undead/construct/elemental/object -- rather than leaving tools/char_compose to guess it "
            .. "off words in the id (which read every wolf as a humanoid).")
        assert(KINDS[def.kind], id .. ": unknown kind " .. tostring(def.kind))
    end
end }

tests[#tests + 1] = { name = "every character declares a rung, and holds its band", fn = function()
    for id, def in pairs(Character.defs) do
        assert(def.tier, id .. ": no `tier`. Declare 1 chaff / 2 line / 3 elite / 4 boss, or 0 for a "
            .. "body that is not on the ladder (a prop, an escortee, a worn shape).")
        assert(type(def.tier) == "number" and def.tier == math.floor(def.tier)
            and def.tier >= 0 and def.tier <= 4, id .. ": tier must be 0-4, got " .. tostring(def.tier))

        local band = BANDS[def.tier]
        if band then
            local hp = (def.stats or {}).health or 0
            assert(hp >= band[1] and hp <= band[2], string.format(
                "%s: declares tier %d (%d-%s health) but has %d. Either the number moved or the rung "
                .. "is wrong -- docs/bestiary.md.",
                id, def.tier, band[1], band[2] == math.huge and "+" or tostring(band[2]), hp))
        end
    end
end }

tests[#tests + 1] = { name = "a declared class is one of the seven", fn = function()
    -- Deliberately NOT "every humanoid declares a class." `class` is not a label on an enemy, it is the
    -- growth table it climbs (models/growth.lua, Growth.creditClass), so declaring one on a body that
    -- had none is a balance change wearing a taxonomy change. The rogue and hunter tables buy +2 damage
    -- a level against the knight table's +2 defense -- they cancel, so a rogue-classed mook's
    -- post-mitigation damage never rises while its target gains +6 health a level, and by level 20 it
    -- cannot hurt an armoured party at all. Only the classless fallback (fighter, +3 damage) outpaces
    -- armour, which is why every un-classed body in the folder has been scaling and none of them said so.
    --
    -- So the shelf is declared where something reads it -- the discipline rule below -- and the plain
    -- chaff keeps the fallback, with the reason written into character_bandit.lua rather than left for
    -- the next person to rediscover through tests/enemy_scaling_spec.lua.
    for id, def in pairs(Character.defs) do
        if def.class then
            assert(Class.roots()[def.class], id .. ": unknown class " .. tostring(def.class))
            assert(def.kind == "humanoid", id .. ": a " .. tostring(def.kind) .. " has no shelf. "
                .. "Creature kit is natural weapons only.")
        end
    end
end }

tests[#tests + 1] = { name = "a declared discipline is real, and its parent is the body's class", fn = function()
    for id, def in pairs(Character.defs) do
        if def.discipline then
            local d = Class.defs[def.discipline]
            assert(d, id .. ": unknown discipline " .. tostring(def.discipline))
            assert(def.class, id .. ": declares discipline " .. def.discipline .. " but no class")
            -- The same invariant an ITEM obeys (tests/class_ladder_spec.lua): a body built as a
            -- discipline fights off one of its parent shelves, and that is the shelf it grows on.
            local ok = false
            for _, parent in ipairs(Class.parents(def.discipline)) do
                if parent == def.class then ok = true end
            end
            assert(ok, string.format("%s: class %q is not a parent of discipline %q (%s)",
                id, def.class, def.discipline,
                table.concat(Class.parents(def.discipline), "+")))
        end
    end
end }

tests[#tests + 1] = { name = "a body that claims a discipline carries it", fn = function()
    for id, def in pairs(Character.defs) do
        if def.discipline then
            local found
            for _, itemId in ipairs(kitOf(def)) do
                local item = Item.defs[itemId]
                -- The item's own class is the claim now (docs/class-fold.md): a Ninja blade is
                -- `class = "ninja"`, where it used to be rogue stock wearing a second field.
                if item and item.class == def.discipline then found = itemId; break end
            end
            assert(found, string.format(
                "%s: declares discipline %q but carries none of its stock. The Elite rung IS the "
                .. "demonstration -- a body that claims a discipline and shows none of it is the stat "
                .. "block this field exists to catch (docs/bestiary.md).", id, def.discipline))
        end
    end
end }

tests[#tests + 1] = { name = "creatures carry no discipline gear", fn = function()
    for id, def in pairs(Character.defs) do
        if def.kind ~= "humanoid" then
            assert(not def.discipline, id .. ": a " .. def.kind .. " cannot BE a discipline. "
                .. "A wolf is not a Beastmaster; a wolf is what a Beastmaster has.")
            -- The gear test reads the item's class now, and it asks EXACTLY what it asked before: no
            -- earned class's gear on a creature (docs/class-fold.md restates "has a discipline" as
            -- "is not a root").
            --
            -- THE STRONGER FORM -- `item.class == "creature"`, a creature carries only its own kit --
            -- was written here first and reverted, because it is a different claim and it fails today:
            -- character_miller_ghost carries ability_fireball, which is mage stock. That may well be a
            -- content bug, and the old check could not see it (a root class was invisible to a test
            -- that read the sparse second field). It is not this pass's to decide, and widening a
            -- contract while migrating the field it is written in is how a refactor acquires an
            -- argument it did not need to have.
            for _, itemId in ipairs(kitOf(def)) do
                local item = Item.defs[itemId]
                assert(not (item and Class.isEarned(item.class)), string.format(
                    "%s (%s) carries %s, which is %s stock. Creature kit is natural weapons only -- "
                    .. "unpriced, noSteal, outside every shelf.", id, def.kind, itemId,
                    tostring(item and item.class)))
            end
        end
    end
end }

tests[#tests + 1] = { name = "every body that fights carries something to fight with", fn = function()
    -- The hole this was written for: character_siege_breaker, an 84-health `assassinate` mark, shipped
    -- with an empty grid and swung weapon_unarmed -- the generic bare fist -- at a party that had
    -- walked a mountain road to reach it. Nothing failed; it just quietly was not a fight.
    --
    -- Rung 0 is exempt by construction: an escortee that cannot fight and a plank that never moves are
    -- supposed to carry nothing. A blueprint that opts out of a natural weapon entirely
    -- (`unarmed = false`) is making that choice explicitly and is left alone.
    for id, def in pairs(Character.defs) do
        if def.tier > 0 and def.unarmed ~= false then
            assert(#kitOf(def) > 0, id .. ": tier " .. def.tier .. " and an empty grid, so it swings "
                .. "the default bare fist. Give it a weapon -- shelf gear if it is a humanoid, a "
                .. "natural weapon if it is not.")
        end
    end
end }

tests[#tests + 1] = { name = "an Elite or Boss humanoid is more than a weapon", fn = function()
    -- What the pass this file came from was actually asked to fix: "bandit chief is only outfitted with
    -- an iron sword." At the Elite rung one item is a stat block -- the rung's whole job is to be
    -- legible before it acts. Chaff and Line are deliberately NOT held to this: a cutpurse is a
    -- cutpurse, and one cheap item off its faction's shelf is the correct kit for it.
    --
    -- Nor is the BOSS rung, and that is a real distinction rather than an exemption of convenience. A
    -- boss's identity is machinery, not a shelf: each of the seven sin generals is one relic plus one
    -- weapon, and the relic IS the fight (Aurea's Bottomless Purse, Ira's Unappeased Heart). Holding
    -- them to three items would be asking a phase engine to also go shopping.
    for id, def in pairs(Character.defs) do
        if def.kind == "humanoid" and def.tier == 3 then
            local n = #kitOf(def)
            assert(n >= 3, string.format("%s: tier %d humanoid carrying %d item(s). An Elite is a "
                .. "signature relic and a rule list that reads, not a health pool with a sword.",
                id, def.tier, n))
        end
    end
end }

tests[#tests + 1] = { name = "a body that means to move can take a step", fn = function()
    -- Armour movement penalties STACK (tests/armor_spec.lua), and the two halves of that sum are
    -- authored months apart: `movement` is one line at the top of a blueprint, the coats are a grid
    -- filled in later by whoever was writing that body's kit. Nothing ever added them together.
    --
    -- What the sum reaching zero costs is invisible in every direction. Combat.moveBudget clamps at 0
    -- rather than going negative, Combat.reachableList comes back empty, and models/ai.lua walks its
    -- whole rule list, finds nothing within reach of a melee weapon it can never close with, and
    -- returns `{ wait = true }`. No error, no warning: on the board it reads as an enemy standing in
    -- its corner doing nothing for the length of the battle, which looks like a broken planner and is
    -- a stat line.
    --
    -- Two bodies were sitting on it when this was written. character_forsworn_captain declared 2 and
    -- wore a tower shield and the Warden's Oath at -1 each; character_bulwark declared 4 and wore the
    -- Halting Rank and the Unyielding Harness at -2 each. Both are fixed in their own files, and the
    -- fixes are opposite -- one raised the base, one took a coat off -- which is exactly why this
    -- asserts the sum and not either half of it.
    --
    -- A blueprint that declares `movement = 0` is a sentry, a totem or a plank, and opts out by saying
    -- so, the same way rung 0 opts out of carrying a weapon above.
    for id, def in pairs(Character.defs) do
        local base = def.stats and def.stats.movement
        if base and base > 0 then
            local unit = { char = Character.instantiate(id), alive = true, x = 1, y = 1, side = "enemy" }
            Combat.refreshPassives(unit)
            assert(Combat.moveBudget(unit) > 0, string.format("%s: declares movement %d and its kit "
                .. "spends %d of it, so it cannot take a step and waits out every battle it stands "
                .. "in. Raise the base, or take a coat off it.",
                id, base, base - Combat.flatStat(unit, "movement")))
        end
    end
end }

-- ---------------------------------------------------------------------------
-- What a creature wears instead of armour
-- ---------------------------------------------------------------------------

-- The bodies this contract covers: everything that is not a humanoid and not a prop. `object` is out
-- with rung 0 -- a plank and a straw sentry are not wearing anything and are not meant to be measured.
local function isArmourless(def)
    return def.kind and def.kind ~= "humanoid" and def.kind ~= "object" and (def.tier or 0) > 0
end

-- WAIVED, NOT EXEMPT -- the entry is the argument, exactly as Balance.FROZEN's is.
local NO_INNATE = {
    -- The one body a rescale is also forbidden to touch (Balance.FROZEN). data/tutorials/village.lua
    -- quotes its arithmetic line by line and the parry beat is built on it landing a specific blow and
    -- surviving a specific answer; an innate resist is that arithmetic changing. It also declares
    -- `scaling = false`, so there is nowhere for the change to hide either.
    character_demon_grunt = "prologue: the parry lesson is written against these exact numbers",
}

tests[#tests + 1] = { name = "every armourless body declares what it has instead", fn = function()
    local missing = {}
    for id, def in pairs(Character.defs) do
        if isArmourless(def) and not def.resist and not NO_INNATE[id] then
            missing[#missing + 1] = string.format("%s (%s, tier %d)", id, def.kind, def.tier)
        end
    end
    table.sort(missing)
    -- Asserted as a SET rather than left to whoever adds the next wolf. A humanoid buys its per-tag
    -- line off a shelf and the absence of one is a loadout; a creature buys nothing, so the absence of
    -- one is a body that goes into every fight with an empty resist table and no way for its author to
    -- notice. That was the state of all 67 of these before this pass.
    assert(#missing == 0, "these wear no armour and declare no innate `resist`, so every weapon in the "
        .. "game lands on them identically (docs/bestiary.md):\n  " .. table.concat(missing, "\n  "))
end }

tests[#tests + 1] = { name = "an innate resist is a trade, not a buff", fn = function()
    local Balance = require("models.balance")

    -- The legal vocabulary: the three physical types the melee probes carry, plus the closed element
    -- set armour `resist` is already keyed on (Combat.ELEMENT_TAGS) and `magical`. Read from those two
    -- rather than listed here, so widening either widens this and a typo'd tag stays a failure -- a
    -- resist under a tag no weapon carries is silently nothing at all.
    local legal = { magical = true }
    for _, t in ipairs(Balance.INNATE_PHYSICAL) do legal[t] = true end
    for t in pairs(Combat.ELEMENT_TAGS) do legal[t] = true end

    local bad = {}
    for id, def in pairs(Character.defs) do
        if def.resist then
            local budget = Balance.INNATE_BUDGET[def.tier or 0]
            local function fail(fmt, ...) bad[#bad + 1] = id .. ": " .. string.format(fmt, ...) end

            if not isArmourless(def) then
                fail("a %s does not have an innate hide -- its per-tag line comes off a shelf, as a "
                    .. "`resist` table on the armour it wears", tostring(def.kind))
            end
            if not budget then
                fail("tier %s has no Balance.INNATE_BUDGET entry", tostring(def.tier))
            end

            local physical = 0
            for tag, amount in pairs(def.resist) do
                if tag == "physical" then
                    fail("names `physical`, which subtracts from all three melee probes at once -- "
                        .. "that is what the `defense` stat already is. Name the type.")
                elseif not legal[tag] then
                    fail("unknown resist tag %q -- nothing carries it, so the line is worth zero", tag)
                end
                if type(amount) ~= "number" or amount ~= math.floor(amount) then
                    fail("%s = %s is not a whole number of damage", tag, tostring(amount))
                elseif budget then
                    local cap = amount >= 0 and budget or budget * Balance.INNATE_WEAKNESS_FACTOR
                    if math.abs(amount) > cap then
                        fail("%s = %d exceeds the tier-%d %s budget of %d", tag, amount, def.tier,
                            amount >= 0 and "resist" or "weakness", cap)
                    end
                end
                for _, t in ipairs(Balance.INNATE_PHYSICAL) do
                    if tag == t then physical = physical + amount end
                end
            end

            if physical ~= 0 then
                fail("its slash/pierce/impact lines sum to %+d. A creature's hide is a REDISTRIBUTION: "
                    .. "they must sum to zero, so turning one weapon aside costs it another. See "
                    .. "Balance.INNATE_PHYSICAL for why a cap was not enough.", physical)
            end
        end
    end
    table.sort(bad)
    assert(#bad == 0, "innate `resist` tables that break the contract:\n  " .. table.concat(bad, "\n  "))
end }

tests[#tests + 1] = { name = "an innate resist reaches the unit that fights", fn = function()
    -- The failure this exists for is silent in both directions. Character.instantiate builds its table
    -- by an explicit whitelist, so a field nobody named there reads back nil; and Combat's passive fold
    -- rebuilds unit.resist from scratch at every setup, so a hide seeded in the wrong place would be
    -- wiped by the first item in the grid. Walk the whole path once, on a body whose numbers say which
    -- end broke.
    local unit = { char = Character.instantiate("character_wolf_grunt"), alive = true, side = "enemy" }
    Combat.refreshPassives(unit)
    assert(unit.resist.slash == 2, "a wolf's coat did not reach the unit: slash resist is "
        .. tostring(unit.resist.slash) .. ", expected 2")
    assert(unit.resist.impact == -2, "a wolf's coat kept its resist and lost its price: impact is "
        .. tostring(unit.resist.impact) .. ", expected -2")

    -- And it is really in the formula, not merely on the table. Measured through the one damage
    -- function rather than re-derived, the way models/balance.lua measures everything.
    local slash = Combat.mitigatedDamage(unit, 100, { "sword", "slash", "physical", "melee" })
    local impact = Combat.mitigatedDamage(unit, 100, { "mace", "impact", "physical", "melee" })
    assert(impact - slash == 4, string.format("the trade did not reach Combat.mitigatedDamage: a mace "
        .. "lands %d and a blade %d, a gap of %d where the coat says 4", impact, slash, impact - slash))

    -- A grid item layers ON TOP of the hide rather than replacing it: the seed happens before the fold.
    unit.char.inventory[9] = require("models.item").instantiate("armor_leather_armor")
    Combat.refreshPassives(unit)
    assert(unit.resist.slash == 5, "a coat over a hide should be both: got " .. tostring(unit.resist.slash))
end }

tests[#tests + 1] = { name = "the runtime character keeps kind, tier and discipline", fn = function()
    -- Character.instantiate builds its table field by field rather than cloning the blueprint, so a
    -- field nobody named there reads back nil at runtime and fails silently (its own header says so).
    local c = Character.instantiate("character_bandit_chief")
    assert(c.kind == "humanoid", "kind was dropped on instantiate")
    assert(c.tier == 3, "tier was dropped on instantiate")
    assert(c.discipline == "thief", "discipline was dropped on instantiate")

    -- And keeps the innate hide, which is the same failure mode with a new field in it.
    local wolf = Character.instantiate("character_wolf_grunt")
    assert(wolf.resist and wolf.resist.slash == 2, "resist was dropped on instantiate")
    assert(wolf.resist ~= Character.defs.character_wolf_grunt.resist,
        "resist is the blueprint's own table -- one wolf's edit would reach every wolf")
end }

return tests

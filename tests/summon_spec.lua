-- Tests for summoning (models/summon.lua + models/combat.lua): a character placed on the field
-- mid-battle joins the turn order, obeys whoever called it, is sustained by the resource its
-- summoner reserved, and sets off whatever it is called on top of. Kill either end of that bond and
-- the other is freed. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Summon = require("models.summon")
local Trap = require("models.trap")
local Hazard = require("models.hazard")
local Status = require("models.status")

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    -- Isolate from the innate, which now rides on a bound signature relic in the grid (see
    -- tests/innate_spec.lua): strip that relic. The archer's innate wolf would otherwise add a unit and
    -- take the tile these fixtures spawn onto by hand, and the mage relic's mana ceiling would skew the
    -- reservation math.
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

-- Wipe a character's grid and place `ids` from slot 1, so a spec controls the whole loadout.
local function equip(char, ids)
    char.inventory = {}
    for _, id in ipairs(ids) do Character.addItem(char, Item.instantiate(id)) end
end

local function inOrder(c, u)
    for _, entry in ipairs(Combat.turnOrder(c)) do
        if entry == u then return true end
    end
    return false
end

return {
    {
        name = "a summon joins the units, the turn order, and starts at its own natural initiative",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 1, 1) }, { unit("character_bandit", 8, 8) })
            local archer = c.units[1]
            local before = #c.units

            local wolf = Summon.spawn(c, archer, "character_wolf_grunt", 2, 1)
            assert(#c.units == before + 1, "it is a real unit on the field")
            assert(Combat.unitAt(c, 2, 1) == wolf, "standing where it was called")
            assert(inOrder(c, wolf), "and it takes turns")

            local natural = math.max(0, Combat.initiative(wolf.char))
            assert(wolf.initiative == natural,
                "it enters at its own initiative, clamped so it can't cut ahead of the acting unit")
            assert(archer.initiative == 0, "the summoner keeps the turn it is in the middle of")
        end,
    },
    {
        name = "a summon inherits its summoner's controller, and its passives are folded in",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 1, 1) }, { unit("character_bandit", 8, 8) })
            local archer, bandit = c.units[1], c.units[2]

            local mine = Summon.spawn(c, archer, "character_wolf_grunt", 2, 1)
            assert(mine.side == "party" and Combat.isPlayerControlled(mine), "my wolf answers to me")
            assert(mine.bonus and mine.resist, "its item passives were folded in on arrival")

            local theirs = Summon.spawn(c, bandit, "character_wolf_grunt", 7, 8)
            assert(theirs.side == "enemy" and theirs.control == "ai", "their wolf answers to the AI")

            local inert = Summon.spawn(c, archer, "character_wolf_grunt", 1, 2, { control = "none" })
            assert(not Combat.isPlayerControlled(inert), "an inert summon is nobody's to command")
        end,
    },
    {
        name = "power scales a summon additively, per stat, and it arrives at full health",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 1, 1) }, { unit("character_bandit", 8, 8) })
            local archer = c.units[1]
            local base = Character.defs.character_wolf_grunt.stats

            local wolf = Summon.spawn(c, archer, "character_wolf_grunt", 2, 1, {
                scaling = { health = 2, damage = 0.5 }, amount = 10,
            })
            local hp = wolf.char.stats.health
            assert(hp.max == base.health + 20, "health max grew by power * factor")
            assert(hp.current == hp.max, "and it arrives unwounded, not at its old current")
            assert(wolf.char.stats.damage == base.damage + 5, "damage grew by power * factor")
        end,
    },
    {
        name = "an ability's reservation is bound to the creature it summons",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            local mana = mage.char.stats.mana
            local expected = math.floor(mana.max * 0.25)

            local summon = itemNamed(mage.char, "ability_summon_fire_elemental")
            assert(Combat.useItem(c, mage, summon, 3, 2), "the cast begins winding up")
            assert(Combat.resolveChannel(c, mage), "and the wound-up binding forms the elemental")

            local elemental = Combat.unitAt(c, 3, 2)
            assert(elemental and elemental.char.id == "character_fire_elemental", "the elemental is there")
            assert(Combat.reservedAmount(mage.char, "mana") == expected, "a quarter of max mana is committed")
            assert(mana.max == 80, "the maximum itself is untouched")
            assert(Combat.unreservedMax(mage.char, "mana") == 80 - expected, "the ceiling drops by the reservation")
            assert(mana.current == 80 - expected, "and the cast spent that mana outright")
        end,
    },
    {
        name = "killing a summon releases the mana its summoner set aside",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            local summon = itemNamed(mage.char, "ability_summon_fire_elemental")
            Combat.useItem(c, mage, summon, 3, 2)
            Combat.resolveChannel(c, mage) -- the summon winds up before the elemental forms
            local elemental = Combat.unitAt(c, 3, 2)
            assert(Combat.reservedAmount(mage.char, "mana") > 0, "committed while it lives")

            Combat.dealFlatDamage(c, elemental, 9999, { "physical" })
            assert(not elemental.alive, "the elemental falls")
            assert(Combat.reservedAmount(mage.char, "mana") == 0, "and the mage's mana is freed")
            assert(Combat.unreservedMax(mage.char, "mana") == 80, "the ceiling is whole again")
        end,
    },
    {
        name = "killing the summoner dismisses its summons and frees the reservation",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            Combat.useItem(c, mage, itemNamed(mage.char, "ability_summon_fire_elemental"), 3, 2)
            Combat.resolveChannel(c, mage) -- the summon winds up before the elemental forms
            local elemental = Combat.unitAt(c, 3, 2)

            Combat.dealFlatDamage(c, mage, 9999, { "physical" })
            assert(not mage.alive, "the mage falls")
            assert(not elemental.alive, "and what it was sustaining vanishes with it")
            assert(Combat.reservedAmount(mage.char, "mana") == 0, "no reservation outlives its holder")
        end,
    },
    {
        name = "a live enemy summon blocks killAll; killing its summoner dismisses it and resolves the fight",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 8, 8) })
            local bandit = c.units[2]
            local wolf = Summon.spawn(c, bandit, "character_wolf_grunt", 7, 8)

            -- Kill the bandit's summoner-less companion first: only the wolf is left standing, and it
            -- is an enemy like any other, so the objective must not resolve.
            Combat.dealFlatDamage(c, bandit, 9999, { "physical" })
            -- ...except the wolf was sustained by the bandit, so it went with it.
            assert(not wolf.alive, "its summon is dismissed with it")
            assert(Combat.aliveCount(c, "enemy") == 0, "nothing hostile is left")
            assert(Combat.evaluate(c) == "win", "so killAll resolves without hunting the summon down")
        end,
    },
    {
        name = "a summon of a still-living enemy keeps killAll open",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 8, 8) })
            local bandit = c.units[2]
            -- Give the wolf an independent summoner that never dies, so it outlives the bandit.
            local wolf = Summon.spawn(c, bandit, "character_wolf_grunt", 7, 8)
            wolf.summoner = nil

            Combat.dealFlatDamage(c, bandit, 9999, { "physical" })
            assert(wolf.alive, "nothing sustains it, so it stays")
            assert(Combat.evaluate(c) == nil, "and it must be killed like any other enemy")

            Combat.dealFlatDamage(c, wolf, 9999, { "physical" })
            assert(Combat.evaluate(c) == "win", "once it falls, the field is clear")
        end,
    },
    {
        name = "a summoned duplicate of an assassination target does not count as the target",
        fn = function()
            local c = Combat.new(arena(8, 8, { type = "assassinate", target = "character_bandit_chief" }),
                { unit("character_knight", 1, 1) }, { unit("character_bandit_chief", 8, 8) })
            local chief = c.units[2]

            local double = Summon.copy(c, chief, 7, 8, { fragile = true })
            assert(double.char.id == "character_bandit_chief", "the copy shares the mark's identity")
            assert(double.summoned, "but it is flagged as conjured")

            Combat.dealFlatDamage(c, chief, 9999, { "physical" })
            assert(not double.alive, "the double is dismissed with its summoner")
            assert(Combat.evaluate(c) == "win", "killing the real mark ends the hunt")
        end,
    },
    {
        name = "a copy carries the caster's current stats and kit, minus anything marked noCopy",
        fn = function()
            local mage = Character.instantiate("character_mage")
            equip(mage, { "ability_fireball", "ability_doppelganger", "armor_silk_robes" })
            local c = Combat.new(arena(8, 8), { unit(mage, 2, 2) }, { unit("character_bandit", 8, 8) })
            local caster = c.units[1]
            caster.char.stats.health.current = 31 -- wounded

            local double = Summon.copy(c, caster, 3, 2, { fragile = true })
            assert(double.char.stats.health.current == 31, "the copy is as wounded as the original")
            assert(itemNamed(double.char, "ability_fireball"), "it carries the caster's spells")
            assert(itemNamed(double.char, "armor_silk_robes"), "and its armor")
            assert(not itemNamed(double.char, "ability_doppelganger"),
                "but never the ability that made it -- a copy cannot copy itself")
            assert(double.char.inventory ~= caster.char.inventory, "the grids are separate")
        end,
    },
    {
        name = "a fragile summon dies to any hit at all",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 8, 8) })
            local knight = c.units[1]
            local double = Summon.copy(c, knight, 3, 2, { fragile = true })
            assert(double.char.stats.health.current > 1, "it looks perfectly healthy")

            Combat.dealFlatDamage(c, double, 1, { "physical" })
            assert(not double.alive, "one scratch and the illusion collapses")
        end,
    },
    {
        name = "a summon ability is refused when its reservation cannot be committed",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            mage.char.stats.mana.current = 1

            local ok, reason = Combat.useItem(c, mage, itemNamed(mage.char, "ability_summon_fire_elemental"), 3, 2)
            assert(not ok and reason == "insufficient mana", "you cannot set aside what you don't hold")
            assert(Combat.unitAt(c, 3, 2) == nil, "and nothing was summoned")
            assert(c.turn ~= nil, "the turn was never spent")
        end,
    },
    {
        name = "a summon ability cannot be recast while its creature stands, and frees up when it falls",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            local summon = itemNamed(mage.char, "ability_summon_fire_elemental")

            openTurn(c, mage)
            assert(Combat.useItem(c, mage, summon, 3, 2), "the first elemental begins winding up")
            assert(Combat.resolveChannel(c, mage), "and forms once wound up")
            local elemental = Combat.unitAt(c, 3, 2)
            assert(Combat.activeSummon(summon) == elemental, "the item holds what it called")

            openTurn(c, mage)
            assert(mage.char.stats.mana.current >= 20, "the mage could well afford a second one")
            local ok, reason = Combat.useItem(c, mage, summon, 2, 3)
            assert(not ok and reason == "summon still active", "but one elemental is all it may sustain")
            assert(Combat.unitAt(c, 2, 3) == nil, "nothing was summoned")
            assert(c.turn ~= nil, "and the refused cast never spent the turn")

            local blocked = Combat.itemBlockReason(mage, summon)
            assert(blocked and blocked.kind == "active" and blocked.summon == elemental,
                "the UI is told which creature is holding the ability")

            Combat.dealFlatDamage(c, elemental, 9999, { "physical" })
            assert(Combat.activeSummon(summon) == nil, "the claim dies with the creature")
            assert(Combat.useItem(c, mage, summon, 2, 3), "so the mage may call another")
            assert(Combat.resolveChannel(c, mage), "the second binding winds up and forms")
            assert(Combat.unitAt(c, 2, 3), "and it stands where it was called")
        end,
    },
    {
        name = "a summon dismissed with its summoner releases the ability that called it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            local summon = itemNamed(mage.char, "ability_summon_fire_elemental")
            openTurn(c, mage)
            Combat.useItem(c, mage, summon, 3, 2)
            Combat.resolveChannel(c, mage) -- wind the summon up so a real elemental stands

            -- The mage falls, taking the elemental with it. The item's claim must go too, or a
            -- revived mage would be holding a creature that isn't on the field.
            Combat.dealFlatDamage(c, mage, 9999, { "physical" })
            assert(Combat.activeSummon(summon) == nil, "a dismissed summon holds nothing")
        end,
    },
    {
        name = "a summon still standing at the last blow does not follow the party into the next battle",
        fn = function()
            local mage = Character.instantiate("character_mage")
            local c = Combat.new(arena(8, 8), { unit(mage, 2, 2) }, { unit("character_bandit", 8, 8) })
            openTurn(c, c.units[1])
            local summon = itemNamed(mage, "ability_summon_fire_elemental")
            Combat.useItem(c, c.units[1], summon, 3, 2)
            Combat.resolveChannel(c, c.units[1]) -- wind the summon up so a real elemental stands
            assert(Combat.activeSummon(summon), "the elemental outlives the fight")

            -- Same character instance, new battle: its grid must come up clean.
            local next_ = Combat.new(arena(8, 8), { unit(mage, 2, 2) }, { unit("character_bandit", 8, 8) })
            assert(Combat.activeSummon(summon) == nil, "the claim was left behind with the old field")
            assert(Combat.itemBlockReason(next_.units[1], summon) == nil, "so it may be cast again")
        end,
    },
    {
        name = "releaseClaims frees the summon claim when the battle ends, so the overworld reads clean",
        fn = function()
            local mage = Character.instantiate("character_mage")
            local c = Combat.new(arena(8, 8), { unit(mage, 2, 2) }, { unit("character_bandit", 8, 8) })
            openTurn(c, c.units[1])
            local summon = itemNamed(mage, "ability_summon_fire_elemental")
            Combat.useItem(c, c.units[1], summon, 3, 2)
            Combat.resolveChannel(c, c.units[1]) -- wind the summon up so a real elemental stands
            assert(Combat.activeSummon(summon), "the elemental stands at the final blow")

            -- Battle over: the party leaves the field (states/battle.lua win/lose call this). No new
            -- Combat.new has run yet, so this is exactly what a hub/overworld item tooltip reads.
            Combat.releaseClaims(mage)
            assert(Combat.activeSummon(summon) == nil, "the claim is gone the moment the battle ends")
            assert(Combat.itemBlockReason(nil, summon) == nil,
                "so the item tooltip no longer cries 'still on the field'")
        end,
    },
    {
        name = "a timed summon counts down on the combat clock and fades when its duration runs out",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            Combat.useItem(c, mage, itemNamed(mage.char, "ability_summon_fire_elemental"), 3, 2)
            Combat.resolveChannel(c, mage) -- the summon winds up before the elemental forms
            local elemental = Combat.unitAt(c, 3, 2)
            assert(elemental.summonRemaining == 24, "the elemental is bound for its declared duration")

            -- Ticks are the currency: rebase counts the binding down by the elapsed clock, exactly
            -- as it counts down a Burn or a patch of fire.
            Summon.tick(c, 10)
            assert(elemental.alive and elemental.summonRemaining == 14, "it stands while time remains")

            Summon.tick(c, 14)
            assert(not elemental.alive, "at zero the binding lapses and it fades")
            assert(Combat.reservedAmount(mage.char, "mana") == 0, "which frees the mana it was holding")
            assert(Combat.unreservedMax(mage.char, "mana") == 80, "the ceiling is whole again")
            assert(Combat.activeSummon(itemNamed(mage.char, "ability_summon_fire_elemental")) == nil,
                "and the ability may be cast again")
        end,
    },
    {
        name = "a summon with no duration stands indefinitely, however much time passes",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2) }, { unit("character_bandit", 8, 8) })
            local archer = c.units[1]
            openTurn(c, archer)
            Combat.useItem(c, archer, itemNamed(archer.char, "ability_summon_wolf"), 3, 2)
            local wolf = Combat.unitAt(c, 3, 2)
            assert(wolf.summonRemaining == nil, "the wolf carries no countdown at all")

            Summon.tick(c, 9999)
            assert(wolf.alive, "so no amount of time dismisses it -- only a blade will")
        end,
    },
    {
        name = "the real turn clock ages a summon: ending turns fades it without anyone calling tick",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage, bandit = c.units[1], c.units[2]
            mage.initiative, bandit.initiative = 0, 100
            openTurn(c, mage)
            Combat.useItem(c, mage, itemNamed(mage.char, "ability_summon_fire_elemental"), 3, 2)
            Combat.resolveChannel(c, mage) -- the summon winds up before the elemental forms
            local elemental = Combat.unitAt(c, 3, 2)
            local born = c.clock
            assert(elemental.summonRemaining == 24, "it arrives with its full binding (addUnit never rebases)")

            -- Wind the clock forward with real turns until the binding lapses. Nothing here touches
            -- Summon.tick: the countdown must ride the same rebase every other duration rides.
            for _ = 1, 20 do
                if not elemental.alive then break end
                local u = Combat.startTurn(c)
                if not u then break end
                Combat.wait(c, u)
            end
            assert(not elemental.alive, "the elemental faded as the battle wore on")
            assert(c.clock - born >= 24, "after at least its duration in ticks had elapsed")
        end,
    },
    {
        name = "a faded summon's own summons go with it, and the log says it faded rather than fell",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            Combat.useItem(c, mage, itemNamed(mage.char, "ability_summon_fire_elemental"), 3, 2)
            Combat.resolveChannel(c, mage) -- the summon winds up before the elemental forms
            local elemental = Combat.unitAt(c, 3, 2)
            -- Hang a second creature off the elemental, so the dismissal has a chain to unwind.
            local pup = Summon.spawn(c, elemental, "character_wolf_grunt", 4, 2)

            Summon.tick(c, 999)
            assert(not elemental.alive, "the elemental fades")
            assert(not pup.alive, "and what IT was sustaining vanishes with it")

            local faded = false
            for _, e in ipairs(c.log) do
                if e.text:find("fades away") then faded = true end
                assert(not e.text:find("Fire Elemental is defeated"), "nothing struck it down")
            end
            assert(faded, "the log records the binding lapsing, not a death")
        end,
    },
    {
        name = "one double at a time: a doppelganger cannot beget a second while the first stands",
        fn = function()
            local mage = Character.instantiate("character_mage")
            equip(mage, { "ability_doppelganger" })
            local c = Combat.new(arena(8, 8), { unit(mage, 2, 2) }, { unit("character_bandit", 8, 8) })
            local caster = c.units[1]
            local double = itemNamed(caster.char, "ability_doppelganger")

            openTurn(c, caster)
            assert(Combat.useItem(c, caster, double, 3, 2), "the double appears")
            openTurn(c, caster)
            local ok, reason = Combat.useItem(c, caster, double, 2, 3)
            assert(not ok and reason == "summon still active", "and it will not split again")

            Combat.dealFlatDamage(c, Combat.unitAt(c, 3, 2), 1, { "physical" })
            openTurn(c, caster)
            assert(Combat.useItem(c, caster, double, 2, 3), "once the illusion collapses, it may recast")
        end,
    },
    {
        name = "the summon tooltip preview names the creature without spawning it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2) }, { unit("character_bandit", 8, 8) })
            local archer = c.units[1]
            local before = #c.units

            local out = Combat.abilityOutput(archer, itemNamed(archer.char, "ability_summon_wolf"))
            assert(out and out.summon == "character_wolf_grunt", "the dry run reports what would be summoned")
            assert(#c.units == before, "and summons nothing")

            local preview = Combat.previewAbility(c, archer, itemNamed(archer.char, "ability_summon_wolf"), 3, 2)
            assert(preview ~= nil, "the aimed preview resolves")
            assert(#c.units == before, "still nothing summoned")
        end,
    },
    {
        name = "a summon scales with its item's upgrade level (fx.level), not a Power stat",
        fn = function()
            -- The old `summonPower` list is gone: the ability's `amount` is base + the item's level, so
            -- a forged summon ability fields a tougher creature.
            local function fireElementalHealthAt(level)
                local mage = Character.instantiate("character_mage")
                mage.inventory = {}
                Character.addItem(mage, Item.instantiate("ability_summon_fire_elemental", 1, level))
                local c = Combat.new(arena(8, 8), { unit(mage, 2, 2) }, { unit("character_bandit", 8, 8) })
                local caster = c.units[1]
                caster.char.stats.mana.current = caster.char.stats.mana.max
                openTurn(c, caster)
                local it = itemNamed(caster.char, "ability_summon_fire_elemental")
                assert(it.level == level, "the summon ability is forged to the asked level")
                assert(Combat.useItem(c, caster, it, 3, 2), "the elemental begins winding up")
                assert(Combat.resolveChannel(c, caster), "and forms once wound up")
                return Combat.unitAt(c, 3, 2).char.stats.health.max
            end
            -- Fire elemental base health 22, scaling health = 1 per point, amount = 12 + level.
            local base = fireElementalHealthAt(0)   -- 22 + 12
            local forged = fireElementalHealthAt(6) -- 22 + 18
            assert(base == 34, "a +0 fire elemental has 22 base + 12 amount = 34 health, got " .. base)
            assert(forged == base + 6, "a +6 fire elemental gains +6 health (amount 18 vs 12), got " .. forged)
        end,
    },

    -- Arriving on a tile (Combat.enterTile): a conjured body sets off what it lands on, exactly as
    -- one that walked or was shoved there would.
    {
        name = "a creature summoned on top of an enemy trap springs it the moment it arrives",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 1, 1) }, { unit("character_bandit", 8, 8) })
            local archer = c.units[1]
            Trap.place(c, 2, 1, "spike_trap", "enemy")

            local wolf = Summon.spawn(c, archer, "character_wolf_grunt", 2, 1)
            local hp = wolf.char.stats.health
            assert(hp.current < hp.max, "the spikes bit the wolf as it was called onto them")
            assert(Trap.at(c, 2, 1) == nil, "and the one-shot trap is spent")
        end,
    },
    {
        name = "a creature summoned onto its own side's trap leaves it alone",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 1, 1) }, { unit("character_bandit", 8, 8) })
            local archer = c.units[1]
            Trap.place(c, 2, 1, "spike_trap", "party")

            local wolf = Summon.spawn(c, archer, "character_wolf_grunt", 2, 1)
            local hp = wolf.char.stats.health
            assert(hp.current == hp.max, "own-side immunity holds for a summon as for a walker")
            assert(Trap.at(c, 2, 1), "the trap is still armed, waiting for an enemy")
        end,
    },
    {
        name = "a creature summoned into a fire catches Burn on arrival",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 1, 1) }, { unit("character_bandit", 8, 8) })
            local archer = c.units[1]
            Hazard.place(c, 2, 1, "hazard_fire")

            local wolf = Summon.spawn(c, archer, "character_wolf_grunt", 2, 1)
            assert(Status.has(wolf, "status_burn"), "conjured into the flames is conjured alight")
        end,
    },
    {
        name = "a creature killed on arrival never holds its summoner's reservation",
        fn = function()
            -- The wolf is called onto a trap that kills anything: the reservation must never be
            -- bound, since the death that would have released it is already past.
            Trap.defs.test_slayer = { name = "Slayer", health = 1,
                onTrigger = function(ctx) ctx.damage(ctx.victim, 9999, {}) end }

            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2) }, { unit("character_bandit", 8, 8) })
            local archer = c.units[1]
            Trap.place(c, 3, 2, "test_slayer", "enemy")
            local mana = archer.char.stats.mana
            local horn = itemNamed(archer.char, "ability_summon_wolf")
            openTurn(c, archer)

            assert(Combat.useItem(c, archer, horn, 3, 2), "the cast lands -- the trap was hidden")
            local wolf = c.units[#c.units]
            assert(not wolf.alive, "and the wolf dies on the tile it was called to")
            assert(Combat.reservedAmount(archer.char, "mana") == 0, "nothing is committed to a corpse")
            assert(Combat.unreservedMax(archer.char, "mana") == mana.max, "the archer's ceiling is untouched")
            assert(Combat.activeSummon(horn) == nil, "and the horn is free to blow again")

            openTurn(c, archer)
            assert(Combat.useItem(c, archer, horn, 2, 3), "so a second wolf may be called at once")
        end,
    },
    {
        name = "a decoy destroyed by the trap it was planted on hides nobody",
        fn = function()
            local thief = Character.instantiate("character_archer")
            equip(thief, { "utility_decoy" })
            local c = Combat.new(arena(8, 8), { unit(thief, 2, 2) }, { unit("character_bandit", 8, 8) })
            local caster = c.units[1]
            Trap.place(c, 3, 2, "spike_trap", "enemy") -- a fragile double dies to any hit at all
            openTurn(c, caster)

            assert(Combat.useItem(c, caster, itemNamed(caster.char, "utility_decoy"), 3, 2), "the double is planted")
            local double = c.units[#c.units]
            assert(not double.alive, "and the spikes destroy it where it stands")
            assert(not Status.has(caster, "status_invisible"),
                "there is nothing left to hide behind, so the caster never slips out of sight")
            assert(Combat.activeSummon(itemNamed(caster.char, "utility_decoy")) == nil, "the trick may be tried again")

            -- The fake "moves to" line is never written: the double died before the lie was told.
            for _, e in ipairs(c.log) do
                assert(not e.text:find("moves to"), "the log claims no move that never happened")
            end
        end,
    },
}

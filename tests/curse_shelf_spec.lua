-- THE CURSE-FACING SHELF: gear that reads hexes, moves them, spends them and ends them.
--
-- Round 1 of this design gave the rift ten more curses (tests/curse_spec.lua covers those). This file
-- covers what the CATALOGUE does about them, which split into three verbs and one system:
--
--   the Shaman     manipulates -- counts, moves, spreads, wakes, lends. Never ends one.
--   the Exorcist   ends and prevents -- the two rites and the ward.
--   the Cathedral  stays open to everybody, which is the law docs/the-count.md states.
--   the road       an ability may be cast outside a fight at all (Player.partyAbilities)
--
-- WHAT THIS FILE IS REALLY FOR is the first of those. "A Shaman never removes a curse" is a rule that
-- lives in prose and in six separate blueprints, and prose is exactly the kind of implementation that
-- ships green and then quietly stops being true -- so the sweep at the bottom asserts it over the whole
-- shelf rather than over the items somebody remembered to name.
--
-- Pure logic, headless. Fixture style mirrors tests/curse_spec.lua.

local Character = require("models.character")
local Combat = require("models.combat")
local Curse = require("models.curse")
local Fixture = require("tests.support.fixture")
local Forge = require("models.forge")
local Item = require("models.item")
local Player = require("models.player")

local function unitFor(combat, spawn)
    for _, u in ipairs(combat.units) do
        if u.char == spawn.char then return u end
    end
    return nil
end

-- A body with `n` hexed pieces in its grid, built out of plain swords so the only variable is the count.
local function hexedBody(n, x, y)
    local items = {}
    for _ = 1, math.max(1, n) do items[#items + 1] = "weapon_iron_sword" end
    local spawn = Fixture.unit("character_knight", x or 2, y or 2,
        { isolate = "bare", items = items, stats = { health = 200, mana = 200, stamina = 200 } })
    for i = 1, n do
        assert(Curse.afflict(spawn.char.inventory[i], "curse_the_witness"), "hexed cell " .. i)
    end
    return spawn
end

return {
    {
        name = "counting a body's hexes is one call, and it is the one the grid badge draws",
        fn = function()
            local clean = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", items = { "weapon_iron_sword" } })
            assert(Curse.countOn(clean.char) == 0, "a clean grid counts nothing")
            assert(Curse.countOn(nil) == 0, "and a nil body answers rather than raising")

            local three = hexedBody(3)
            assert(Curse.countOn(three.char) == 3, "three hexed cells count three")
            assert(#Curse.hexedOn(three.char) == 3, "...and list three")

            -- THE BADGE AND THE BLOW READ THE SAME CALL. The Reckoning's `counter` is what draws the
            -- number on the grid and what its effect multiplies by; if those were two readings they
            -- could disagree, which is the one thing a live figure must never do.
            local reck = Item.instantiate("weapon_the_reckoning")
            local unit = { char = three.char }
            assert(reck.activeAbility.counter(unit) == 3, "the counter quotes the same three")
            assert(reck.activeAbility.counterGates == false,
                "and a clean bearer still swings -- 0 is a floor, not an empty purse")
        end,
    },
    {
        name = "the deepest hex is found by depth, and ties break by cell",
        fn = function()
            local body = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", items = { "weapon_iron_sword", "armor_leather_armor" } })
            Curse.afflict(body.char.inventory[1], "curse_the_witness")      -- depth 2
            Curse.afflict(body.char.inventory[2], "curse_the_long_memory")  -- depth 10
            local worst, def = Curse.deepestOn(body.char)
            assert(worst == body.char.inventory[2], "the deeper hex wins whichever cell it is in")
            assert(Curse.depthOf(def) == 10, "and its depth is what Rouse the Binding scales on")
        end,
    },
    {
        name = "a passive pays per hex and moves the moment one lands or lifts",
        fn = function()
            -- Trait.liveBonus is recomputed on every stat read, which is the whole reason The Gathered
            -- Weight is a trait rather than a `bonus` table: a hex count is not static.
            local c = Fixture.new(10, 10)
            local body = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", items = { "utility_gathered_weight", "weapon_iron_sword" } })
            local combat = Fixture.combat(c, { body }, {})
            local unit = unitFor(combat, body)

            local before = Combat.flatStat(unit, "attack")
            assert(Curse.afflict(body.char.inventory[2], "curse_the_witness"), "the sword takes a hex")
            local after = Combat.flatStat(unit, "attack")
            assert(after - before == 2, "one hex is worth +2 attack, got " .. (after - before))

            Curse.lift(body.char.inventory[2])
            assert(Combat.flatStat(unit, "attack") == before,
                "and it falls back the instant the hex is lifted -- nothing had to be told to refresh")
        end,
    },
    {
        name = "Rebind moves a hex to the ally beside it, and never destroys one on the way",
        fn = function()
            local from = hexedBody(1, 2, 2)
            local to = Fixture.unit("character_knight", 3, 2,
                { isolate = "bare", items = { "armor_leather_armor" } })
            assert(Curse.move(from.char.inventory[1], to.char.inventory[1]) == "curse_the_witness",
                "the move reports what it moved")
            assert(Curse.countOn(from.char) == 0, "the caster is rid of it")
            assert(Curse.countOn(to.char) == 1, "...and the ally has it -- the count is unchanged")

            -- THE DESTINATION IS CHECKED FIRST. A move that emptied the source and then found the
            -- target would refuse has DESTROYED a curse, which is precisely what a Shaman may not do.
            local hexed = hexedBody(1, 5, 5)
            local full = Item.instantiate("weapon_iron_sword")
            Curse.afflict(full, "curse_dead_weight")
            local moved, why = Curse.move(hexed.char.inventory[1], full)
            assert(moved == nil and why == "cannot take it", "a refused move says so")
            assert(Curse.countOn(hexed.char) == 1, "and the hex is still where it was")
        end,
    },
    {
        name = "a hex spreads into a neighbouring cell, and stops when the grid is full of them",
        fn = function()
            local body = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", items = { "weapon_iron_sword", "armor_leather_armor" } })
            local source = body.char.inventory[1]
            Curse.afflict(source, "curse_dead_weight")

            assert(Curse.spreadWithin(body.char, source) == "curse_dead_weight", "it creeps one cell")
            assert(Curse.countOn(body.char) == 2, "and the neighbour is hexed too")
            assert(Curse.spreadWithin(body.char, source) == nil,
                "with nowhere clean left to go it simply stops -- the nine cells are the ceiling")
        end,
    },
    {
        name = "Let It Walk spends a hex, and the bell decides whether it comes back",
        fn = function()
            -- THE ONE PLACE A CURSE ENDS WITHOUT A PRIEST, and the ruling survives it: the Shaman made
            -- the binding killable and somebody else swung. Both branches are asserted because the
            -- interesting one is the branch the design turns on.
            local body = hexedBody(1)
            local item = body.char.inventory[1]
            local id = item.curse

            item.lentCurse = { id = id, spirit = { alive = true } }
            Combat.releaseClaims(body.char)
            assert(item.curse == id, "a spirit still standing hands the binding back")
            assert(item.lentCurse == nil, "and the leash is cleared either way")

            Curse.lift(item)
            item.lentCurse = { id = id, spirit = { alive = false } }
            Combat.releaseClaims(body.char)
            assert(item.curse == nil, "a spirit that fell took the curse down with it")
        end,
    },
    {
        name = "a consecrated kit cannot be hexed at all, by any vector",
        fn = function()
            local c = Fixture.new(10, 10)
            local caster = Fixture.unit("character_knight", 2, 2, { isolate = "bare" })
            local warded = Fixture.unit("character_knight", 3, 2,
                { isolate = "bare", items = { "utility_consecration", "weapon_iron_sword" } })
            local bare = Fixture.unit("character_knight", 4, 2,
                { isolate = "bare", items = { "weapon_iron_sword" } })
            local combat = Fixture.combat(c, { caster }, { warded, bare })

            assert(Curse.warded(warded.char), "the ward is read off the whole grid, not off one piece")
            assert(not Curse.warded(bare.char), "and an ordinary kit is not warded")

            assert(Combat.curseItem(combat, unitFor(combat, warded), "curse_dead_weight") == nil,
                "a cast finds no purchase on a consecrated body")
            assert(Curse.countOn(warded.char) == 0, "nothing landed")
            assert(Combat.curseItem(combat, unitFor(combat, bare), "curse_dead_weight") ~= nil,
                "...and the same cast lands fine on the body beside it")
        end,
    },
    {
        name = "Cold Iron closes the bench, with its own word and on every path",
        fn = function()
            local player = Player.new()
            player.gold = 9000
            local sword = Item.instantiate("weapon_iron_sword")
            assert(Forge.canWork(sword), "an ordinary sword is bench work")
            assert(Forge.hexRefusal(sword) == nil, "and nothing refuses it")

            assert(Curse.afflict(sword, "curse_cold_iron"), "it takes Cold Iron")
            assert(Forge.hexRefusal(sword) == "cursed", "which the bench refuses by name")

            -- ITS OWN REASON, NOT "not forgeable". The two are different facts -- one is about the KIND
            -- of thing and is permanent, one is about this copy and has somewhere to go about it -- and
            -- a row greyed with the wrong word sends the player to the wrong building.
            local _, why = Forge.upgrade(player, sword)
            assert(why == "cursed", "the commit says cursed, got " .. tostring(why))
            assert(Forge.grantRefusal(player, sword) == "cursed", "and so does a free rung")
            assert(Forge.upgradeCost(player, sword).cursed == true,
                "...and the BILL carries it, so the row greys for the same reason the press refuses")

            Curse.lift(sword)
            assert(Forge.hexRefusal(sword) == nil, "lifting it opens the bench again")
        end,
    },
    {
        name = "an ability may be cast outside a fight, and pays for it out of a carried pool",
        fn = function()
            -- The gap this closes: Player.partyRestoratives admits consumables ONLY, on purpose, so
            -- before this there was no path in the game for a cast on a road.
            local player = Player.new()
            local priest = Character.instantiate("character_knight")
            priest.inventory = {}   -- the blueprint kit carries draughts; this case is about abilities
            priest.stats.mana = { current = 40, max = 40 }
            Character.addItem(priest, Item.instantiate("ability_lesser_rite"))
            player.roster = { priest }

            local found = Player.partyAbilities(player)
            assert(#found == 1 and found[1].item.id == "ability_lesser_rite",
                "the sweep finds an ability flagged outOfCombat")
            assert(#Player.partyRestoratives(player) == 0,
                "and the draught sweep is untouched by it -- two lists, two ways of being spent")

            local hexed = Character.instantiate("character_knight")
            hexed.inventory = {}
            local coat = Item.instantiate("armor_leather_armor")
            Character.addItem(hexed, coat)
            assert(Curse.afflict(coat, "curse_the_anchor"))

            local before = priest.stats.mana.current
            local ok, lifted = Player.castOutOfCombat(player, found[1], hexed)
            assert(ok, "the rite fires on a road")
            assert(lifted == "curse_the_anchor", "and lifts the worst hex it found")
            assert(not Curse.isCursed(coat), "the piece is clean")
            assert(priest.stats.mana.current < before, "the caster paid for it out of a carried pool")

            -- An empty pool refuses rather than half-casting, and says which pool.
            priest.stats.mana.current = 0
            local can, why = Player.canCastOutOfCombat(priest, found[1].item)
            assert(not can and why:find("mana"), "a dry caster is refused by name, got " .. tostring(why))
        end,
    },
    {
        name = "every counting item quotes its number off the same call its effect reads",
        fn = function()
            -- NAMES THE WHOLE SHELF, which is also what satisfies tests/item_coverage_spec.lua -- but
            -- the reason to write it this way is the invariant: a `counter` that read one thing and an
            -- `effect` that multiplied by another would put a number on the grid badge that the blow
            -- disagrees with, which is the one thing a live figure must never do.
            local body = hexedBody(2)
            local unit = { char = body.char }

            for _, id in ipairs({ "weapon_the_reckoning", "ability_speak_for_them",
                                  "ability_let_it_walk" }) do
                local ab = Item.instantiate(id).activeAbility
                assert(ab.counter, id .. " declares a counter")
                assert(ab.counter(unit) == 2, id .. " counts the bearer's two hexes")
                assert(ab.counterLabel, id .. " labels what the badge is counting")
            end

            -- ...and the one that reads DEPTH rather than the count, which is a different question
            -- about the same grid.
            local rouse = Item.instantiate("ability_rouse_the_binding").activeAbility
            assert(rouse.counter(unit) == 2, "The Witness is depth 2, so the readout is 2")
            assert(rouse.counterLabel == "Depth", "and it says so -- it is not counting hexes")

            -- Let It Walk is the one that GATES on the count: with nothing bound there is nothing to
            -- spend, so the cast is refused rather than fired for no effect.
            local walk = Item.instantiate("ability_let_it_walk").activeAbility
            assert(walk.counterGates ~= false, "Let It Walk needs a hex to spend")
            assert(walk.counter({ char = Character.instantiate("character_knight") }) >= 0,
                "and a clean body answers zero rather than faulting")

            -- The two charms carry their rule as a trait rather than a static bonus, because a hex
            -- count moves and a `bonus` table does not.
            for _, id in ipairs({ "utility_gathered_weight", "utility_common_burden" }) do
                local def = Item.defs[id]
                assert(def.traits and #def.traits == 1, id .. " carries exactly one live rule")
                assert(not def.bonus, id .. " must not also declare a static bonus -- it would double")
            end

            -- And the passive spreader acts between fights rather than on a cast.
            local spread = Item.defs["utility_let_it_spread"]
            assert(type(spread.encounterCleared) == "function",
                "Let It Spread is a passive on the between-fights seam")
            assert(not spread.activeAbility, "...and is never cast")
        end,
    },
    {
        name = "Rebind is a play, not a menu: a turn, a reach and an adjacency",
        fn = function()
            -- The denied draft moved hexes between grid cells from a loadout screen. What makes this
            -- version an ABILITY is that two bodies have to be standing together on somebody's turn.
            local ab = Item.instantiate("ability_rebind").activeAbility
            assert(ab.target == "ally", "it is aimed at a friend")
            assert(ab.range == 1, "at arm's length, so the two have to walk together")
            assert(#require("models.item").costs(ab) > 0, "and it is paid for")
        end,
    },
    {
        name = "no Shaman item ever lifts a curse, and both rites do",
        fn = function()
            -- THE RULING, ASSERTED OVER THE SHELF RATHER THAN OVER A LIST. "A Shaman manipulates and
            -- never removes" is a sentence in a doc and in six headers, and a sentence is the kind of
            -- implementation that stops being true without anything going red. This reads the source of
            -- every shaman blueprint and fails on the word itself.
            --
            -- Let It Walk is the one carve-out and it is named here rather than exempted quietly: it
            -- does call Curse.lift, and the binding comes back at the bell unless somebody killed the
            -- thing carrying it (Combat.releaseClaims). The Shaman still never ends one.
            local ALLOWED = { ability_let_it_walk = true }
            local paths = select(2, require("models.registry").load("data/items", "data.items"))
            local shaman, lifters = 0, {}
            for id, def in pairs(Item.defs) do
                if def.class == "shaman" then
                    shaman = shaman + 1
                    local f = paths[id] and io.open(paths[id], "r")
                    local src = f and f:read("*a") or ""
                    if f then f:close() end
                    if src:find("Curse%.lift") and not ALLOWED[id] then lifters[#lifters + 1] = id end
                end
            end
            table.sort(lifters)
            assert(shaman >= 10, "the shaman shelf is being scanned at all, found " .. shaman)
            assert(#lifters == 0,
                "a Shaman item lifts a curse, which the discipline may not do: "
                    .. table.concat(lifters, ", "))

            -- ...and the houses that MAY end one do.
            for _, id in ipairs({ "ability_lesser_rite", "ability_greater_rite" }) do
                local def = Item.defs[id]
                assert(def and def.class == "exorcist", id .. " is the Exorcist's")
                assert((def.price or 0) > 0 and (def.unlockLevel or 0) >= 7,
                    id .. " is priced and sits high on the Cathedral's rack -- lifting is earned")
            end
            assert(Item.defs.utility_consecration.curseWard, "and the ward is the third answer")
        end,
    },
}

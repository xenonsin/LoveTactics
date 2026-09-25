-- Tests for THE DWARVES OF GREED (2026-09-24, reviewed over three rounds on "The Dwarves of Greed"
-- artifact): the race, its racial rules, the line's own mechanics, the fights and the drops.
--
--   Stout          cannot be moved, cannot be robbed, goes for loose gold
--   Inheritance    a fallen dwarf's Share, coffer and Dragon-Sickness pass to the nearest within 3, or to
--                  the heir of all anywhere -- uncapped, movement floored at 1 ("Floor the movement")
--   Coin heaps     a dwarf pockets one for Dragon-Sickness (no haste: "heap stacks should not haste");
--                  the company loots one and EVERY dwarf on the board catches Gold Fever
--   Gilded         armour on a kinsman, bait on a foe, 20 gold off an enemy that falls wearing it
--   Delve          under for a turn, up beside somebody, Deeper each time; the third brings the lava
--   the Thane      Heir of All, Hire a Hand, the King's Jewel when he falls
--   the Seam       waves up through the floor, and a kill-all that waits for them
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = {
    "character_dwarf_delver", "character_dwarf_hornblower", "character_dwarf_hearthguard",
    "character_dwarf_goldsmith", "character_the_hoard_thane",
}
local TROPHIES = { "ability_delve", "ability_fools_gold", "ability_gilders_leaf", "armor_mithril_shirt" }

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function board(n) return Fixture.new(n or 11, n or 11) end

local function units(c, id)
    local out = {}
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then out[#out + 1] = u end end
    return out
end

-- A board of dwarves (enemy side) plus one company walker far away in the corner, so nothing is in reach.
local function dwarves(spec, party)
    local enemies = {}
    for _, s in ipairs(spec) do enemies[#enemies + 1] = unit(s[1], s[2], s[3]) end
    return Fixture.combat(board(), party or walker(1, 1), enemies)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the dwarf is a race that appends to a class, and it grants Stout",
        fn = function()
            local blueprint = Character.defs["character_dwarf_delver"]
            local c = Character.instantiate("character_dwarf_delver")
            assert(c.race == "dwarf" and c.kind == "humanoid", "a dwarf is a humanoid race")
            assert(c.resist.fire == 2 and c.resist.impact == -2, "forge-born, and the hammer rings the helm")
            assert(c.stats.movement == blueprint.stats.movement - 1, "short legs")
            assert(c.stats.defense == blueprint.stats.defense + 1, "thick hide")
            assert(itemNamed(c, "utility_stout"), "the race put Stout in the grid")
            for _, id in ipairs(BODIES) do
                local def = Character.defs[id]
                assert(def and def.race == "dwarf", id .. " is a dwarf")
                assert(def.class, id .. " appends to a class")
            end
            assert(Character.defs["character_dwarf_porter"] == nil, "the Porter and its strongbox are cut")
        end,
    },
    {
        name = "every new drop is an unstocked trophy the line carries, and each body drops what the review said",
        fn = function()
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def and def.unstocked and def.price == nil, id .. " is seen on the rack and never sold")
                assert(def.unlockLevel == 5 or def.unlockLevel == 6, id .. " is found on Greed's floors")
                assert(def.class ~= "creature", id .. " is a person's piece")
            end
            local drops = {
                character_dwarf_delver = "ability_delve",
                character_dwarf_hornblower = "ability_fools_gold",
                character_dwarf_goldsmith = "ability_gilders_leaf",
                character_dwarf_hearthguard = "armor_wardens_oath",
            }
            for body, id in pairs(drops) do
                assert(Character.defs[body].drops[1] == id, body .. " drops " .. id)
            end
            local thane = Character.defs["character_the_hoard_thane"].drops
            assert(thane[1] == "armor_mithril_shirt", "the Thane's own trophy is the Mithril Shirt")
            local shirt = Item.defs["armor_mithril_shirt"]
            assert(shirt.type == "armor" and shirt.bonus.movement == 0, "mithril is armor, and costs no movement")
            assert(shirt.resist.pierce > 0, "and it turns a point")
        end,
    },
    -- ------------------------------------------------------------------------------ Stout
    {
        name = "Stout: a dwarf cannot be moved and cannot be robbed",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 5, 5 } }, walker(4, 5))
            local thief, dwarf = c.units[1], units(c, "character_dwarf_delver")[1]
            assert(Status.blocksForcedMove(dwarf), "no shove, drag or throw shifts a dwarf")
            assert(Combat.steal(c, thief, dwarf) == nil, "a thief comes back empty-handed")
            assert(itemNamed(dwarf.char, "ability_delve"), "and the kit is all still there")
        end,
    },
    -- ------------------------------------------------------------------------------ Inheritance
    {
        name = "Inheritance: a fallen dwarf's Share and coffer pass to the nearest dwarf within 3",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 5, 5 }, { "character_dwarf_delver", 6, 5 },
                                { "character_dwarf_delver", 10, 10 } })
            local a, heir, far = unpack(units(c, "character_dwarf_delver"))
            local coffer = heir.coffer
            Combat.fell(c, a)
            local st = Status.get(heir, "status_inheritance")
            assert(st and st.magnitude == 1, "the nearest kinsman takes up one Share")
            assert(st.statBonus.damage == 2 and st.statBonus.defense == 2 and st.statBonus.movement == -1,
                "a Share is +2 Damage, +2 Defense, -1 Movement")
            assert(heir.coffer == coffer + 10, "and the fallen one's coffer with it")
            assert(not Status.has(far, "status_inheritance"), "a dwarf beyond 3 tiles inherits nothing")
            local bounty = c.bounty or 0
            Combat.fell(c, far)
            assert((c.bounty or 0) == bounty + 10, "a dwarf with no heir spills its coffer into the spoils")
        end,
    },
    {
        name = "Inheritance is uncapped, and the heir's movement never drops below 1",
        fn = function()
            local spec = { { "character_dwarf_delver", 5, 5 } }
            for _, xy in ipairs({ { 4, 4 }, { 5, 4 }, { 6, 4 }, { 4, 5 }, { 6, 5 }, { 4, 6 } }) do
                spec[#spec + 1] = { "character_dwarf_delver", xy[1], xy[2] }
            end
            local c = dwarves(spec)
            local all = units(c, "character_dwarf_delver")
            local heir = all[1]
            -- The heir is the one that stays nearest every fall: leave it standing, drop the rest.
            for i = 2, #all do Combat.fell(c, all[i]) end
            local st = Status.get(heir, "status_inheritance")
            assert(st and st.magnitude >= 4, "Shares keep coming past three")
            assert(st.statBonus.damage == 2 * st.magnitude, "and every one of them adds its damage")
            assert(Combat.flatStat(heir, "movement") >= 1, "but the legs stop at 1")
        end,
    },
    {
        name = "the Hoard-Thane is heir of all at any range, and his jewel makes a new one when he falls",
        fn = function()
            local c = dwarves({ { "character_the_hoard_thane", 10, 10 }, { "character_dwarf_delver", 3, 3 },
                                { "character_dwarf_delver", 4, 3 }, { "character_dwarf_delver", 9, 9 } })
            local thane = units(c, "character_the_hoard_thane")[1]
            assert(itemNamed(thane.char, "utility_the_thanes_seal"), "the office is a seal he wears")
            local d1, d2, d3 = unpack(units(c, "character_dwarf_delver"))
            Combat.fell(c, d1)
            assert(Status.stacksOf(thane, "status_inheritance") == 1, "the Share crosses the board to him")
            assert(not Status.has(d2, "status_inheritance"), "not to the kinsman standing beside it")
            local tx, ty = thane.x, thane.y
            Combat.fell(c, thane)
            local jewel = Hazard.at(c, tx, ty, "hazard_kings_jewel")
            assert(jewel, "the King's Jewel drops where he fell")
            Hazard.onEnter(c, d3, tx, ty)
            assert(d3.heirOfAll, "the first dwarf to reach it is the new heir of all")
            Combat.fell(c, d2)
            assert(Status.has(d3, "status_inheritance"), "and the next Share goes to it, wherever it stands")
        end,
    },
    -- ------------------------------------------------------------------------------ heaps
    {
        name = "a dwarf pockets a heap: gold, and a stack of Dragon-Sickness -- and no haste",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 5, 5 } })
            local dwarf = units(c, "character_dwarf_delver")[1]
            local coffer = dwarf.coffer
            Hazard.place(c, 6, 5, "hazard_coin_heap")
            Hazard.onEnter(c, dwarf, 6, 5)
            assert(dwarf.coffer == coffer + 10, "the heap's gold goes into its coffer")
            assert(Status.stacksOf(dwarf, "status_dragon_sickness") == 1, "and it takes a stack of the sickness")
            assert(not Status.has(dwarf, "status_hasted"), "heap stacks do not haste")
            assert(not Hazard.at(c, 6, 5, "hazard_coin_heap"), "and the heap is spent")
            Hazard.place(c, 7, 5, "hazard_coin_heap")
            Hazard.onEnter(c, dwarf, 7, 5)
            local sick = Status.get(dwarf, "status_dragon_sickness")
            assert(sick.magnitude == 2, "the sickness stacks, with no cap")
        end,
    },
    {
        name = "the company loots a heap: the gold is banked, and every dwarf on the board catches Gold Fever",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 3, 3 }, { "character_dwarf_delver", 10, 10 } },
                walker(6, 6))
            local looter = c.units[1]
            Hazard.place(c, 6, 7, "hazard_coin_heap")
            Hazard.onEnter(c, looter, 6, 7)
            assert((c.bounty or 0) == 10, "the heap's gold rides out with the spoils")
            for _, d in ipairs(units(c, "character_dwarf_delver")) do
                local fever = Status.get(d, "status_gold_fever")
                assert(fever and fever.taunter == looter, "every dwarf, near or far, is driven at the looter")
                local plan = AI.preempt(c, d)
                assert(plan, "and the fever overrides its own plan")
            end
        end,
    },
    {
        name = "a dwarf with nothing to hit walks for the nearest heap",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 9, 9 } })
            local dwarf = units(c, "character_dwarf_delver")[1]
            Hazard.place(c, 9, 7, "hazard_coin_heap")
            local goal = AI.nearestHeap(c, dwarf)
            assert(goal and goal.x == 9 and goal.y == 7, "the heap is the goal it would walk for")
        end,
    },
    -- ------------------------------------------------------------------------------ Gilded
    {
        name = "Gilded: an enemy that falls wearing it pays 20 gold; a company body pays nobody",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 5, 5 } }, walker(2, 2))
            local mine, dwarf = c.units[1], units(c, "character_dwarf_delver")[1]
            Status.apply(c, dwarf, "status_gilded")
            local before = c.bounty or 0
            dwarf.coffer = 0
            Combat.fell(c, dwarf)
            assert((c.bounty or 0) == before + 20, "the gilding is prised off for 20")
            Status.apply(c, mine, "status_gilded")
            local now = c.bounty or 0
            Combat.fell(c, mine)
            assert((c.bounty or 0) == now, "a gilded company body pays nothing to anybody")
        end,
    },
    {
        name = "a dwarf covets the gilded body over an equal one beside it",
        fn = function()
            local plain, gilt = walker(4, 5), walker(6, 5)
            local c = Fixture.combat(board(), { plain, gilt }, { unit("character_dwarf_delver", 5, 5) })
            local dwarf = units(c, "character_dwarf_delver")[1]
            local target = c.units[2]
            Status.apply(c, target, "status_gilded")
            local plan = AI.plan(c, dwarf)
            assert(plan and plan.target == target, "it goes for the gold with legs")
        end,
    },
    -- ------------------------------------------------------------------------------ Delve
    {
        name = "Delve: under for a turn, up on the tile, a blow to whoever is beside the exit, and Deeper",
        fn = function()
            -- Beside the exit ORTHOGONALLY: adjacency in this engine is Manhattan (Combat.cellGap).
            local c = dwarves({ { "character_dwarf_delver", 2, 8 } }, walker(6, 6))
            local foe, dwarf = c.units[1], units(c, "character_dwarf_delver")[1]
            openTurn(c, dwarf)
            local ok = Combat.useItem(c, dwarf, itemNamed(dwarf.char, "ability_delve"), 5, 6)
            assert(ok, "the delve begins")
            assert(Status.has(dwarf, "status_underground"), "and the delver is under the floor for it")
            assert(Status.untargetable(dwarf, c), "where nothing can reach it")
            local before = hp(foe)
            Combat.resolveChannel(c, dwarf)
            assert(dwarf.x == 5 and dwarf.y == 6, "it surfaces on the telegraphed tile")
            assert(not Status.has(dwarf, "status_underground"), "and is back in reach")
            assert(hp(foe) < before, "the floor comes up under the body beside the exit")
            assert(Status.stacksOf(dwarf, "status_deeper") == 1, "and it is one Deeper")
        end,
    },
    {
        name = "delved too greedily and too deep: the third Delve turns the empty ground beside it to lava",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 2, 8 } })
            local dwarf = units(c, "character_dwarf_delver")[1]
            Status.apply(c, dwarf, "status_deeper", { magnitude = 2 })
            openTurn(c, dwarf)
            assert(Combat.useItem(c, dwarf, itemNamed(dwarf.char, "ability_delve"), 5, 6))
            Combat.resolveChannel(c, dwarf)
            local lava = 0
            for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
                local cell = c.arena.tiles[6 + d[2]][5 + d[1]]
                if cell.type == "lava" and not cell.walkable then lava = lava + 1 end
            end
            assert(lava == 4, "every empty orthogonal tile runs molten, got " .. lava)
        end,
    },
    -- ------------------------------------------------------------------------------ the Thane
    {
        name = "Hire a Hand: 30 gold from his coffer puts a Delver beside him, and none without it",
        fn = function()
            local c = dwarves({ { "character_the_hoard_thane", 6, 6 } })
            local thane = units(c, "character_the_hoard_thane")[1]
            thane.coffer = 45
            openTurn(c, thane)
            assert(Combat.useItem(c, thane, itemNamed(thane.char, "ability_hire_hand"), thane.x, thane.y))
            local hands = units(c, "character_dwarf_delver")
            assert(#hands == 1 and Combat.unitGap(hands[1], thane) == 1, "a Delver surfaces beside him")
            assert(thane.coffer == 15, "and 30 gold left his coffer")
            local hire = itemNamed(thane.char, "ability_hire_hand")
            assert(not hire.activeAbility.usable(thane), "below the price, he cannot hire")
            Combat.fell(c, thane)
            assert(not hands[1].alive, "the pay stops, and the hired hand leaves with him")
        end,
    },
    {
        name = "the Mithril Shirt: never a critical, and once a fight a killing blow leaves its wearer at 1",
        fn = function()
            local shirted = unit("character_archer", 5, 5, { isolate = "bare", items = { "armor_mithril_shirt" } })
            local c = Fixture.combat(board(), shirted, { unit("character_dwarf_delver", 6, 5) })
            local wearer, dwarf = c.units[1], units(c, "character_dwarf_delver")[1]
            local weapon = itemNamed(dwarf.char, "weapon_iron_hammer")
            assert(Combat.critChance(c, dwarf, wearer, weapon) == 0, "the forecast says no critical")
            local hpBefore = hp(wearer)
            Combat.dealFlatDamage(c, wearer, hpBefore + 500, { "physical" }, "test")
            assert(wearer.alive and hp(wearer) == 1, "the troll's spear: a killing blow leaves it at 1")
            Combat.dealFlatDamage(c, wearer, 500, { "physical" }, "test")
            assert(not wearer.alive, "once a fight -- the second one lands")
        end,
    },
    -- ------------------------------------------------------------------------------ the Goldsmith
    {
        name = "the Goldsmith's Molten Assay burns a gilded body 4 harder",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 3), walker(7, 3) }, { unit("character_dwarf_goldsmith", 6, 6) })
            local a, b = c.units[1], c.units[2]
            local smith = units(c, "character_dwarf_goldsmith")[1]
            Status.apply(c, b, "status_gilded")
            local assay = itemNamed(smith.char, "ability_molten_assay")
            local pa = Combat.previewAbility(c, smith, assay, a.x, a.y)
            local pb = Combat.previewAbility(c, smith, assay, b.x, b.y)
            local da = pa and pa.entries[a] and pa.entries[a].damage
            local db = pb and pb.entries[b] and pb.entries[b].damage
            assert(da and db, "the bolt forecasts a wound on both")
            -- Gilded's +3 Defense is paid first, so "4 harder" nets to at least 1 over the plain body.
            assert(db > da, string.format("the gilded body takes more (%s against %s)", db, da))
        end,
    },
    {
        name = "Gilding Brand gilds whoever it hits",
        fn = function()
            local c = Fixture.combat(board(), walker(6, 4), { unit("character_dwarf_goldsmith", 6, 6) })
            local foe, smith = c.units[1], units(c, "character_dwarf_goldsmith")[1]
            openTurn(c, smith)
            assert(Combat.useItem(c, smith, itemNamed(smith.char, "ability_gilding_brand"), foe.x, foe.y))
            assert(Status.has(foe, "status_gilded"), "the ingot cools on it")
        end,
    },
    -- ------------------------------------------------------------------------------ the Hornblower
    {
        name = "the horn moves every dwarf a tile further; the banner arms only dwarves",
        fn = function()
            local c = dwarves({ { "character_dwarf_hornblower", 5, 5 }, { "character_dwarf_delver", 9, 9 } })
            local horn = units(c, "character_dwarf_hornblower")[1]
            local delver = units(c, "character_dwarf_delver")[1]
            openTurn(c, horn)
            assert(Combat.useItem(c, horn, itemNamed(horn.char, "ability_sound_the_horn"), horn.x, horn.y))
            assert(Status.has(delver, "status_horn_call"), "the far delver heard the horn")
            assert(Status.has(horn, "status_horn_call"), "and so did the one who blew it")
            openTurn(c, horn)
            local planted = Combat.useItem(c, horn, itemNamed(horn.char, "ability_banner_of_the_mountain"), 5, 7)
            assert(planted, "the Banner of the Mountain goes up")
            assert(Hazard.at(c, 7, 9, "hazard_mountain_banner"), "and holds ground two tiles out from it")
            Hazard.onEnter(c, delver, 7, 9)
            assert(Status.has(delver, "status_under_the_banner"), "a dwarf standing in it is under the banner")
            Hazard.onEnter(c, c.units[1], 5, 8)
            assert(not Status.has(c.units[1], "status_under_the_banner"), "the colours mean nothing to the company")
        end,
    },
    -- ------------------------------------------------------------------------------ the fights
    {
        name = "Greed's deeps are rock-walled caverns with lava pits and loose gold on the floor",
        fn = function()
            local Arena = require("models.arena")
            local Biome = require("models.biome")
            assert(Biome.defs.cave.layout == "caverns", "the caverns carve")
            local palette = Arena.BIOME_TERRAIN.cave
            assert(palette.rise == "lava" and palette.block == "mountain", "lava pits, rock walls")
            local pits, heaps = 0, 0
            for seed = 1, 12 do
                local layout = Arena.generateLayout({ seed = seed, party = 2, enemies = 2, biome = "cave" })
                for y = 1, layout.rows do
                    for x = 1, layout.cols do
                        if layout.tiles[y][x] == "lava" then pits = pits + 1 end
                    end
                end
                for _, h in ipairs(layout.hazards) do
                    if h.id == "hazard_coin_heap" then heaps = heaps + 1 end
                end
            end
            assert(pits > 0, "a deeps board opens lava pits")
            assert(heaps >= 24, "and two to four heaps on every board, saw " .. heaps .. " over twelve")
        end,
    },
    {
        name = "the deeps deal the dwarves: two fights on each floor and the Counting Hall on the seat",
        fn = function()
            local function pool(rung)
                local out = {}
                for _, row in ipairs(Encounter.pool({ biome = "cave", depth = 5, rung = rung,
                                                      quest = { sin = "greed" } })) do
                    out[row.id or row.def and row.def.id or row] = true
                end
                return out
            end
            local one, two = pool(1), pool(2)
            assert(one.encounter_greed_the_dig and one.encounter_greed_the_strongroom, "the approach deals the Dig and the Strongroom")
            assert(two.encounter_greed_the_assay_office and two.encounter_greed_the_seam, "the seat deals the Assay Office and the Seam")
            assert(two.encounter_greed_the_counting_hall, "and the Counting Hall")
            assert(Encounter.get("encounter_greed_the_counting_hall").kind == "elite", "an elite")
        end,
    },
    {
        name = "the Seam's waves come up through the floor, and its kill-all waits for them",
        fn = function()
            local seam = Encounter.get("encounter_greed_the_seam")
            local obj = seam.objective
            assert(obj and obj.type == "killAll" and #obj.waves == 2, "two waves on a kill-all")
            local c = Fixture.combat(board(), walker(6, 6), { unit("character_dwarf_delver", 1, 1) })
            c.objective = obj
            local x, y = Combat.waveArrivalTile(c, "below", "top", 1, 1)
            assert(x and math.max(math.abs(x - 6), math.abs(y - 6)) == 2, "a wave surfaces two tiles from the company")
            Combat.fell(c, units(c, "character_dwarf_delver")[1])
            c.clock = 0
            assert(Combat.outcomeFor(c, "party") == nil, "an empty board before the drums is not a win")
            c.clock = 1e9
            assert(Combat.outcomeFor(c, "party") == "win", "once both waves have come and fallen, it is")
        end,
    },
    -- ------------------------------------------------------------------------------ the Gilt Wyrm
    -- Reviewed 2026-09-25 ("Dragon-Sickness"): the sickness is the race's road to a dragon. Three stacks,
    -- however they arrived, and a dwarf becomes a Gilt Wyrm for the rest of the fight.
    {
        name = "at three stacks of Dragon-Sickness a dwarf becomes a Gilt Wyrm, and keeps its wounds and stacks",
        fn = function()
            local Transform = require("models.transform")
            local c = dwarves({ { "character_dwarf_delver", 5, 5 } })
            local dwarf = units(c, "character_dwarf_delver")[1]
            local pool = dwarf.char.stats.health
            pool.current = pool.max - 5
            for i = 1, 2 do
                Hazard.place(c, 5 + i, 5, "hazard_coin_heap")
                Hazard.onEnter(c, dwarf, 5 + i, 5)
            end
            assert(dwarf.char.id == "character_dwarf_delver", "two heaps is sick, not yet a dragon")
            Hazard.place(c, 8, 5, "hazard_coin_heap")
            Hazard.onEnter(c, dwarf, 8, 5)
            assert(dwarf.char.id == "character_gilt_wyrm", "the third heap makes a dragon of it")
            assert(Transform.originalChar(dwarf).id == "character_dwarf_delver", "the same unit, in a new body")
            assert(dwarf.char.stats.health == pool and hp(dwarf) == pool.max - 5, "its wounds came with it: no heal")
            assert(Status.stacksOf(dwarf, "status_dragon_sickness") == 3, "and every stack of the sickness")
            assert(itemNamed(dwarf.char, "weapon_gilt_maw") and itemNamed(dwarf.char, "ability_venom_breath"),
                "it bites with the Gilt Maw and breathes venom")
            assert(itemNamed(dwarf.char, "utility_stout"), "and it is still Stout: unmovable, unrobbable, gold-seeking")
            Hazard.place(c, 9, 5, "hazard_coin_heap")
            Hazard.onEnter(c, dwarf, 9, 5)
            assert(Status.stacksOf(dwarf, "status_dragon_sickness") == 4, "a wyrm still pockets gold, and still sickens")
        end,
    },
    {
        name = "a turned dwarf is a wyrm at its own level, never the blueprint's",
        fn = function()
            local Growth = require("models.growth")
            local deep = Growth.spawn("character_dwarf_delver", 12, 12)
            local c = dwarves({ { deep, 5, 5 } })
            local dwarf = c.units[2]
            local level = dwarf.char.level
            assert(level and level > 1, "a deep dwarf is fielded above level 1")
            Status.apply(c, dwarf, "status_dragon_sickness", { magnitude = 3 })
            assert(dwarf.char.id == "character_gilt_wyrm", "it turned")
            assert(dwarf.char.level == level, "the wyrm stands at the dwarf's level")
            assert(dwarf.char.stats.damage > Character.instantiate("character_gilt_wyrm").stats.damage,
                "and hits like it, not like a level-1 wyrm")
        end,
    },
    {
        name = "inherited stacks turn the heir; a company body never turns",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 5, 5 }, { "character_dwarf_delver", 6, 5 } })
            local a, heir = unpack(units(c, "character_dwarf_delver"))
            Status.apply(c, a, "status_dragon_sickness", { magnitude = 2 })
            Status.apply(c, heir, "status_dragon_sickness", { magnitude = 1 })
            Combat.fell(c, a)
            assert(heir.char.id == "character_gilt_wyrm", "a kinsman's two and its own one make three")
            local walkerUnit = c.units[1]
            Status.apply(c, walkerUnit, "status_dragon_sickness", { magnitude = 5 })
            assert(walkerUnit.char.id ~= "character_gilt_wyrm", "the company stays out of it")
        end,
    },
    {
        name = "the Hoard-Thane turns, and stays an objective and the heir of all",
        fn = function()
            local c = dwarves({ { "character_the_hoard_thane", 10, 10 }, { "character_dwarf_delver", 3, 3 } })
            local thane = units(c, "character_the_hoard_thane")[1]
            Status.apply(c, thane, "status_dragon_sickness", { magnitude = 3 })
            assert(thane.char.id == "character_gilt_wyrm", "the Thane is a dwarf, and the gold takes him too")
            assert(thane.char.boss, "still off the execute and Charm tables")
            Combat.fell(c, units(c, "character_dwarf_delver")[1])
            assert(Status.stacksOf(thane, "status_inheritance") == 1, "and his line's Shares still cross the board to him")
        end,
    },
    {
        name = "a turned dwarf pays from the wyrm's list AND its own",
        fn = function()
            local Spoils = require("models.spoils")
            local c = dwarves({ { "character_dwarf_delver", 5, 5 } })
            local dwarf = units(c, "character_dwarf_delver")[1]
            Status.apply(c, dwarf, "status_dragon_sickness", { magnitude = 3 })
            local function offers(id)
                local r = Spoils.depthOf(Item.defs[id])
                for _, e in ipairs(Spoils.rankCandidates({ dwarf }, r, {})) do
                    if e.id == id then return true end
                end
                return false
            end
            assert(offers("weapon_gram"), "the wyrm's trophies are on offer")
            assert(offers("ability_delve"), "and so is the Delver's own")
        end,
    },
    {
        name = "the Gilt Wyrm is natural kit, and its drops are six unstocked trophies",
        fn = function()
            local def = Character.defs["character_gilt_wyrm"]
            assert(def and def.race == "dragon" and not def.class, "a dragon claims no class")
            for _, id in ipairs({ "weapon_gilt_maw", "ability_venom_breath", "utility_wyrm_dread" }) do
                assert(Item.defs[id].class == "creature", id .. " is part of the body")
            end
            local want = { weapon_gram = true, armor_aegishjalmur = true, ability_wyrms_venom = true,
                utility_lindworm_heart = true, utility_linden_leaf = true, utility_every_hair_covered = true }
            local n = 0
            for _, id in ipairs(def.drops) do
                assert(want[id], id .. " was not reviewed as a wyrm drop")
                local item = Item.defs[id]
                assert(item.unstocked and item.price == nil and item.class ~= "creature", id .. " is a person's trophy")
                n = n + 1
            end
            assert(n == 6, "six drops (Andvaranaut was cut on review)")
        end,
    },
    {
        name = "Venom Breath poisons the foes in its cone and leaves Choking Fumes on its own side",
        fn = function()
            local c = dwarves({ { "character_gilt_wyrm", 5, 5 } }, walker(6, 5))
            local wyrm, foe = c.units[2], c.units[1]
            Fixture.openTurn(c, wyrm)
            local ok = Combat.useItem(c, wyrm, itemNamed(wyrm.char, "ability_venom_breath"), 6, 5)
            assert(ok, "the wyrm breathes")
            assert(Status.has(foe, "status_poison"), "the foe in the cone is poisoned")
            local fumes = Hazard.at(c, 6, 5, "hazard_choking")
            assert(fumes and fumes.side == wyrm.side, "the ground chokes, and it is the wyrm's")
            assert(fumes.remaining >= 15, "for three turns")
        end,
    },
    {
        name = "the Helm of Terror: a foe within 2 moves 2 fewer squares, and one at 3 does not",
        fn = function()
            local near = dwarves({ { "character_gilt_wyrm", 5, 5 } }, walker(7, 5))
            local far = dwarves({ { "character_gilt_wyrm", 5, 5 } }, walker(8, 5))
            local a, b = near.units[1], far.units[1]
            assert(Combat.flatStat(a, "movement") == Combat.flatStat(b, "movement") - 2, "Dread takes two squares")
            local worn = Fixture.combat(board(), unit("character_archer", 1, 1, { items = { "armor_aegishjalmur" } }),
                { unit("character_dwarf_delver", 2, 2) })
            local foe = worn.units[2]
            local alone = Fixture.combat(board(), walker(1, 1), { unit("character_dwarf_delver", 2, 2) })
            assert(Combat.flatStat(foe, "movement") == Combat.flatStat(alone.units[2], "movement") - 2,
                "and the Aegishjalmur lends the same dread to its wearer")
        end,
    },
    {
        name = "the Lindworm's Heart slips a spell as well as a blow, then waits three turns",
        fn = function()
            local Trait = require("models.trait")
            local c = Fixture.combat(board(), unit("character_archer", 1, 1, { items = { "utility_lindworm_heart" } }),
                { unit("character_dwarf_delver", 9, 9) })
            local bearer = c.units[1]
            assert(Trait.tryEvade(c, bearer, { "magical", "fire" }), "the birds warn of a spell")
            assert(not Trait.tryEvade(c, bearer, { "physical", "slash" }), "and then the warning is spent")
            assert(Combat.onCooldown(bearer, "trait_birds_warning"), "on a cooldown, not once a fight")
        end,
    },
    {
        name = "the Linden Leaf leaves exactly one physical tag open, on a badge, for the fight",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 1, 1, { items = { "utility_linden_leaf" } }),
                { unit("character_dwarf_delver", 9, 9) })
            local bearer = c.units[1]
            local open = 0
            for _, tag in ipairs({ "slash", "pierce", "impact" }) do
                if Status.has(bearer, "status_vulnerable_" .. tag) then open = open + 1 end
            end
            assert(open == 1, "one spot the leaf covered, and only one")
        end,
    },
    {
        name = "Every Hair Covered: each heap its bearer loots is another +2 Defense",
        fn = function()
            local c = dwarves({ { "character_dwarf_delver", 10, 10 } },
                unit("character_archer", 5, 5, { items = { "utility_every_hair_covered" } }))
            local looter = c.units[1]
            local before = Combat.flatStat(looter, "defense")
            for i = 1, 2 do
                Hazard.place(c, 5 + i, 5, "hazard_coin_heap")
                Hazard.onEnter(c, looter, 5 + i, 5)
            end
            assert(Status.stacksOf(looter, "status_every_hair_covered") == 2, "a stack a heap")
            assert(Combat.flatStat(looter, "defense") == before + 4, "+2 Defense each")
        end,
    },
    {
        name = "Gram: standing your ground, a foe that came to you is struck critically",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5, { items = { "weapon_gram" } }),
                { unit("character_dwarf_delver", 6, 5) })
            local bearer, foe = c.units[1], c.units[2]
            local gram = itemNamed(bearer.char, "weapon_gram")
            Fixture.openTurn(c, bearer)
            foe.turnStartX, foe.turnStartY = 9, 5
            assert(Combat.forcesCrit(c, bearer, foe, gram), "it walked onto the blade")
            foe.turnStartX, foe.turnStartY = 6, 5
            assert(not Combat.forcesCrit(c, bearer, foe, gram), "a foe that stood still gets an ordinary blow")
            foe.turnStartX, foe.turnStartY = 9, 5
            c.turn.moved = true
            assert(not Combat.forcesCrit(c, bearer, foe, gram), "and a bearer that stepped has left the pit")
        end,
    },
}

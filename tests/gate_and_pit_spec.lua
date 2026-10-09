-- Tests for THE GATE AND THE PIT ("The Crown's Bestiary", slice C, approved 2026-10-09): the Crown's hounds, Cerberus,
-- the Pit Locusts, the Reaper, and the underworld's new ground.
--
--   Hellhound      Hearth-Born: its breath leaves fire; standing in fire it heals instead of burning and hits for +3
--   Cerberus       Three Heads: up to three bites a turn, one per head; each head a third of the bar, quiet when it is
--                  gone. Honey-Cake: a Sleep, or a draught thrown at a head, quiets it for 2 turns
--   Pit Locust     Seek Death: its sting cannot take a body below 1; on a body at 1 each sting adds Torment
--   Reaper         The Harvest: a sweep of every tile around it; a foe under a quarter is downed at once
--   Lethe Shallows a body that ends its turn in the grey water forgets every status, good and bad
--
-- Each case pins a rule the review approved, on a bare board, plus the four trophies and the three fights.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Biome = require("models.biome")
local GatePit = require("models.gate_and_pit")
local Fixture = require("tests.support.fixture")

local unit, itemNamed, hp = Fixture.unit, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_hellhound = { race = "demon", tier = 2, organ = "utility_hearth_born",
        drop = "utility_hellhound_collar", class = "beastmaster" },
    character_cerberus = { race = "demon", tier = 4, organ = "utility_each_head_a_third",
        drop = "ability_three_heads", class = "vanguard" },
    character_pit_locust = { race = "demon", tier = 1, organ = "utility_seek_death",
        drop = "ability_torment", class = "plague_knight" },
    character_reaper = { race = "undead", tier = 3, organ = "utility_the_line",
        drop = "ability_the_harvest", class = "assassin" },
}
local FIGHTS = {
    encounter_crown_the_kennels = { kind = "combat", weight = 3, bodies = { character_hellhound = { 2, 3 } } },
    encounter_crown_seek_death = { kind = "combat", weight = 3,
        bodies = { character_reaper = { 1, 1 }, character_pit_locust = { 2, 3 } } },
    encounter_crown_cerberus = { kind = "elite", weight = 2,
        bodies = { character_cerberus = { 1, 1 }, character_hellhound = { 1, 2 } } },
}

local function board(n) return Fixture.new(n or 12, n or 12) end

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 100, health or 100
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function headsOf(c, body) return Combat.headsOf(c, body) end

local function setHp(u, n) u.char.stats.health.current = n end

local function hit(c, target, amount, attacker)
    return Combat.dealFlatDamage(c, target, amount, { "physical" }, "test", attacker, { raw = true })
end

local function count(list, id)
    local n = 0
    for _, v in ipairs(list) do if v == id then n = n + 1 end end
    return n
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "five bodies of the pit, each with its organ, and four trophies on real shelves",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == want.race, id .. " is " .. want.race)
                assert(def.race ~= "human", id .. " is never human")
                assert(def.tier == want.tier, id .. " stands on tier " .. want.tier)
                local c = Character.instantiate(id)
                assert(itemNamed(c, want.organ), id .. " carries " .. want.organ)
                assert(def.drops and def.drops[1] == want.drop, id .. " drops " .. want.drop)
                local drop = Item.defs[want.drop]
                assert(drop.class == want.class, want.drop .. " is " .. want.class .. " stock")
                assert(drop.unstocked and not drop.price, want.drop .. " is a trophy: on the rack, never sold")
                assert(drop.unlockLevel == 15, want.drop .. " sits at the Crown's rung")
                local organ = Item.defs[want.organ]
                assert(organ.class == "creature" and organ.noSteal and organ.bound, want.organ .. " is a body's own")
            end
            local reaper = Character.defs["character_reaper"]
            local n = 0
            for _, e in ipairs(reaper.startingItems) do if e then n = n + 1 end end
            assert(n >= 3, "the Reaper is tier 3 and carries at least three items")
            -- The demons' blows burn; the Reaper's does not, being no demon.
            for _, id in ipairs({ "weapon_hellhound_bite", "weapon_three_mouths", "weapon_pit_locust_sting" }) do
                local tags = {}
                for _, t in ipairs(Item.defs[id].tags) do tags[t] = true end
                assert(tags.fire and tags.physical, id .. " is a demon's blow: it burns, as a physical blow")
            end
            assert(Character.defs["character_cerberus"].boss, "Cerberus is off the execute and Charm tables")
            assert(Character.defs["character_cerberus_head"].timeless, "a head takes no turn of its own")
            local dog = Character.instantiate("character_cerberus")
            local heads = 0
            for i = 1, Character.MAX_INVENTORY do
                local it = dog.inventory[i]
                if it and it.id == "utility_cerberus_head" then heads = heads + 1 end
            end
            assert(heads == 3, "Cerberus grows its three heads off three utility_cerberus_head pieces")
            assert(Item.defs["utility_cerberus_head"].head == "character_cerberus_head", "each grows a head")
            assert(itemNamed(Character.instantiate("character_cerberus_head"), "utility_honey_cake"),
                "a head carries utility_honey_cake")
            assert(Status.defs["status_torment"].name == "Torment", "the new status is named Torment")
        end,
    },
    {
        name = "three fights on the Crown's floor: underworld-locked, no rung, and the approved counts",
        fn = function()
            for id, want in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == want.kind, id .. " is " .. want.kind)
                assert(e.weight == want.weight, id .. " weighs " .. want.weight)
                assert(e.rung == nil, id .. " carries no rung: the ground is the pin")
                assert(e.condition({ biome = "underworld" }) and not e.condition({ biome = "cave" }),
                    id .. " is underworld-locked")
                local seen = {}
                for seed = 1, 40 do
                    local comp = e.composition({ biome = "underworld", depth = 15, seed = seed * 7919 })
                    for body, range in pairs(want.bodies) do
                        local n = count(comp, body)
                        assert(n >= range[1] and n <= range[2], string.format("%s fields %d %s, wants %d-%d",
                            id, n, body, range[1], range[2]))
                        seen[body .. n] = true
                    end
                    if want.kind == "combat" then assert(#comp <= 4, id .. " stays inside a skirmish's four") end
                end
                for body, range in pairs(want.bodies) do
                    assert(seen[body .. range[1]] and seen[body .. range[2]], id .. " rolls the whole band of " .. body)
                end
            end
        end,
    },
    -- ------------------------------------------------------------------------------ Lethe Shallows
    {
        name = "the Lethe Shallows: ending a turn in the water forgets every status, good and bad; wading costs nothing",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 5), { walker(9, 9) })
            local body = c.units[1]
            for _, id in ipairs({ "status_burn", "status_poison", "status_root", "status_blessing", "status_hasted" }) do
                Status.apply(c, body, id)
            end
            assert(#body.statuses >= 5, "the body carries five statuses")
            Hazard.place(c, 5, 5, "hazard_lethe_shallows")
            for _, id in ipairs({ "status_burn", "status_root", "status_blessing" }) do
                assert(Status.has(body, id), "stepping in forgets nothing: " .. id)
            end
            Fixture.openTurn(c, body)
            Combat.wait(c, body)
            for _, id in ipairs({ "status_burn", "status_poison", "status_root", "status_blessing", "status_hasted" }) do
                assert(not Status.has(body, id), "the turn's end in the water forgets " .. id)
            end
            -- ...and it forgets nothing for a body that ended its turn beside it.
            local c2 = Fixture.combat(board(), walker(5, 5), { walker(9, 9) })
            local b2 = c2.units[1]
            Status.apply(c2, b2, "status_blessing")
            Hazard.place(c2, 6, 5, "hazard_lethe_shallows")
            Fixture.openTurn(c2, b2)
            Combat.wait(c2, b2)
            assert(Status.has(b2, "status_blessing"), "dry ground remembers")
        end,
    },
    {
        name = "the Lethe Shallows replace the spoil heap, and land live on a real underworld fight board",
        fn = function()
            assert(Biome.hazardFor("underworld").id == "hazard_lethe_shallows", "the underworld seeds the Lethe")
            assert(Hazard.defs["hazard_spoil_heap"], "the spoil heap's own file is left alone")
            -- Pride's Exposure once shipped placed and inert. So build the fight the way the game does, and use the
            -- water it laid: it is there, it is not on a clock that runs out mid-fight, and it forgets.
            local EncounterBattle = require("models.encounter_battle")
            local found = 0
            for seed = 1, 4 do
                local built = EncounterBattle.build({ encounter = Encounter.get("encounter_crown_the_kennels"),
                    biome = "underworld", depth = 15, seed = seed * 104729 })
                local c = built.combat
                local pool
                for _, h in ipairs(c.hazards or {}) do
                    if h.id == "hazard_lethe_shallows" and h.alive then pool = h end
                end
                if pool then
                    found = found + 1
                    assert((pool.remaining or 0) > 1000, "the water does not dry up mid-fight")
                    local hound = one(c, "character_hellhound")
                    hound.x, hound.y = pool.x, pool.y
                    Status.apply(c, hound, "status_hasted")
                    Hazard.onTurnEnd(c, hound)
                    assert(not Status.has(hound, "status_hasted"), "the laid water forgets, on a real board")
                end
            end
            assert(found >= 3, "the underworld lays its water on its fight boards (" .. found .. " of 4)")
        end,
    },
    -- ------------------------------------------------------------------------------ Hearth-Born
    {
        name = "Hearth-Born: fire does not burn a hound, it hits 3 harder in it and heals 4 a turn there; Wet puts it out",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_hellhound", 5, 5) })
            local hound = one(c, "character_hellhound")
            local dry = Combat.flatStat(hound, "damage")
            Hazard.place(c, 5, 5, "hazard_fire")
            assert(not Status.has(hound, "status_burn"), "the fire does not burn it")
            assert(Combat.flatStat(hound, "damage") == dry + 3, "standing in fire it hits for +3")
            setHp(hound, 30)
            Fixture.openTurn(c, hound)
            Combat.wait(c, hound)
            assert(hp(hound) == 34, "a turn ended in fire heals it 4, got " .. hp(hound))

            Status.apply(c, hound, "status_wet")
            assert(Combat.flatStat(hound, "damage") == dry, "Wet: no +3")
            Fixture.openTurn(c, hound)
            Combat.wait(c, hound)
            assert(hp(hound) <= 34, "Wet: no heal")
            assert(not GatePit.fireproof(hound), "Wet: the fire is just fire")
        end,
    },
    {
        name = "Hearth-Born: the breath burns a 2-tile cone and leaves the ground alight",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6), { unit("character_hellhound", 5, 5) })
            local foe, hound = c.units[1], one(c, "character_hellhound")
            local ok, why = Fixture.strike(c, hound, foe, "ability_hellfire_breath")
            assert(ok, "it breathes: " .. tostring(why))
            for _, cell in ipairs({ { 5, 6 }, { 4, 7 }, { 5, 7 }, { 6, 7 } }) do
                assert(Hazard.at(c, cell[1], cell[2], "hazard_fire"), "fire on " .. cell[1] .. "," .. cell[2])
            end
            assert(not Hazard.at(c, 5, 8, "hazard_fire"), "two tiles deep and no deeper")
            assert(Status.has(foe, "status_burn"), "the foe in the cone burns")
        end,
    },
    {
        name = "the Hellhound Collar: the bearer's summons walk through fire unharmed and heal 3 a turn in it",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_archer", 2, 2, { isolate = "bare", items = { "utility_hellhound_collar" } }),
                { walker(10, 10) })
            local master = c.units[1]
            local wolf = require("models.summon").spawn(c, master, "character_wolf_grunt", 5, 5, { announce = false })
            assert(wolf, "a summon stands")
            Hazard.place(c, 5, 5, "hazard_fire")
            assert(not Status.has(wolf, "status_burn"), "the summon is unharmed by the fire")
            setHp(wolf, 5)
            require("models.trait").onAnyTurnEnd(c, wolf)
            assert(hp(wolf) == 8, "and heals 3 for a turn ended in it, got " .. hp(wolf))
            assert(Combat.flatStat(wolf, "damage") == Combat.flatStat(wolf, "damage"), "(no +3 is promised)")
            local stranger = c.units[2]
            assert(not GatePit.fireproof(stranger), "a body that is not the bearer's summon gets nothing")
        end,
    },
    -- ------------------------------------------------------------------------------ Cerberus
    {
        name = "Three Heads: three heads hold a third of the bar each, and the bar is their sum",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_cerberus", 5, 5, { stats = { health = 300 } }) })
            local dog = one(c, "character_cerberus")
            local heads = headsOf(c, dog)
            assert(#heads == 3, "three heads grow at the bell")
            for _, h in ipairs(heads) do
                assert(h.char.stats.health.max == 100 and hp(h) == 100, "each head holds a third")
                assert(h.timeless and not Combat.inTimeline(h), "a head takes no turn of its own")
            end
            assert(dog.char.stats.health.max == 300 and hp(dog) == 300, "the body's bar is the three")
        end,
    },
    {
        name = "Three Heads: a blow on the body lands on the fullest head; an aimed blow breaks the head you chose",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_cerberus", 5, 5, { stats = { health = 300 } }) })
            local dog = one(c, "character_cerberus")
            local a, b, d = headsOf(c, dog)[1], headsOf(c, dog)[2], headsOf(c, dog)[3]
            hit(c, a, 30)
            assert(hp(a) == 70 and hp(dog) == 270, "a head's wound is the body's")
            hit(c, dog, 20)
            assert(hp(a) == 70 and (hp(b) == 80 or hp(d) == 80), "a blow on the body lands on a full head")
            assert(hp(dog) == 250, "and the body reads the sum")
            hit(c, a, 500)
            assert(not a.alive, "the head you chose is broken")
            assert(hp(dog) == 180, "its third is gone from the bar, got " .. hp(dog))
            assert(#GatePit.awake(c, dog) == 2, "and it goes quiet: two heads left to bite")
            hit(c, dog, 500)
            hit(c, dog, 500)
            assert(not dog.alive, "the last head lost fells the dog")
        end,
    },
    {
        name = "Three Heads: one bite per head awake, each on a different body beside it",
        fn = function()
            -- The dog's cells are 5..6 x 5..6; three bodies stand beside it.
            local c = Fixture.combat(board(), { walker(4, 5), walker(7, 5), walker(5, 7) },
                { unit("character_cerberus", 5, 5, { stats = { health = 300, damage = 20 } }) })
            local x, y, z = c.units[1], c.units[2], c.units[3]
            local dog = one(c, "character_cerberus")
            local ok, why = Fixture.strike(c, dog, x, "weapon_three_mouths")
            assert(ok, "it bites: " .. tostring(why))
            assert(hp(x) < 100 and hp(y) < 100 and hp(z) < 100, "three heads, three bodies bitten")

            local c2 = Fixture.combat(board(), { walker(4, 5), walker(7, 5), walker(5, 7) },
                { unit("character_cerberus", 5, 5, { stats = { health = 300, damage = 20 } }) })
            local x2, y2, z2 = c2.units[1], c2.units[2], c2.units[3]
            local dog2 = one(c2, "character_cerberus")
            local heads = headsOf(c2, dog2)
            GatePit.quiet(c2, heads[1])
            hit(c2, heads[2], 500)
            Fixture.strike(c2, dog2, x2, "weapon_three_mouths")
            local bitten = 0
            for _, u in ipairs({ x2, y2, z2 }) do if hp(u) < 100 then bitten = bitten + 1 end end
            assert(bitten == 1, "one head asleep and one broken: one bite, got " .. bitten)

            local c3 = Fixture.combat(board(), walker(4, 5),
                { unit("character_cerberus", 5, 5, { stats = { health = 300, damage = 20 } }) })
            local only = c3.units[1]
            Fixture.strike(c3, one(c3, "character_cerberus"), only, "weapon_three_mouths")
            assert(hp(only) < 100 and hp(only) > 100 - 3 * 40, "one body beside it is bitten once, not three times")
        end,
    },
    {
        name = "Honey-Cake: a Sleep or a draught thrown at a head quiets that head for 2 turns",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_archer", 4, 5, { isolate = "bare", items = { "consumable_throwing_stone" } }),
                { unit("character_cerberus", 5, 5, { stats = { health = 300 } }) })
            local thrower, dog = c.units[1], one(c, "character_cerberus")
            local heads = headsOf(c, dog)
            Status.apply(c, heads[1], "status_sleep")
            local s = Status.get(heads[1], "status_sleep")
            assert(s and s.remaining == 10, "a Sleep on a head lasts two turns")
            assert(#GatePit.awake(c, dog) == 2, "and that head is quiet")

            Fixture.openTurn(c, thrower)
            local ok, why = Combat.useItemOnHead(c, thrower, itemNamed(thrower.char, "consumable_throwing_stone"), heads[2])
            assert(ok, "the draught is thrown at the head: " .. tostring(why))
            assert(Status.has(heads[2], "status_sleep"), "a draught thrown at a head puts it under")
            assert(#GatePit.awake(c, dog) == 1, "two heads quiet, one awake")
        end,
    },
    -- ------------------------------------------------------------------------------ Seek Death
    {
        name = "Seek Death: a sting never takes a body below 1, and on a body at 1 it adds Torment",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6, 10),
                { unit("character_pit_locust", 5, 5, { stats = { damage = 40 } }) })
            local body, locust = c.units[1], one(c, "character_pit_locust")
            Fixture.strike(c, locust, body, "weapon_pit_locust_sting")
            assert(body.alive and hp(body) == 1, "held at 1, got " .. hp(body))
            assert(not Status.has(body, "status_torment"), "a body above 1 is not Tormented by the blow that brought it there")
            local dmg = Combat.flatStat(body, "damage")
            local mov = Combat.flatStat(body, "movement")
            Fixture.strike(c, locust, body, "weapon_pit_locust_sting")
            Fixture.strike(c, locust, body, "weapon_pit_locust_sting")
            assert(body.alive and hp(body) == 1, "still at 1")
            assert(Status.stacksOf(body, "status_torment") == 2, "each sting at 1 adds a stack")
            assert(Combat.flatStat(body, "damage") == dmg - 6, "-3 Damage a stack")
            assert(Combat.flatStat(body, "movement") == mov - 2, "-1 Movement a stack")
            Combat.cleanse(c, body)
            assert(not Status.has(body, "status_torment"), "a Cure lifts it")
        end,
    },
    {
        name = "the Torment ability: a strike that holds at 1 and lays Torment on any foe",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_knight", 5, 6, { isolate = "bare", items = { "ability_torment" }, stats = { damage = 80 } }),
                { walker(5, 5, 30) })
            local knight, foe = c.units[1], c.units[2]
            local ok, why = Fixture.strike(c, knight, foe, "ability_torment")
            assert(ok, "it strikes: " .. tostring(why))
            assert(foe.alive and hp(foe) == 1, "held at 1, got " .. hp(foe))
            assert(Status.stacksOf(foe, "status_torment") == 1, "and Tormented")
        end,
    },
    -- ------------------------------------------------------------------------------ The Harvest
    {
        name = "The Harvest: the sweep takes the whole ring, downs a foe under a quarter, and leaves its own side",
        fn = function()
            local c = Fixture.combat(board(), { walker(4, 4), walker(6, 6), walker(5, 7) },
                { unit("character_reaper", 5, 5), unit("character_pit_locust", 4, 5) })
            local weak, whole, far = c.units[1], c.units[2], c.units[3]
            local reaper, locust = one(c, "character_reaper"), one(c, "character_pit_locust")
            setHp(weak, 25)
            local locustHp = hp(locust)
            -- Aimed at an empty tile beside it: the sweep is the whole ring whichever tile was aimed at.
            Fixture.openTurn(c, reaper)
            local ok, why = Combat.useItem(c, reaper, itemNamed(reaper.char, "weapon_reapers_scythe"), 5, 4)
            assert(ok, "it sweeps: " .. tostring(why))
            assert(not weak.alive, "a foe at a quarter is downed at once, corner and all")
            assert(whole.alive and hp(whole) < 100, "a foe above the line takes the sweep")
            assert(hp(far) == 100, "two tiles off is outside the ring")
            assert(hp(locust) == locustHp, "its own side is not swept")
        end,
    },
    {
        name = "The Harvest: the line is drawn while a Reaper stands, and the Assassin's sweep reaps too",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_reaper", 5, 5) })
            assert(GatePit.line(c) == 0.25, "a Reaper on the board: the line is at a quarter")
            hit(c, one(c, "character_reaper"), 9999)
            assert(GatePit.line(c) == nil, "and gone with it")

            local c2 = Fixture.combat(board(),
                unit("character_archer", 5, 5, { isolate = "bare", items = { "ability_the_harvest" } }),
                { walker(4, 4), walker(6, 5) })
            local assassin, weak, whole = c2.units[1], c2.units[2], c2.units[3]
            setHp(weak, 20)
            Fixture.openTurn(c2, assassin)
            local ok, why = Combat.useItem(c2, assassin, itemNamed(assassin.char, "ability_the_harvest"), 5, 5)
            assert(ok, "it sweeps: " .. tostring(why))
            assert(not weak.alive, "the foe under a quarter is downed")
            assert(whole.alive and hp(whole) < 100, "the whole one is swept")
        end,
    },
    -- ------------------------------------------------------------------------------ the Vanguard's Three Heads
    {
        name = "the Three Heads ability: a free breath, then one swing strikes three foes beside you",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_knight", 5, 5, { isolate = "bare", items = { "ability_three_heads", "weapon_iron_sword" } }),
                { walker(4, 5), walker(6, 5), walker(5, 4), walker(5, 9) })
            local v, a, b, d, far = c.units[1], c.units[2], c.units[3], c.units[4], c.units[5]
            Fixture.openTurn(c, v)
            local ok, why = Combat.useItem(c, v, itemNamed(v.char, "ability_three_heads"), 5, 5)
            assert(ok, "it is called: " .. tostring(why))
            assert(Status.has(v, "status_three_heads"), "Three Heads is worn")
            assert(c.turn and c.turn.unit == v, "and the turn is still open: it was free")
            ok, why = Combat.useItem(c, v, itemNamed(v.char, "weapon_iron_sword"), a.x, a.y)
            assert(ok, "the swing: " .. tostring(why))
            assert(hp(a) < 100 and hp(b) < 100 and hp(d) < 100, "three foes beside you are struck")
            assert(hp(far) == 100, "and nobody else")
            assert(not Status.has(v, "status_three_heads"), "the swing spent it")
        end,
    },
}

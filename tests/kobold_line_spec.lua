-- Tests for THE KOBOLDS OF GREED (2026-09-24/25, reviewed over two rounds on "The Kobolds of Greed"
-- artifact): the race, its rules, the dragons they worship, the line's own mechanics, the fights and the
-- drops. "Kobolds don't care about gold" decided the line; nothing here touches a heap.
--
--   Pack          +2 per other kobold beside the target, to +6
--   Devotion      the Dragon's Eye within 3 of a dragon; a dragon struck is Fervor, destroyed is Forsaken
--   the eggs      brooded by whoever ends a turn beside them; three and a Wyrmling hatches
--   the Godling   the Tithe (a worshipper beside it is eaten, for Glut), the Bare Patch (a critical
--                 strips it all)
--   the kit       Scurry + Harry, the Deadfall, Borrowed Breath, Dragon's Call, the Dragon Egg drop, the
--                 Godling's Scale
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Devotion = require("models.devotion")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local KOBOLDS = {
    "character_kobold_skulker", "character_kobold_trapwright", "character_kobold_broodkeeper",
    "character_kobold_scale_priest", "character_kobold_devotee",
}
local TROPHIES = { "utility_scurry", "ability_deadfall", "ability_dragon_egg", "ability_borrowed_breath",
                   "utility_godlings_scale" }
local FIGHTS = {
    encounter_greed_the_warren = 1, encounter_greed_the_clutch = 1,
    encounter_greed_the_choir = 2, encounter_greed_the_deadfall_run = 2, encounter_greed_the_nest = 2,
}

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

local function one(c, id) return units(c, id)[1] end

-- A board of kobolds and dragons (enemy side) plus a company walker far away in the corner.
local function nest(spec, party)
    local enemies = {}
    for _, s in ipairs(spec) do enemies[#enemies + 1] = unit(s[1], s[2], s[3], s[4]) end
    return Fixture.combat(board(), party or walker(1, 1), enemies)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the kobold is a quick race that appends to a class, and it grants Underfoot",
        fn = function()
            local blueprint = Character.defs["character_kobold_skulker"]
            local c = Character.instantiate("character_kobold_skulker")
            assert(c.race == "kobold" and c.kind == "humanoid", "a kobold is a humanoid race")
            assert(c.resist.slash == -2 and c.resist.pierce == 1 and c.resist.impact == 1,
                "a blade opens thin scales; a point and a hammer are turned")
            assert(c.resist.fire == nil, "no element: the dwarves of this circle already take fire")
            assert(c.stats.movement == blueprint.stats.movement + 1, "quick feet")
            assert(c.stats.speed == blueprint.stats.speed + 1, "and quick to act")
            assert(itemNamed(c, "utility_underfoot"), "the race put Underfoot in the grid")
            for _, id in ipairs(KOBOLDS) do
                local def = Character.defs[id]
                assert(def and def.race == "kobold", id .. " is a kobold")
                assert(def.class, id .. " appends to a class")
            end
            local underfoot = Item.defs["utility_underfoot"]
            assert(underfoot.bound and underfoot.noSteal, "Underfoot is an organ, never kit")
        end,
    },
    {
        name = "the dragons are a race of their own, and the egg is an object that takes no turns",
        fn = function()
            for _, id in ipairs({ "character_wyrmling", "character_the_godling" }) do
                local c = Character.instantiate(id)
                assert(c.race == "dragon" and c.kind == "beast", id .. " is a dragon, and a creature to the item rules")
                assert(c.resist.fire == 2, id .. ": fire runs off every dragon")
                assert(itemNamed(c, "utility_dragonblood"), id .. " carries Dragonblood")
            end
            local egg = Character.instantiate("character_dragon_egg")
            assert(egg.kind == "object" and egg.timeless, "the egg is an object outside the turn order")
            assert(itemNamed(egg, "utility_dragonblood") and itemNamed(egg, "utility_the_clutch"),
                "and it is a dragon that broods")
            local c = nest({ { "character_dragon_egg", 6, 6 } })
            local e = one(c, "character_dragon_egg")
            assert(e.timeless and not Combat.inTimeline(e), "an egg dealt into the opening line takes no turn")
            assert(Devotion.isDragon(e), "and a kobold reads it as a dragon")
        end,
    },
    {
        name = "every new drop is an unstocked trophy, and each body drops what the review said",
        fn = function()
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def and def.unstocked and def.price == nil, id .. " is seen on the rack and never sold")
                assert(def.unlockLevel == 5 or def.unlockLevel == 6, id .. " is found on Greed's floors")
                assert(def.class ~= "creature", id .. " is a person's piece")
            end
            local drops = {
                character_kobold_skulker = "utility_scurry",
                character_kobold_trapwright = "ability_deadfall",
                character_kobold_broodkeeper = "ability_dragon_egg",
                character_kobold_scale_priest = "ability_borrowed_breath",
                character_the_godling = "utility_godlings_scale",
            }
            for body, id in pairs(drops) do
                assert(Character.defs[body].drops[1] == id, body .. " drops " .. id)
            end
            assert(Item.defs["ability_tripline"] == nil, "the Tripline was denied on the body and the drop")
        end,
    },
    -- ------------------------------------------------------------------------------ Pack
    {
        name = "Pack: +2 for every other kobold beside the target, to +6, and only kobolds count",
        fn = function()
            local c = nest({ { "character_kobold_skulker", 4, 5 }, { "character_kobold_skulker", 6, 5 },
                             { "character_kobold_skulker", 5, 4 }, { "character_kobold_skulker", 9, 9 } },
                           walker(5, 5))
            local target = c.units[1]
            local sk = units(c, "character_kobold_skulker")
            local striker = sk[1]
            local spear = itemNamed(striker.char, "weapon_iron_spear")
            assert(Trait.outgoingDamageBonus(c, striker, target, spear) == 4, "two kin beside the target: +4")
            sk[4].x, sk[4].y = 5, 6
            assert(Trait.outgoingDamageBonus(c, striker, target, spear) == 6, "three kin: +6")
            local extra = Combat.addUnit(c, Character.instantiate("character_kobold_skulker"), "enemy", 4, 4)
            assert(extra and Trait.outgoingDamageBonus(c, striker, target, spear) == 6, "and never past +6")
            local lone = nest({ { "character_kobold_skulker", 4, 5 }, { "character_dwarf_delver", 6, 5 } },
                              walker(5, 5))
            local k = one(lone, "character_kobold_skulker")
            assert(Trait.outgoingDamageBonus(lone, k, lone.units[1], itemNamed(k.char, "weapon_iron_spear")) == 0,
                "a dwarf beside the target is no kobold's packmate")
        end,
    },
    -- ------------------------------------------------------------------------------ Devotion
    {
        name = "the Dragon's Eye: within 3 of a dragon a kobold gains damage and defense, and it does not stack",
        fn = function()
            local c = nest({ { "character_kobold_skulker", 5, 5 }, { "character_kobold_skulker", 10, 10 } })
            local near, far = unpack(units(c, "character_kobold_skulker"))
            local base, baseDef = Combat.flatStat(near, "damage"), Combat.flatStat(near, "defense")
            assert(Combat.flatStat(far, "damage") == base, "two kobolds off one blueprint, before any dragon")
            Combat.addUnit(c, Character.instantiate("character_dragon_egg"), "enemy", 5, 8, { timeless = true })
            assert(Combat.flatStat(near, "damage") == base + 2, "three tiles from the egg: +2 damage")
            assert(Combat.flatStat(near, "defense") == baseDef + 1, "and +1 defense")
            assert(Combat.flatStat(far, "damage") == base, "a kobold far from any dragon fights without the Eye")
            Combat.addUnit(c, Character.instantiate("character_dragon_egg"), "enemy", 5, 6, { timeless = true })
            assert(Combat.flatStat(near, "damage") == base + 2, "two eggs are one god")
        end,
    },
    {
        name = "a dragon struck drives the kobolds who see it to Fervor; destroyed, they are Forsaken and cannot rally",
        fn = function()
            local c = nest({ { "character_dragon_egg", 5, 5 }, { "character_kobold_skulker", 5, 8 },
                             { "character_dragon_egg", 8, 8 } })
            local egg, other = unpack(units(c, "character_dragon_egg"))
            local sk = one(c, "character_kobold_skulker")
            egg.char.stats.health.max, egg.char.stats.health.current = 100, 100
            Combat.dealFlatDamage(c, egg, 5, { "physical" }, "test")
            assert(egg.alive and Status.has(sk, "status_fervor"), "a blow the egg survives rallies the kobold that saw it")
            Combat.fell(c, egg)
            assert(Status.has(sk, "status_forsaken"), "smashed, and the kobold that saw it is Forsaken")
            assert(not Status.has(sk, "status_fervor"), "and its Fervor is gone with the god")
            other.char.stats.health.max, other.char.stats.health.current = 100, 100
            Combat.dealFlatDamage(c, other, 5, { "physical" }, "test")
            assert(not Status.has(sk, "status_fervor"), "a Forsaken kobold cannot be rallied")
        end,
    },
    -- ------------------------------------------------------------------------------ the eggs
    {
        name = "an ally ending its turn beside an egg broods it; three broodings hatch a Wyrmling on its tile",
        fn = function()
            local c = nest({ { "character_dragon_egg", 5, 5 }, { "character_kobold_broodkeeper", 5, 6 },
                             { "character_kobold_skulker", 9, 9 } })
            local egg, keeper = one(c, "character_dragon_egg"), one(c, "character_kobold_broodkeeper")
            local far = one(c, "character_kobold_skulker")
            Trait.onAnyTurnEnd(c, far)
            assert(Status.stacksOf(egg, "status_brood") == 0, "a kobold across the room broods nothing")
            Trait.onAnyTurnEnd(c, keeper)
            assert(Status.stacksOf(egg, "status_brood") == 1, "one brooding")
            Trait.onAnyTurnEnd(c, c.units[1])
            assert(Status.stacksOf(egg, "status_brood") == 1, "the company does not brood the kobolds' egg")
            -- Wired, not just written: a real turn ending (Combat.wait) broods it too.
            openTurn(c, keeper)
            Combat.wait(c, keeper)
            assert(Status.stacksOf(egg, "status_brood") == 2, "a turn waited beside the egg is a brooding")
            Trait.onAnyTurnEnd(c, keeper)
            assert(not egg.alive and egg.hatched, "at three the egg hatches")
            local wyrm = one(c, "character_wyrmling")
            assert(wyrm and wyrm.alive and wyrm.x == 5 and wyrm.y == 5 and wyrm.side == "enemy",
                "and a Wyrmling stands on its tile, on its side")
            assert(not wyrm.summoned, "an enemy hatchling is a body in its own right: the kill-all waits for it")
            assert(not Status.has(keeper, "status_forsaken"), "a hatching is the god arriving, not the god falling")
        end,
    },
    {
        name = "the Broodkeeper's post is AT the egg, not two tiles from it",
        fn = function()
            local c = nest({ { "character_dragon_egg", 5, 5 }, { "character_kobold_broodkeeper", 9, 9 } })
            local keeper = one(c, "character_kobold_broodkeeper")
            local post = AI.post(c, keeper)
            assert(post and post.radius == 1, "guardRadius 1 holds the post beside the egg")
            assert(post.tiles[1].x == 5 and post.tiles[1].y == 5, "and the post is the egg")
        end,
    },
    -- ------------------------------------------------------------------------------ the Godling
    {
        name = "the Tithe: a kobold ending its turn beside the Godling is eaten, and it heals and takes Glut",
        fn = function()
            local c = nest({ { "character_the_godling", 5, 5 }, { "character_kobold_devotee", 5, 6 },
                             { "character_wyrmling", 6, 5 }, { "character_kobold_devotee", 9, 9 } })
            local god = one(c, "character_the_godling")
            local devotee, far = unpack(units(c, "character_kobold_devotee"))
            local wyrm = one(c, "character_wyrmling")
            local hpc = god.char.stats.health
            hpc.current = math.floor(hpc.max / 2)
            local before = hpc.current
            Trait.onAnyTurnEnd(c, devotee)
            assert(not devotee.alive and devotee.devoured, "the worshipper is devoured whole")
            assert(Status.stacksOf(god, "status_glut") == 1, "a stack of Glut")
            assert(hp(god) > before, "and the Godling heals")
            Trait.onAnyTurnEnd(c, wyrm)
            assert(wyrm.alive and Status.stacksOf(god, "status_glut") == 1, "a Wyrmling beside it is not a worshipper")
            Trait.onAnyTurnEnd(c, far)
            assert(far.alive, "a kobold across the room is not eaten")
        end,
    },
    {
        name = "the Bare Patch: a critical strips every stack of Glut; an ordinary blow strips none",
        fn = function()
            local c = nest({ { "character_the_godling", 5, 5 } }, walker(5, 6))
            local god = one(c, "character_the_godling")
            Status.apply(c, god, "status_glut", { magnitude = 3 })
            assert(Status.stacksOf(god, "status_glut") == 3, "three worshippers eaten")
            Combat.dealFlatDamage(c, god, 5, { "physical" }, "test", c.units[1])
            assert(Status.stacksOf(god, "status_glut") == 3, "an ordinary blow finds scale")
            Combat.dealFlatDamage(c, god, 5, { "physical" }, "test", c.units[1], { critical = true })
            assert(god.alive and Status.stacksOf(god, "status_glut") == 0, "a critical finds the bare patch")
        end,
    },
    {
        name = "a Devotee walks to its dragon and never swings; beside it, it holds",
        fn = function()
            local c = nest({ { "character_the_godling", 9, 5 }, { "character_kobold_devotee", 3, 5 } }, walker(3, 6))
            local devotee = one(c, "character_kobold_devotee")
            openTurn(c, devotee)
            local plan = AI.plan(c, devotee)
            assert(plan and not plan.item, "it never acts against the company standing beside it")
            assert(plan.move and plan.move.x > devotee.x, "it walks toward the Godling")
            devotee.x = 8
            openTurn(c, devotee)
            local held = AI.plan(c, devotee)
            assert(not (held and held.move), "beside its god, it stays to be eaten")
        end,
    },
    -- ------------------------------------------------------------------------------ the kit
    {
        name = "Scurry: after a melee blow the Skulker steps back, and the foe it struck is Harried until the next blow",
        fn = function()
            local c = nest({ { "character_kobold_skulker", 5, 6 } }, walker(5, 5))
            local sk, foe = one(c, "character_kobold_skulker"), c.units[1]
            local ok = Fixture.strike(c, sk, foe, "weapon_iron_spear")
            assert(ok, "the spear is thrown")
            assert(Status.has(foe, "status_harried"), "the foe is left Harried")
            assert(Combat.unitGap(sk, foe) > 1, "and the Skulker is a tile out of reach")
            Combat.dealFlatDamage(c, foe, 1, { "physical" }, "test")
            assert(not Status.has(foe, "status_harried"), "the next blow that lands spends it")
        end,
    },
    {
        name = "the Deadfall: a rigged 3x3 a foe springs by stepping in, rock a turn later, and rough ground after",
        fn = function()
            local c = nest({ { "character_kobold_trapwright", 3, 9 } }, walker(1, 1))
            local wright, foe = one(c, "character_kobold_trapwright"), c.units[1]
            openTurn(c, wright)
            assert(Combat.useItem(c, wright, itemNamed(wright.char, "ability_deadfall"), 5, 8), "the rig is laid")
            local rigged = 0
            for dy = -1, 1 do
                for dx = -1, 1 do if Hazard.at(c, 5 + dx, 8 + dy, "hazard_deadfall_rig") then rigged = rigged + 1 end end
            end
            assert(rigged == 9, "the whole 3x3 is rigged")
            Hazard.onEnter(c, wright, 4, 7)
            assert(Hazard.at(c, 4, 7, "hazard_deadfall_rig"), "the layer walks its own rig and sets nothing off")
            foe.x, foe.y = 4, 7
            Hazard.onEnter(c, foe, 4, 7)
            assert(not Hazard.at(c, 6, 9, "hazard_deadfall_rig"), "one boot on a corner springs the whole square")
            assert(Hazard.at(c, 6, 9, "hazard_deadfall_falling"), "and rock is coming down on all of it")
            local before = hp(foe)
            Hazard.tick(c, 5)
            assert(hp(foe) < before, "a turn later it lands on whoever is still under it")
            assert(c.arena.tiles[7][4].type == "rough", "and leaves the ground rough")
        end,
    },
    {
        name = "Borrowed Breath burns 3 harder for each ally beside the caster",
        fn = function()
            local c = nest({ { "character_kobold_scale_priest", 5, 8 }, { "character_kobold_skulker", 10, 10 },
                             { "character_kobold_skulker", 10, 9 } }, walker(5, 6))
            local priest, foe = one(c, "character_kobold_scale_priest"), c.units[1]
            local breath = itemNamed(priest.char, "ability_borrowed_breath")
            local function quoted()
                local p = Combat.previewAbility(c, priest, breath, 5, 7)
                for _, e in ipairs((p and p.order) or {}) do if e.unit == foe then return e.damage end end
                return 0
            end
            local alone = quoted()
            local a, b = unpack(units(c, "character_kobold_skulker"))
            a.x, a.y, b.x, b.y = 4, 8, 6, 8
            assert(alone > 0 and quoted() > alone, "the choir makes the breath hotter")
        end,
    },
    {
        name = "Dragon's Call: every kobold steps a tile toward its dragon, and one beside it stays put",
        fn = function()
            local c = nest({ { "character_kobold_scale_priest", 1, 10 }, { "character_dragon_egg", 6, 5 },
                             { "character_kobold_skulker", 6, 9 }, { "character_kobold_skulker", 6, 6 } })
            local priest = one(c, "character_kobold_scale_priest")
            local farSk, nearSk = unpack(units(c, "character_kobold_skulker"))
            openTurn(c, priest)
            assert(Combat.useItem(c, priest, itemNamed(priest.char, "ability_dragons_call"), priest.x, priest.y))
            assert(farSk.x == 6 and farSk.y == 8, "the far one takes a step nearer the egg")
            assert(nearSk.x == 6 and nearSk.y == 6, "the one beside it stays")
        end,
    },
    {
        name = "the Dragon Egg drop: the company broods its own egg, and hatches a Wyrmling that is the layer's",
        fn = function()
            local layer = unit("character_archer", 5, 5, { isolate = "mechanics", items = { "ability_dragon_egg" } })
            local c = Fixture.combat(board(), { layer, walker(6, 6) }, { unit("character_kobold_skulker", 10, 10) })
            local me, friend = c.units[1], c.units[2]
            openTurn(c, me)
            assert(Combat.useItem(c, me, itemNamed(me.char, "ability_dragon_egg"), 5, 6), "the egg is laid")
            local egg = one(c, "character_dragon_egg")
            assert(egg and egg.side == "party" and egg.timeless, "a company egg, outside the turn order")
            for _ = 1, 3 do Trait.onAnyTurnEnd(c, friend) end
            local wyrm = one(c, "character_wyrmling")
            assert(wyrm and wyrm.side == "party", "it hatches for the company")
            assert(wyrm.summoned and wyrm.summoner == me, "as the layer's summon, never a roster body")
        end,
    },
    {
        name = "the Godling's Scale: allies within 2 of the wearer fight harder, and a hired kobold treats it as a dragon",
        fn = function()
            local wearer = unit("character_archer", 5, 5, { isolate = "mechanics", items = { "utility_godlings_scale" } })
            local c = Fixture.combat(board(), { wearer, walker(5, 7), walker(5, 9) },
                { unit("character_kobold_skulker", 6, 5) })
            local near, far = c.units[2], c.units[3]
            local foe = one(c, "character_kobold_skulker")
            assert(Combat.flatStat(near, "damage") == Combat.flatStat(far, "damage") + 2,
                "two tiles from the wearer: +2 damage over an ally four away")
            assert(Combat.flatStat(near, "defense") == Combat.flatStat(far, "defense") + 1, "and +1 defense")
            assert(Devotion.isDragon(c.units[1]), "to a kobold on its side, the wearer is a dragon")
            assert(Devotion.nearestDragon(c, foe) == nil, "and to a kobold across the line, it is not theirs")
            local foeDamage = Combat.flatStat(foe, "damage") -- standing beside the wearer
            c.units[1].x, c.units[1].y = 1, 10
            assert(foeDamage == Combat.flatStat(foe, "damage"), "the Eye reaches no foe")
        end,
    },
    {
        name = "the creature kit: the Godling's Hunger, both breaths, and the priest's Scale Blessing",
        fn = function()
            local hunger = Item.defs["utility_godlings_hunger"]
            assert(hunger.bound and hunger.noSteal, "the Godling's Hunger is its organ")
            local god = Character.instantiate("character_the_godling")
            assert(itemNamed(god, "utility_godlings_hunger"), "and it carries it")
            assert(Item.defs["ability_dragons_breath"].activeAbility.windup > 0,
                "Dragon's Breath winds up, so the cone is read a turn early")
            local c = nest({ { "character_wyrmling", 5, 7 }, { "character_the_godling", 8, 7 } }, walker(5, 5))
            local wyrm, g, foe = one(c, "character_wyrmling"), one(c, "character_the_godling"), c.units[1]
            local p = Combat.previewAbility(c, wyrm, itemNamed(wyrm.char, "ability_kindling_breath"), 5, 6)
            local hit = 0
            for _, e in ipairs((p and p.order) or {}) do if e.unit == foe then hit = e.damage end end
            assert(hit > 0, "Kindling Breath reaches a foe two tiles off")
            assert(Item.defs["ability_kindling_breath"].class == "creature", "and it is the hatchling's own")
            assert(itemNamed(g.char, "ability_dragons_breath"), "the Godling breathes the grown one")
            local pc = nest({ { "character_kobold_scale_priest", 5, 5 }, { "character_kobold_skulker", 5, 7 } })
            local priest, sk = one(pc, "character_kobold_scale_priest"), one(pc, "character_kobold_skulker")
            local before = Combat.flatStat(sk, "defense")
            openTurn(pc, priest)
            assert(Combat.useItem(pc, priest, itemNamed(priest.char, "ability_scale_blessing"), sk.x, sk.y))
            assert(Status.has(sk, "status_dragonscale") and Combat.flatStat(sk, "defense") == before + 3,
                "Scale Blessing: +3 defense on the kinsman")
        end,
    },
    -- ------------------------------------------------------------------------------ the fights
    {
        name = "the five fights stand in Greed's deeps on the rungs the review gave them, and the Nest is a seat spare",
        fn = function()
            for id, rung in pairs(FIGHTS) do
                local def = Encounter.defs[id]
                assert(def, id .. " exists")
                assert(def.rung == rung, id .. " is homed on rung " .. rung)
                assert(def.condition({ biome = "cave" }) and not def.condition({ biome = "forest" }),
                    id .. " is dealt in the Goldvein Deeps and nowhere else")
                for _, body in ipairs(def.composition({ depth = 5 })) do
                    assert(not body:match("dwarf") and body ~= "character_the_hoard_thane",
                        id .. " fields no dwarf: the two races never share a board")
                end
            end
            local clutch = Encounter.defs["encounter_greed_the_clutch"].composition({ depth = 5 })
            local eggs = 0
            for _, b in ipairs(clutch) do if b == "character_dragon_egg" then eggs = eggs + 1 end end
            assert(eggs == 2, "with no seed, the Clutch rates on its centre: two eggs")
            local greed
            for _, sin in ipairs(Descent.SINS) do if sin.id == "greed" then greed = sin end end
            local spare = false
            for _, e in ipairs(greed.elites.spares) do if e == "encounter_greed_the_nest" then spare = true end end
            assert(spare, "the Nest is a spare on Greed's seat")
            assert(greed.elites.seat == "encounter_greed_the_counting_hall", "and the Counting Hall keeps the billing")
            assert(greed.minor.lead ~= "character_the_godling", "the Godling is not the lieutenant")
            local nestDef = Encounter.defs["encounter_greed_the_nest"]
            local wave = nestDef.objective.waves[1]
            assert(wave.count == 3 and wave.every, "three waves of worshippers, counted, so the fight can end")
            for _, b in ipairs(wave.composition()) do
                assert(b == "character_kobold_devotee", "every wave is Devotees")
            end
        end,
    },
}

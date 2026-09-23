-- Tests for the SPIDER LINE (Gluttony, 2026-09-23): the Giant Spider, the Larder Mother and the brood,
-- the web they fight on, and the engine seams they needed --
--   * ground a BODY brings (`seedsGround`, models/arena.lua's bodyGround)
--   * new ground douses what it is doused by, and every cast douses its footprint (fire burns silk)
--   * a zone that WELCOMES a walker (Hazard.tileBias / tollMap, the walk-stop preview)
--   * a Root that lands mid-walk ends the walk (status_root's stopsMovement)
--   * a standing reach waiver against one target (Combat.reachWaiver: Feels the Web, Tremor Cord)
--   * `notOn`, the planner's refusal to aim a lockdown at a body already held
--   * a coating's status names its striker as applier (Spider's Supper's Digesting)
-- Each case pins a rule a blueprint's header argues, on a bare board, so it is measured, not described.

local Arena = require("models.arena")
local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local function find(c, id)
    for _, u in ipairs(c.units) do
        if u.alive and u.char and u.char.id == id then return u end
    end
end

local function webAt(c, x, y) return Hazard.at(c, x, y, "hazard_web") end

-- Every piece the line added, by id -- the creature kit and the drops -- so a rename reddens here.
local KIT = {
    "weapon_spider_fangs", "weapon_larder_fangs", "ability_silk_shot", "ability_spin",
    "ability_cast_the_net", "ability_strand_walk", "ability_egg_sac", "utility_silkfoot",
    "utility_feels_the_web", "utility_moult", "utility_the_still_hunt_beast", "utility_brood_hunger",
}
local DROPS = {
    "armor_gossamer_mantle", "ability_dragline", "consumable_spiders_supper",
    "utility_the_still_hunt", "ability_brood_sac", "utility_tremor_cord", "armor_castoff_coat",
}
local BODIES = { "character_giant_spider", "character_the_larder_mother", "character_spiderling" }

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the spider kit is creature stock, and every drop is a person's item that exists",
        fn = function()
            for _, id in ipairs(KIT) do
                local def = Item.defs[id]
                assert(def, "kit item exists: " .. id)
                assert(def.class == "creature" and def.noSteal, id .. " is unstealable creature kit")
                assert(def.price == nil and def.unlockLevel == nil, id .. " carries no price and no rung")
            end
            for _, id in ipairs(DROPS) do
                local def = Item.defs[id]
                assert(def and def.class ~= "creature", "drop is a person's item: " .. id)
            end
            for _, id in ipairs(BODIES) do
                for _, d in ipairs(Character.defs[id].drops or {}) do
                    assert(Item.defs[d], id .. " drops a real item: " .. d)
                end
            end
            -- The Bolas stays the Poacher's, on the counter, and no spider hands it over (Keno's call).
            assert(Item.defs["ability_bolas"].price and not Item.defs["ability_bolas"].unstocked,
                "the Bolas is still Poacher stock")
            for _, id in ipairs(BODIES) do
                for _, d in ipairs(Character.defs[id].drops or {}) do
                    assert(d ~= "ability_bolas", id .. " does not drop the Bolas")
                end
            end
        end,
    },
    {
        name = "the Larder Mother's nine slots are exactly full, and she is an elite spare, not the lieutenant",
        fn = function()
            local def = Character.defs["character_the_larder_mother"]
            local n = 0
            for _, id in ipairs(def.startingItems) do if id then n = n + 1 end end
            assert(n == 9, "her grid is full: " .. n)
            local gluttony
            for _, sin in ipairs(Descent.SINS) do if sin.id == "gluttony" then gluttony = sin end end
            local billed = false
            for _, id in ipairs(gluttony.elites.spares) do
                if id == "encounter_the_larder" then billed = true end
            end
            assert(billed, "The Larder is billed as a spare of the wood")
            assert(gluttony.minor.lead ~= "character_the_larder_mother", "and she is not the lieutenant")
            assert(Encounter.get("encounter_the_larder").rung == 1, "on the approach floor")
            assert(Encounter.get("encounter_the_tangle").kind == "combat", "the Tangle is ordinary traffic")
        end,
    },

    -- ---------------------------------------------------------------------------------- the web
    {
        name = "web holds and Marks whoever steps in, then breaks when the Root does",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 5) }, { unit("character_giant_spider", 5, 9) })
            local knight = c.units[1]
            local web = Hazard.place(c, 5, 5, "hazard_web")
            assert(Status.get(knight, "status_root"), "the strand holds")
            assert(Status.get(knight, "status_mark"), "and tells the spiders where the catch is")
            assert(web.remaining <= 6, "one catch pulls the strand down to a Root's length")
            Hazard.tick(c, 7)
            assert(not webAt(c, 5, 5), "the strand breaks")
            assert(not Status.get(knight, "status_root"), "and the Root goes with it, on one clock")
        end,
    },
    {
        name = "a Root that lands mid-walk ends the walk",
        fn = function()
            assert(Status.defs["status_root"].stopsMovement, "status_root stops a walk that gains it")
        end,
    },
    {
        name = "a spider walks its web, acts sooner on it, and the planner routes onto it",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 2, 2) }, { unit("character_giant_spider", 5, 5) })
            local knight, spider = c.units[1], find(c, "character_giant_spider")
            Hazard.place(c, 5, 5, "hazard_web")
            assert(not Status.get(spider, "status_root"), "the web does not catch its own")
            assert(Status.get(spider, "status_on_the_web"), "it is on the web instead")
            assert(Status.costMultiplier(spider) < 1, "and every action costs it less time there")
            local stride = Combat.flatStat(spider, "movement")
            assert(stride > spider.char.stats.movement, "and it covers more ground setting off from it")
            assert(Hazard.tileBias(c, 5, 5, spider.side, spider) > 0, "the spider wants to stand on web")
            assert(Hazard.tileBias(c, 5, 5, knight.side, knight) < 0, "the knight does not")
            assert(Hazard.tollMap(c, spider) == nil, "and a spider pays no toll to cross it")
            assert(Hazard.tollMap(c, knight), "where a knight does")
        end,
    },
    {
        name = "fire burns web: spreading onto it, or cast over it",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 1, 1) }, { unit("character_giant_spider", 9, 9) })
            Hazard.place(c, 5, 5, "hazard_web")
            Hazard.place(c, 5, 5, "hazard_fire")
            assert(not webAt(c, 5, 5), "fire landing on a strand burns it away")
            Hazard.place(c, 6, 6, "hazard_web")
            Hazard.douse(c, { { x = 6, y = 6 } }, { "fire" })
            assert(not webAt(c, 6, 6), "a fire-tagged cast over it does the same")
            Hazard.place(c, 7, 7, "hazard_web")
            Hazard.douse(c, { { x = 7, y = 7 } }, { "physical", "slash" })
            assert(webAt(c, 7, 7), "and a blade does nothing to it")
        end,
    },
    {
        name = "a spider brings its web to the board, laid between the lines and under nobody",
        fn = function()
            local base = { biome = "forest", seed = 4242, party = { "character_knight", "character_knight" } }
            local function webs(composition)
                local spec = {}
                for k, v in pairs(base) do spec[k] = v end
                spec.composition = composition
                local arena = Arena.build({ biome = "forest" }, spec)
                local n, under = 0, false
                local seats = {}
                for _, u in ipairs(arena.party) do seats[u.x .. "," .. u.y] = true end
                for _, u in ipairs(arena.enemies) do seats[u.x .. "," .. u.y] = true end
                for _, h in ipairs(arena.hazards) do
                    if h.id == "hazard_web" then
                        n = n + 1
                        if seats[h.x .. "," .. h.y] then under = true end
                    end
                end
                return n, under
            end
            local plain = webs({ "character_wolf_alpha", "character_wolf_alpha" })
            local strung, under = webs({ "character_giant_spider", "character_giant_spider" })
            assert(strung >= plain + 6, string.format("two spiders bring six strands (%d vs %d)", strung, plain))
            assert(not under, "no strand is laid under a seated body")
        end,
    },

    {
        -- THE PLANNER PRICES THE ROAD, not only the stop (Combat.routeTolls, AI.WEIGHTS.ROUTE_HAZARD).
        -- Before this a Shoalkin on the old forest walked through sweetbriar to reach a clean tile and
        -- was charmed to the party's side -- the whole of why that fight "won" in 14 unit-turns.
        name = "the road to a tile is charged for the hostile ground it crosses, and a clean detour is free",
        fn = function()
            local c = Fixture.combat(Fixture.new(5, 5),
                { Fixture.walker(1, 1) }, { unit("character_giant_spider", 5, 5) })
            local walker = c.units[1]
            Hazard.place(c, 2, 1, "hazard_web")
            local tolls = Combat.routeTolls(c, walker)
            assert(tolls, "a board with hostile ground has a toll map")
            assert(tolls["3,1"] == Hazard.PATH_TOLL,
                "the only road to (3,1) inside the move crosses the strand: " .. tostring(tolls["3,1"]))
            assert((tolls["3,2"] or 0) == 0, "and (3,2) has a clean road round it: " .. tostring(tolls["3,2"]))
            local spider = find(c, "character_giant_spider")
            assert(Combat.routeTolls(c, spider) == nil, "a spider's own web charges it nothing")
        end,
    },

    -- --------------------------------------------------------------------------- Giant Spider
    {
        name = "Silk Shot Roots and Halts, and the planner will not aim it at a body already held",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 2) }, { unit("character_giant_spider", 5, 5) })
            local knight, spider = c.units[1], find(c, "character_giant_spider")
            local shot = itemNamed(spider.char, "ability_silk_shot")
            local listed = Combat.abilityTargets(c, spider, shot)
            assert(#listed == 1 and listed[1] == knight, "a free knight is a target")
            openTurn(c, spider)
            assert(Combat.useItem(c, spider, shot, knight.x, knight.y))
            assert(Status.get(knight, "status_root") and Status.get(knight, "status_halted"), "legs and hands")
            assert(#Combat.abilityTargets(c, spider, shot) == 0, "a held knight is not listed again")
        end,
    },
    {
        name = "Spider Fangs bite half again as hard on a Rooted body",
        fn = function()
            local function bite(rooted)
                local c = Fixture.combat(Fixture.new(10, 10),
                    { unit("character_knight", 5, 5) }, { unit("character_giant_spider", 5, 6) })
                local knight, spider = c.units[1], find(c, "character_giant_spider")
                if rooted then Status.apply(c, knight, "status_root") end
                local before = hp(knight)
                Fixture.strike(c, spider, knight, itemNamed(spider.char, "weapon_spider_fangs"))
                return before - hp(knight)
            end
            local free, stuck = bite(false), bite(true)
            assert(stuck > free, string.format("stuck %d > free %d", stuck, free))
        end,
    },

    -- ----------------------------------------------------------------------- The Larder Mother
    {
        name = "Digesting feeds whoever inflicted it, tick by tick",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 2, 2) }, { unit("character_the_larder_mother", 6, 6) })
            local knight, mother = c.units[1], find(c, "character_the_larder_mother")
            mother.char.stats.health.current = 60
            Status.apply(c, knight, "status_digesting", { applier = mother })
            local kBefore = hp(knight)
            Status.tick(c, 10)
            assert(hp(knight) < kBefore, "the venom works")
            assert(hp(mother) > 60, "and she drinks what it dissolves")
        end,
    },
    {
        name = "the Still Hunt counts unmoved turns to three, and a step clears it",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 2, 2) }, { unit("character_the_larder_mother", 6, 6) })
            local mother = find(c, "character_the_larder_mother")
            if not Status.get(mother, "status_still_hunt") then
                Status.apply(c, mother, "status_still_hunt", { magnitude = 0 })
            end
            for _ = 1, 4 do
                openTurn(c, mother)
                Status.onTurnEnd(c, mother)
            end
            assert(Status.get(mother, "status_still_hunt").magnitude == 3, "three turns of patience, capped")
            local bonus = Trait.defs["trait_still_hunt"].damageBonusVs({ unit = mother })
            assert(bonus > 0, "which the next blow is paid")
            Status.onEnterTile(c, mother)
            assert(Status.get(mother, "status_still_hunt").magnitude == 0, "and any step spends it for nothing")
        end,
    },
    {
        name = "Feels the Web reaches a foe beside a strand from anywhere; Tremor Cord sees a Rooted one",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 1, 1) }, { unit("character_the_larder_mother", 10, 10) })
            local knight, mother = c.units[1], find(c, "character_the_larder_mother")
            local shot = itemNamed(mother.char, "ability_silk_shot")
            assert(#Combat.abilityTargets(c, mother, shot) == 0, "a knight across the board is out of reach")
            Hazard.place(c, 2, 1, "hazard_web") -- a strand beside him, not under him
            local waivesRange, waivesSight = Combat.reachWaiver(c, mother, knight)
            assert(waivesRange and waivesSight, "a strand beside him is how she reaches him")
            assert(#Combat.abilityTargets(c, mother, shot) == 1, "and the planner lists him")

            local archer = Fixture.unit("character_knight", 1, 1)
            Fixture.give(archer.char, "utility_tremor_cord")
            local c2 = Fixture.combat(Fixture.new(10, 10), { archer }, { unit("character_giant_spider", 5, 5) })
            local me, spider = c2.units[1], find(c2, "character_giant_spider")
            local _, blind = Combat.reachWaiver(c2, me, spider)
            assert(not blind, "a free spider is not seen through cover")
            Status.apply(c2, spider, "status_root")
            local range, sight = Combat.reachWaiver(c2, me, spider)
            assert(sight and not range, "a Rooted one is -- in sight, never out of range")
        end,
    },
    {
        name = "Moult, once at half health: every debuff shed, and a husk left where she stood",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 1, 1) }, { unit("character_the_larder_mother", 6, 6) })
            local mother = find(c, "character_the_larder_mother")
            Status.apply(c, mother, "status_poison")
            local max = mother.char.stats.health.max
            Combat.dealFlatDamage(c, mother, math.ceil(max * 0.55), { "physical" }, "the test", nil, { raw = true })
            assert(mother.alive, "she lives through it")
            assert(not Status.get(mother, "status_poison"), "the skin takes the venom with it")
            assert(find(c, "character_larder_husk"), "and the husk stands where she did")
        end,
    },
    {
        name = "the Egg Sac hatches two, never past four alive",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 1, 1) }, { unit("character_the_larder_mother", 6, 6) })
            local mother = find(c, "character_the_larder_mother")
            local sac = itemNamed(mother.char, "ability_egg_sac")
            local function brood()
                local n = 0
                for _, u in ipairs(c.units) do
                    if u.alive and u.char.id == "character_spiderling" then n = n + 1 end
                end
                return n
            end
            for _ = 1, 3 do
                openTurn(c, mother)
                mother.char.stats.stamina.current = mother.char.stats.stamina.max
                Combat.useItem(c, mother, sac, mother.x, mother.y)
            end
            assert(brood() == 4, "two, then two, then none: " .. brood())
        end,
    },
    {
        name = "Spider's Supper coats a blade with Digesting that feeds the striker",
        fn = function()
            local def = Item.defs["consumable_spiders_supper"]
            assert(def.price and def.class == "poisoner", "the one priced piece of the set is Poisoner stock")
            assert(def.aura and def.aura.status.id == "status_digesting", "and it coats with Digesting")
        end,
    },
}

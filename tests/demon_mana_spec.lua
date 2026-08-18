-- Tests for the DEMON CONTRACT: a demon's BODY is billed to stamina and its WILL is billed to mana.
--
-- This exists because the rule it pins was invisible for a long time and cost a whole teaching beat.
-- Every demon blueprint used to carry `mana = 0` while the flight leg handed the player Drain Mana
-- (data/items/ability/ability_drain_mana.lua) at stop 5 as its ROGUE class introduction, "siphoned off
-- the demons blocking the way out" -- and Act 0 fields nothing but demons from that stop to the
-- Champion. So the one gift of seven that could not work spent 4 stamina and restored nothing, and
-- the only reading a player could take from it was that the ability was broken.
--
-- The fix was to make the fiction true rather than to move the gift: demons channel hellfire, so
-- hellfire is what their mana buys. What that turns into, and what is asserted below:
--
--   imp       all will and no craft -- its Cinder Spit is the only thing it does, and it is mana
--   grunt     the middle: claws on stamina (its body), Brimstone on mana (its will)
--   champion  claws, riposte and Heave on stamina; the Roar and the Cleave -- the two casts its three
--             stages are actually made of -- on mana
--
-- The load-bearing consequence is that mana NEVER REGENERATES (Combat.regenerate), so every one of
-- those pools is a countable number of castings rather than a resource, and a siphon is worth a whole
-- one of them. That is the property these cases guard: a pool that stops covering its own kit, or a
-- cost quietly moved back onto stamina, breaks the gift again in exactly the way that is impossible
-- to see from the fight.
--
-- Pure logic, headless -- mirrors tests/demon_champion_spec.lua.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Hazard = require("models.hazard")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

-- The demons Act 0 actually fields, which is the set the gift is granted against.
local DEMONS = { "character_demon_imp", "character_demon_grunt", "character_demon_champion" }

-- The declared cost of `id`'s active ability, as stat, amount.
local function costOf(id)
    local ab = Item.defs[id] and Item.defs[id].activeAbility
    local cost = ab and ab.cost
    if not cost or not cost.stat then return nil end
    return cost.stat, cost.amount or 0
end

-- A rogue holding nothing but a Drain Mana, with an empty pool to siphon into so the restore has
-- somewhere to land (Combat.restoreResource clamps at max, and a full caster would hide the gain).
local function siphoner(x, y)
    local spawn = Fixture.unit("character_rogue", x, y,
        { isolate = "bare", items = { "ability_drain_mana" }, stats = { mana = 60, stamina = 40 } })
    spawn.char.stats.mana.current = 0
    return spawn
end

return {
    {
        name = "every demon Act 0 fields spends mana on something, and carries the pool to spend it",
        fn = function()
            for _, id in ipairs(DEMONS) do
                local char = Character.instantiate(id)
                local pool = char.stats.mana
                assert(pool and pool.max > 0, id .. " has no mana pool -- the contract is off this body")

                local casts, dearest = 0, 0
                for i = 1, Character.MAX_INVENTORY do
                    local item = char.inventory[i]
                    -- Spelled out rather than `item and costOf(...)`: an `and` is adjusted to ONE
                    -- value, so the amount would silently arrive nil on every row.
                    local stat, amount
                    if item then stat, amount = costOf(item.id) end
                    if stat == "mana" then
                        casts = casts + 1
                        dearest = math.max(dearest, amount)
                    end
                end
                assert(casts > 0, id .. " carries nothing that costs mana, so its pool buys nothing")
                assert(pool.max >= dearest, id .. " cannot afford its own dearest cast: "
                    .. pool.max .. " mana against " .. dearest)
            end
        end,
    },
    {
        -- The other half of the same contract, and the half that is easy to break by accident: the
        -- body stays on stamina. A demon whose claws moved onto mana would compete with its own will
        -- for the pool, and a Drain Mana would start disarming it outright rather than defanging it.
        name = "a demon's claws are still paid for out of stamina",
        fn = function()
            for _, id in ipairs({ "weapon_rending_claws", "weapon_great_claws" }) do
                local stat = costOf(id)
                assert(stat == "stamina", id .. " is a body, and a body costs stamina -- got " .. tostring(stat))
            end
        end,
    },
    {
        name = "an imp's hellfire IS its mana: six shots, and then it is a body with claws",
        fn = function()
            local stat, amount = costOf("weapon_cinder_spit")
            assert(stat == "mana", "the Cinder Spit is drawn from the will, not the arm")

            local char = Character.instantiate("character_demon_imp")
            assert(math.floor(char.stats.mana.max / amount) == 6,
                "an imp is authored for exactly six spits, got "
                    .. math.floor(char.stats.mana.max / amount))

            local c = Fixture.combat(Fixture.new(8, 8), Fixture.unit("character_knight", 4, 4),
                { char = char, x = 4, y = 6 })
            local imp = c.units[2]
            local spit = Fixture.itemNamed(char, "weapon_cinder_spit")
            assert(Combat.canAfford(imp, spit.activeAbility), "a full imp can spit")

            -- One short of the cost is the whole of the difference: it is not that the imp is tired,
            -- it is that the fire is gone. Its stamina is deliberately untouched here.
            char.stats.mana.current = amount - 1
            assert(not Combat.canAfford(imp, spit.activeAbility), "an emptied imp has no shot left")
            assert(char.stats.stamina.current == char.stats.stamina.max,
                "and none of it came out of stamina")
        end,
    },
    {
        name = "the grunt keeps its claws on stamina and buys three Brimstones with its mana",
        fn = function()
            local clawStat = costOf("weapon_rending_claws")
            local gustStat, gustAmount = costOf("ability_demon_brimstone")
            assert(clawStat == "stamina" and gustStat == "mana",
                "the grunt is the body/will split stated on one sheet")

            local char = Character.instantiate("character_demon_grunt")
            assert(math.floor(char.stats.mana.max / gustAmount) == 3,
                "a grunt is authored for exactly three castings, got "
                    .. math.floor(char.stats.mana.max / gustAmount))
            assert(Fixture.itemNamed(char, "ability_demon_brimstone"), "and it actually carries one")
            -- Brimstone is `magical`, so a grunt with no magic behind it would throw a gout that
            -- landed for nothing -- and an outcome of zero is dropped from the AI's pool before it is
            -- ever scored (AI.scoreCandidate), which would make the whole ability invisible.
            assert(char.stats.magicDamage > 0, "a magical cast needs a magic side to be worth throwing")
        end,
    },
    {
        name = "Brimstone wounds what it catches and leaves the ground burning",
        fn = function()
            local c = Fixture.combat(Fixture.new(8, 8),
                { Fixture.unit("character_knight", 4, 3), Fixture.unit("character_knight", 5, 3) },
                Fixture.unit("character_demon_grunt", 4, 6))
            local left, right, grunt = c.units[1], c.units[2], c.units[3]
            local before = { Fixture.hp(left), Fixture.hp(right) }

            assert(Fixture.strike(c, grunt, left, "ability_demon_brimstone"), "the gout is thrown")
            assert(Fixture.hp(left) < before[1] and Fixture.hp(right) < before[2],
                "the burst catches the pair, not just the body it was aimed at")
            assert(Hazard.at(c, 4, 3, "hazard_fire"), "the tile it landed on is alight")
            assert(Hazard.at(c, 5, 3, "hazard_fire"), "and so is the rest of the blast")
            assert(not Hazard.at(c, 4, 6, "hazard_fire"),
                "minRange keeps the grunt from setting fire to its own feet")
        end,
    },
    {
        -- The point of giving the grunt a second note at all. A grunt that has just swung cannot
        -- afford another claw for a turn or two (its stamina is one swing wide, on purpose -- see the
        -- blueprint), and it used to answer that by walking up and punching. Now it burns the ground.
        name = "a grunt that cannot pay for its claws throws Brimstone rather than a fist",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { Fixture.unit("character_knight", 5, 3), Fixture.unit("character_mage", 6, 3) },
                Fixture.unit("character_demon_grunt", 5, 6))
            local grunt = c.units[3]
            grunt.char.stats.stamina.current = 0 -- it swung last turn

            local plan = AI.plan(c, grunt)
            assert(plan and plan.item, "the grunt found something to do")
            assert(plan.item.id == "ability_demon_brimstone",
                "an emptied grunt reaches for the gout, not the fists -- got " .. tostring(plan.item.id))
        end,
    },
    {
        name = "the Champion's stages are billed to mana, and one pool runs the whole script",
        fn = function()
            local roarStat, roar = costOf("ability_demon_roar")
            local cleaveStat, cleave = costOf("ability_demon_cleave")
            assert(roarStat == "mana" and cleaveStat == "mana",
                "the two casts the three stages are made of come out of the will")

            local char = Character.instantiate("character_demon_champion")
            -- Stage 1 wants a few Cleaves and stage 2 a few Roars; the pool is sized to run that once
            -- through and no more, which is what makes each siphon worth a stage beat.
            assert(char.stats.mana.max >= 3 * cleave + 2 * roar,
                "the Champion cannot afford its own stage script: " .. char.stats.mana.max
                    .. " mana against " .. (3 * cleave + 2 * roar))

            -- ...and its stamina is left to its body. The Sigil's riposte is billed there too, so a
            -- Champion whose casts came out of stamina was competing with its own guard for it.
            local claws = Fixture.itemNamed(char, "weapon_great_claws")
            assert(claws, "the Champion carries its claws")
            assert(char.stats.stamina.max >= (claws.activeAbility.cost.amount or 0),
                "and can pay for a swing out of stamina alone")
        end,
    },
    {
        -- The case the whole change exists for. Before it, this loop measured zero on every body.
        name = "Drain Mana takes a real bite out of every demon Act 0 puts in front of it",
        fn = function()
            for _, id in ipairs(DEMONS) do
                local caster = siphoner(1, 1)
                local c = Fixture.combat(Fixture.new(8, 8), caster, Fixture.unit(id, 1, 3))
                local rogue, demon = c.units[1], c.units[2]
                local before = demon.char.stats.mana.current
                assert(before > 0, id .. " brought no mana to the fight")

                assert(Fixture.strike(c, rogue, demon, "ability_drain_mana"),
                    "the siphon lands on " .. id)
                local taken = before - demon.char.stats.mana.current
                assert(taken > 0, "the siphon took nothing off " .. id)
                assert(rogue.char.stats.mana.current == taken,
                    "what came off " .. id .. " is exactly what went into the rogue")
            end
        end,
    },
}

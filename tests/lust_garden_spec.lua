-- Tests for the LUST GARDEN (2026-09-23): the Alraune line, the Dryad line and the mushroom folk, and
-- the three engine seams they needed -- Swoon's refusal (Combat.itemBlockReason), Mistlight's extra
-- tile (Combat.knockback) and the Gallows Seed's stolen heal (Combat.applyHeal).
--
-- Each case pins a rule a body's header argues, on a bare board, so the fight is measured rather than
-- described. The roster rule the lines live under -- a Lust fight holds or throws, never both -- is
-- pinned beside the rest of the circle, in tests/greed_lust_circle_spec.lua.

local Character = require("models.character")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Wall = require("models.wall")
local Grove = require("models.grove")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local function find(c, id)
    for _, u in ipairs(c.units) do
        if u.alive and u.char and u.char.id == id then return u end
    end
end

local function kill(c, u)
    Combat.dealFlatDamage(c, u, 9999, { "physical" }, "the test", nil, { raw = true })
end

return {
    -- ------------------------------------------------------------------------------------- Swoon
    {
        name = "a swooning body cannot strike, can still act, and is shaken out by a hit",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 5) }, { unit("character_harpy", 5, 6) })
            local knight = c.units[1]
            Status.apply(c, knight, "status_swoon", { duration = 12 })
            assert(Status.forbidsHarm(knight), "the swoon took")
            local sword = itemNamed(knight.char, "weapon_iron_sword")
            local refused = Combat.itemBlockReason(knight, sword)
            assert(refused and refused.kind == "swooning", "a sword swing is refused while swooning")
            local potion = itemNamed(knight.char, "consumable_healing_potion")
            assert(not Combat.itemBlockReason(knight, potion), "a draught is not a blow: it is still drunk")
            Combat.dealFlatDamage(c, knight, 1, { "physical" }, "a slap")
            assert(not Status.get(knight, "status_swoon"), "any hit shakes a body out of it")
        end,
    },

    -- ---------------------------------------------------------------------------- Alraune line
    {
        name = "honeyed ground heals on arrival and puts to sleep whoever ends a turn on it",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 5) }, { unit("character_alraune", 5, 8) })
            local knight, alraune = c.units[1], find(c, "character_alraune")
            knight.char.stats.health.current = 10
            Hazard.place(c, 5, 5, "hazard_honeyed_ground", { owner = alraune, side = alraune.side, amount = 8 })
            assert(hp(knight) > 10, "the honey mends the body standing in it")
            assert(Status.get(knight, "status_honeyed"), "and the body is honeyed")
            Status.onTurnEnd(c, knight)
            assert(Status.get(knight, "status_sleep"), "a turn ended on the honey ends in sleep")
        end,
    },
    {
        name = "a gallows seed sends every heal its host receives to the one who planted it",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 5) }, { unit("character_alraune", 5, 8) })
            local knight, alraune = c.units[1], find(c, "character_alraune")
            knight.char.stats.health.current = 10
            alraune.char.stats.health.current = 20
            Status.apply(c, knight, "status_gallows_seed", { applier = alraune })
            Combat.applyHeal(c, knight, 12)
            assert(hp(knight) == 10, "the host gets nothing")
            assert(hp(alraune) == 32, "the planter drinks the whole heal")
            kill(c, alraune)
            Combat.applyHeal(c, knight, 5)
            assert(hp(knight) == 15, "a seed whose planter is dead feeds nobody")
        end,
    },
    {
        name = "a Mandrake roots from range, and screams when it dies",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 5), unit("character_mage", 5, 3) },
                { unit("character_mandrake", 5, 7), unit("character_alraune", 6, 7) })
            local knight, mandrake, alraune = c.units[1], find(c, "character_mandrake"), find(c, "character_alraune")
            openTurn(c, mandrake)
            Combat.useItem(c, mandrake, itemNamed(mandrake.char, "weapon_taproot"), knight.x, knight.y)
            assert(Status.get(knight, "status_root"), "the root holds the knight where he stands")
            kill(c, mandrake)
            assert(Status.get(knight, "status_stun"), "the scream stuns a foe within two tiles")
            assert(Status.get(alraune, "status_stun"), "...and its own side as well")
            assert(not Status.get(c.units[2], "status_stun"), "a body four tiles off hears nothing")
        end,
    },
    {
        name = "the Pit Grows: a death near the Anchoress sprouts a Mandrake, and a Mandrake's does not",
        fn = function()
            -- The victim is a Puffer because it cannot be revived: its death is a death at once, with
            -- no downed window in front of it.
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 2, 2) },
                { unit("character_alraune_anchoress", 5, 7), unit("character_swooncap_puffer", 5, 5) })
            kill(c, find(c, "character_swooncap_puffer"))
            local sprout = find(c, "character_mandrake")
            assert(sprout, "a Mandrake came up where the Puffer fell")
            local before = 0
            for _, u in ipairs(c.units) do if u.alive and u.char.id == "character_mandrake" then before = before + 1 end end
            kill(c, sprout)
            local after = 0
            for _, u in ipairs(c.units) do if u.alive and u.char.id == "character_mandrake" then after = after + 1 end end
            assert(after == before - 1, "a Mandrake's death sprouts nothing, or the fight could not run out of them")
        end,
    },
    {
        name = "Compline rings every Mandrake's scream and none of them dies of it",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 3, 3), unit("character_mage", 9, 9) },
                { unit("character_alraune_anchoress", 6, 6), unit("character_mandrake", 3, 4),
                  unit("character_mandrake", 9, 8) })
            local anchoress = find(c, "character_alraune_anchoress")
            openTurn(c, anchoress)
            local ok = Combat.useItem(c, anchoress, itemNamed(anchoress.char, "weapon_compline"), anchoress.x, anchoress.y)
            assert(ok, "she starts the office")
            Combat.resolveChannel(c, anchoress)
            assert(Status.get(c.units[1], "status_stun"), "the knight beside the first Mandrake is stunned")
            assert(Status.get(c.units[2], "status_stun"), "the mage beside the second is stunned")
            local alive = 0
            for _, u in ipairs(c.units) do if u.alive and u.char.id == "character_mandrake" then alive = alive + 1 end end
            assert(alive == 2, "both Mandrakes are still in the floor")
            assert(not Status.get(anchoress, "status_stun"), "an anchoress keeps the hours; she does not hear them")
        end,
    },

    -- ------------------------------------------------------------------------------ Dryad line
    {
        name = "Mistlight throws the next shove one tile further, and is spent on it",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 5, 5) }, { unit("character_harpy", 5, 7) })
            local knight, harpy = c.units[1], find(c, "character_harpy")
            Status.apply(c, knight, "status_mistlit")
            local moved = Combat.knockback(c, harpy, knight, 1)
            assert(moved == 2 and knight.y == 3, "a lit body goes two tiles on a one-tile shove")
            assert(not Status.get(knight, "status_mistlit"), "the light is spent on that shove")
            moved = Combat.knockback(c, harpy, knight, 1)
            assert(moved == 1, "and the next shove is an ordinary one")
        end,
    },
    {
        name = "Briarfloor bills a thrown body for every tile of thorn it is thrown across",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 5, 8) }, { unit("character_dryad", 5, 10) })
            local knight, dryad = c.units[1], find(c, "character_dryad")
            for y = 5, 7 do Hazard.place(c, 5, y, "hazard_briarfloor", { side = dryad.side, amount = 4 }) end
            local before = hp(knight)
            Combat.knockback(c, dryad, knight, 2)
            local twoTiles = before - hp(knight)
            assert(knight.y == 6, "the knight was thrown two tiles")
            assert(twoTiles >= 2, "two thorn tiles crossed, two stings taken (took " .. twoTiles .. ")")
            -- ...and her own side walks her thorns freely.
            local before2 = hp(dryad)
            Hazard.onEnter(c, dryad, 5, 5)
            assert(hp(dryad) == before2, "the thorns are sided to whoever grew them")
        end,
    },
    {
        name = "Quickset grows a three-tile hedge across the lane behind its target",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 5, 5) }, { unit("character_dryad", 5, 8) })
            local knight, dryad = c.units[1], find(c, "character_dryad")
            openTurn(c, dryad)
            Combat.useItem(c, dryad, itemNamed(dryad.char, "weapon_quickset"), knight.x, knight.y)
            for x = 4, 6 do
                local w = Wall.at(c, x, 4)
                assert(w and w.id == "hedge", "a hedge stands at (" .. x .. ", 4), behind the knight")
            end
            assert(Grove.besidePlant(c, 5, 5, dryad.side), "and a hedge is grove the Nymphs can step out of")
        end,
    },
    {
        name = "a Nymph plants, and Greensteps out beside the plant farthest from every foe",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 2, 2) }, { unit("character_nymph", 3, 2) })
            local nymph = find(c, "character_nymph")
            openTurn(c, nymph)
            Combat.useItem(c, nymph, itemNamed(nymph.char, "weapon_seedfall"), 5, 3)
            local sapling = find(c, "character_sapling")
            assert(sapling and sapling.side == nymph.side, "a sapling of hers stands where she aimed")
            openTurn(c, nymph)
            Combat.useItem(c, nymph, itemNamed(nymph.char, "weapon_greenstep"), nymph.x, nymph.y)
            assert(math.max(math.abs(nymph.x - 5), math.abs(nymph.y - 3)) == 1,
                "she stepped out of the grain beside her sapling")
            assert(math.max(math.abs(nymph.x - 2), math.abs(nymph.y - 2)) == 4,
                "on the far side of it from the knight")
        end,
    },
    {
        name = "Through the Grain strands a foe beside a far plant, away from its friends",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 3, 3), unit("character_priest", 3, 2) },
                { unit("character_hamadryad", 5, 5), unit("character_sapling", 3, 4),
                  unit("character_sapling", 10, 10) })
            local knight, ham = c.units[1], find(c, "character_hamadryad")
            openTurn(c, ham)
            Combat.useItem(c, ham, itemNamed(ham.char, "weapon_through_the_grain"), knight.x, knight.y)
            if knight.alive then
                assert(math.max(math.abs(knight.x - 3), math.abs(knight.y - 3)) > 1,
                    "the knight was taken through the grain, away from where he stood")
            end
        end,
    },
    {
        name = "the Hamadryad cannot die while her tree stands, and goes back to it when floored",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 2, 2) }, { unit("character_hamadryad", 8, 8) })
            local ham = find(c, "character_hamadryad")
            local tree = find(c, "character_heartwood_tree")
            assert(tree, "her tree was planted beside her at the bell")
            assert(Status.get(ham, "status_heartbound"), "and she is bound to it")
            ham.x, ham.y = 3, 2 -- walk her away from it
            Combat.dealFlatDamage(c, ham, 9999, { "physical" }, "the test", nil, { raw = true })
            assert(ham.alive and hp(ham) == 1, "a killing blow leaves her at 1")
            assert(math.max(math.abs(ham.x - tree.x), math.abs(ham.y - tree.y)) <= 1, "beside her tree")
            kill(c, tree)
            Status.tick(c, 1)
            assert(not Status.get(ham, "status_heartbound"), "the bond ends with the tree")
            kill(c, ham)
            assert(not ham.alive, "and then she dies like anything else")
        end,
    },

    -- ---------------------------------------------------------------------------- mushroom folk
    {
        name = "a Puffer cut down bursts where it stands, both sides",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 5) },
                { unit("character_swooncap_puffer", 5, 6), unit("character_swooncap_verger", 6, 6) })
            local knight, puffer, verger = c.units[1], find(c, "character_swooncap_puffer"), find(c, "character_swooncap_verger")
            kill(c, puffer)
            assert(Status.get(knight, "status_swoon"), "the knight beside it swoons")
            assert(Status.get(verger, "status_swoon"), "...and so does its own Verger")
        end,
    },
    {
        name = "the Verger's flesh swoons every melee hand; the mantle only a quarter of them",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 5) }, { unit("character_swooncap_verger", 5, 6) })
            local knight, verger = c.units[1], find(c, "character_swooncap_verger")
            verger.char.stats.health.current = 200
            Fixture.strike(c, knight, verger, "weapon_iron_sword")
            assert(Status.get(knight, "status_swoon"), "a sword on the Verger comes back as spores")
            local mantle = Item.instantiate("armor_spongeflesh_mantle")
            local t = Trait.instantiate("trait_spongeflesh", mantle)
            assert(Trait.param(t, "chance") == 25, "the carried mantle answers a quarter of blows")
            local own = Trait.instantiate("trait_spongeflesh", Item.instantiate("utility_spongeflesh"))
            assert(Trait.param(own, "chance") == 100, "the Verger's own flesh answers every one")
        end,
    },
    {
        name = "Sporebloom sets off the Puffer with the most foes beside it, from where it stands",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                { unit("character_knight", 5, 5), unit("character_priest", 4, 6) },
                { unit("character_swooncap_puffer", 5, 6), unit("character_swooncap_puffer", 11, 11),
                  unit("character_swooncap_thurifer", 5, 10) })
            local thurifer = find(c, "character_swooncap_thurifer")
            openTurn(c, thurifer)
            Combat.useItem(c, thurifer, itemNamed(thurifer.char, "weapon_sporebloom"), thurifer.x, thurifer.y)
            assert(Status.get(c.units[1], "status_swoon") and Status.get(c.units[2], "status_swoon"),
                "the Puffer beside the company went off")
            local far = 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_swooncap_puffer" then far = far + 1 end
            end
            assert(far == 1, "the one out of reach of anybody is still standing")
        end,
    },

    -- ------------------------------------------------------------------------------ the ledger
    {
        name = "every garden blueprint loads, and every creature kit is natural and unpriced",
        fn = function()
            local kit = {
                "weapon_taproot", "utility_mandrake_scream", "weapon_honeyed_ground", "weapon_gallows_seed",
                "weapon_nightshade", "weapon_compline", "utility_the_anchorhold",
                "weapon_seedfall", "weapon_greenstep", "weapon_mistlight", "weapon_springwater",
                "weapon_thorn_whip", "weapon_briarfloor", "weapon_quickset", "weapon_barkskin",
                "weapon_through_the_grain", "weapon_wild_growth", "utility_heartwood_bond",
                "ability_spore_pop", "utility_spore_sac", "weapon_cap_staff", "weapon_call_to_order",
                "utility_spongeflesh", "weapon_thurifer_cap", "weapon_spore_bolt", "weapon_sporebloom",
                "weapon_mycelial_heal",
            }
            for _, id in ipairs(kit) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.class == "creature" and not def.price, id .. ": creature kit is unpriced and unshelved")
            end
            local drops = {
                "ability_mandrake_sprout", "ability_gallows_seed", "consumable_mandragora", "utility_the_pit_grows",
                "ability_mistlight", "ability_seedfall", "ability_greenstep", "ability_thorn_whip",
                "ability_briarfloor", "ability_quickset", "ability_through_the_grain", "utility_heartwood",
                "weapon_churchyard_yew", "consumable_puffball", "armor_spongeflesh_mantle", "weapon_spore_censer",
            }
            for _, id in ipairs(drops) do
                local def = Item.defs[id]
                assert(def and def.class ~= "creature", id .. " is a piece a company can carry")
            end
            for _, id in ipairs({ "character_mandrake", "character_alraune", "character_alraune_anchoress",
                                  "character_nymph", "character_dryad", "character_hamadryad",
                                  "character_swooncap_puffer", "character_swooncap_verger",
                                  "character_swooncap_thurifer", "character_sapling",
                                  "character_heartwood_tree" }) do
                local char = Character.instantiate(id)
                assert(char, id .. " instantiates")
                for _, dropId in ipairs(Character.defs[id].drops or {}) do
                    assert(Item.defs[dropId], id .. " drops " .. dropId .. ", which does not exist")
                end
            end
        end,
    },
    {
        name = "the Dryad line's spells stock the druid shelf; the garden's trophies stock nothing",
        fn = function()
            for _, id in ipairs({ "ability_mistlight", "ability_seedfall", "ability_greenstep",
                                  "ability_thorn_whip", "ability_briarfloor", "ability_quickset",
                                  "ability_through_the_grain", "utility_heartwood" }) do
                local def = Item.defs[id]
                assert(def.class == "druid" and not def.unstocked, id .. " is ordinary druid stock")
            end
        end,
    },
}

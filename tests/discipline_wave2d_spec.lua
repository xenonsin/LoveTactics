-- Behavioural cases for the Paladin, Plague Knight, Theurge and Apothecary shelves.
--
-- Three engine seams are pinned here alongside the items, because nothing else reaches them:
--   * Combat.spreadContagion  -- the plague's one-step-per-turn spread
--   * the unit-level `steadfastChannels` flag in Combat.interruptChannel
--   * the `lendsGuard` clause in fx.heal, the one heal path that knows who did the healing

local Combat = require("models.combat")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

return {
    -- PALADIN ---------------------------------------------------------------------------------------
    {
        name = "Lay On Hands heals, wards, and moves the ally's afflictions onto the paladin",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "ability_lay_on_hands" } })
            local ally = Fixture.unit("character_rowan", 3, 4, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero, ally }, { foe })
            local h, a = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            a.char.stats.health.current = 10

            Status.apply(combat, a, "status_poison")
            Status.apply(combat, a, "status_bleed")
            assert(Status.has(a, "status_poison") and Status.has(a, "status_bleed"), "the ally is in a bad way")

            assert(Fixture.strike(combat, h, a, "ability_lay_on_hands"), "hands are laid on")
            assert(a.char.stats.health.current > 10, "the ally is healed")
            assert(Status.has(a, "status_aegis"), "and warded")
            assert(not Status.has(a, "status_poison"), "the poison has left them")
            assert(Status.has(h, "status_poison"), "and is on the paladin")
            assert(Status.has(h, "status_bleed"), "along with everything else they were carrying")
        end,
    },
    {
        name = "the Vow-Marked Plate hardens for each affliction borne, however it arrived",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_rowan", 3, 3,
                { isolate = "bare", items = { "armor_vow_marked_plate" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            local before = (h.bonus and h.bonus.defense) or 0
            Status.apply(combat, h, "status_poison")
            local once = (h.bonus and h.bonus.defense) or 0
            assert(once > before, "the first affliction hardens the plate")
            Status.apply(combat, h, "status_bleed")
            assert(((h.bonus and h.bonus.defense) or 0) > once, "and so does the second")

            -- Permanent for the battle: curing it does not undo what bearing it bought.
            local held = (h.bonus and h.bonus.defense) or 0
            Combat.cleanse(combat, h)
            assert(((h.bonus and h.bonus.defense) or 0) == held,
                "what hardens a paladin is having BORNE the thing, so a Cure does not take it back")
        end,
    },
    {
        name = "Oathkeeper's Litany braces the rank beside the paladin and not the paladin",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "ability_oathkeepers_litany" } })
            local ally = Fixture.unit("character_rowan", 3, 4, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 3, 2, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero, ally }, { foe })
            local h, a, f = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            assert(Fixture.strike(combat, h, h, "ability_oathkeepers_litany"), "the litany is said")
            assert(Status.has(a, "status_defending"), "the ally beside them is braced")
            assert(not Status.has(h, "status_defending"),
                "the paladin is not -- a litany is said FOR somebody")
            assert(not Status.has(f, "status_defending"), "and the adjacent foe hears only Latin")
        end,
    },

    -- PLAGUE KNIGHT ---------------------------------------------------------------------------------
    {
        name = "the Plaguebearer's Draught makes the knight the source, and Contagion spreads from it",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_rowan", 3, 3, { isolate = "bare", items = {
                "consumable_plaguebearers_draught", "utility_contagion",
            } })
            local near = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { health = 300 } })
            local far = Fixture.unit("character_bandit", 3, 5, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero }, { near, far })
            local h, a, b = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            assert(Fixture.strike(combat, h, h, "consumable_plaguebearers_draught"), "the draught is drunk")
            assert(Status.has(h, "status_poison"), "the knight is the source")
            assert(Status.has(a, "status_poison"), "and whatever stood beside it caught it at once")
            assert(not Status.has(b, "status_poison"), "the one a tile further off did not")

            -- One step per turn: the far bandit catches it from the near one, not from the knight.
            local caught = Combat.spreadContagion(combat, h)
            assert(caught >= 1, "the sickness travels")
            assert(Status.has(b, "status_poison"), "reaching the next body in the line")
        end,
    },
    {
        name = "contagion gathers before it applies, so it cannot chain a whole line in one turn",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_rowan", 1, 1, { isolate = "bare", items = { "utility_contagion" } })
            local a = Fixture.unit("character_bandit", 5, 5, { isolate = "bare", stats = { health = 300 } })
            local b = Fixture.unit("character_bandit", 5, 6, { isolate = "bare", stats = { health = 300 } })
            local c = Fixture.unit("character_bandit", 5, 7, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero }, { a, b, c })
            local h, u1, u2, u3 = combat.units[1], combat.units[2], combat.units[3], combat.units[4]

            Status.apply(combat, u1, "status_poison")
            Combat.spreadContagion(combat, h)
            assert(Status.has(u2, "status_poison"), "the neighbour catches it")
            assert(not Status.has(u3, "status_poison"),
                "the one past them does not -- a plague travels, it does not teleport")
        end,
    },
    {
        name = "the Rot-Fume Gauntlet reads the whole field, the bearer's own sickness included",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_rowan", 3, 3,
                { isolate = "bare", items = { "utility_rot_fume_gauntlet", "weapon_iron_sword" } })
            local foe = Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            local sword = nil
            for _, it in ipairs(h.char.inventory) do
                if it and it.id == "weapon_iron_sword" then sword = it end
            end
            local clean = Combat.computeDamage(combat, h, f, sword)
            Status.apply(combat, h, "status_poison") -- the bearer's OWN sickness counts
            local sick = Combat.computeDamage(combat, h, f, sword)
            assert(sick > clean, "a plague knight standing sick hits harder for it")
        end,
    },

    -- THEURGE ---------------------------------------------------------------------------------------
    {
        name = "Vigil Beads refuse every interruption, where steadfast only ever saved one weapon",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 3, 3,
                { isolate = "bare", items = { "utility_vigil_beads" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            h.channel = { ab = {}, item = { name = "a working" }, tx = 1, ty = 1 }
            Status.apply(combat, h, "status_channeling")
            assert(not Combat.interruptChannel(combat, h, "stunned"),
                "the wind-up declines to be broken")
            assert(h.channel, "and is still standing")
        end,
    },
    {
        name = "The Long Prayer widens with the wind-up it actually served",
        fn = function()
            local map = Fixture.new(14, 14)
            local hero = Fixture.unit("character_amana", 4, 4,
                { isolate = "bare", items = { "ability_the_long_prayer" } })
            local foe = Fixture.unit("character_bandit", 13, 13, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            local Hazard = require("models.hazard")
            -- A channelled ability BEGINS a wind-up rather than resolving; the ground arrives when the
            -- channel does. That is the bet the whole discipline is built on, so the test takes it too.
            assert(Fixture.strike(combat, h, { x = 6, y = 4 }, "ability_the_long_prayer"), "the prayer is begun")
            assert(h.channel, "the theurge is winding up")
            assert(not Hazard.at(combat, 6, 4, "hazard_sacred"), "and nothing has landed yet")

            assert(Combat.resolveChannel(combat, h), "the prayer finishes")
            assert(Hazard.at(combat, 6, 4, "hazard_sacred"), "and ground is sanctified even at no wind-up")
        end,
    },
    {
        name = "Benediction reaches every ally wherever they are standing",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_amana", 2, 2,
                { isolate = "bare", items = { "ability_benediction" } })
            local far = Fixture.unit("character_rowan", 10, 10, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero, far }, { foe })
            local h, a = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            a.char.stats.health.current = 5

            assert(Fixture.strike(combat, h, h, "ability_benediction"), "the blessing is begun")
            assert(Combat.resolveChannel(combat, h), "and finishes")
            assert(a.char.stats.health.current > 5,
                "and reaches the ally eight tiles away -- it is addressed to none of them")
        end,
    },

    -- APOTHECARY ------------------------------------------------------------------------------------
    {
        name = "The Shared Ledger lends the apothecary's guard to whoever it heals",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3,
                { isolate = "bare", items = { "utility_shared_ledger", "ability_transfusion" } })
            local ally = Fixture.unit("character_rowan", 3, 4, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero, ally }, { foe })
            local h, a = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            h.char.stats.health.current = h.char.stats.health.max
            a.char.stats.health.current = 5

            assert(Fixture.strike(combat, h, a, "ability_transfusion"), "vitality is lent")
            assert(a.char.stats.health.current > 5, "the ally is healed")
            assert(Status.has(a, "status_lent_guard"),
                "and borrows the apothecary's own guard -- every other heal in the game merely gives")
        end,
    },
    {
        name = "Transfusion previews the vitality it lends, without spending it",
        fn = function()
            -- The lend is drawn from the caster and poured into the ally in one effect, so its whole
            -- output hangs off what fx.drain REPORTS. A dry run that answered 0 (as it once did) fed
            -- fx.heal nothing, and the ability previewed -- on the board and to the AI's scorer -- as a
            -- cast that did nothing at all.
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3,
                { isolate = "bare", items = { "ability_transfusion" } })
            local ally = Fixture.unit("character_rowan", 3, 4, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero, ally }, { foe })
            local h, a = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            h.char.stats.health.current = h.char.stats.health.max
            a.char.stats.health.current = 5

            local before = h.char.stats.health.current
            local pv = Combat.previewAbility(combat, h, Fixture.itemNamed(h.char, "ability_transfusion"),
                a.x, a.y)
            local e = pv and pv.entries[a]
            assert(e and e.heal > 0, "the ally's forecast quotes the vitality coming its way")
            assert(h.char.stats.health.current == before, "and the caster pays nothing for being hovered")

            -- ...and the live cast moves exactly the figure the preview promised.
            local previewed = e.heal
            assert(Fixture.strike(combat, h, a, "ability_transfusion"), "vitality is lent")
            assert(a.char.stats.health.current == 5 + previewed, "the ally gains what was previewed")
            assert(h.char.stats.health.current == before - previewed, "and the caster loses that same amount")
        end,
    },
    {
        name = "Borrowed Hands reads the party rather than a number in its own file",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3,
                { isolate = "bare", items = { "consumable_borrowed_hands" } })
            local caster = Fixture.unit("character_mage", 3, 4, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero, caster }, { foe })
            local h, m = combat.units[1], combat.units[2]

            local mine = h.char.stats.magicDamage
            local best = m.char.stats.magicDamage
            assert(Fixture.strike(combat, h, h, "consumable_borrowed_hands"), "the elixir is drunk")
            if best > mine then
                assert((h.bonus and h.bonus.magicDamage or 0) == best - mine,
                    "the apothecary is raised exactly to the best in the party, no further")
            end
        end,
    },
    {
        name = "The Tithe copies allies' blessings and leaves their afflictions where they are",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3,
                { isolate = "bare", items = { "consumable_the_tithe" } })
            local ally = Fixture.unit("character_rowan", 3, 4, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero, ally }, { foe })
            local h, a = combat.units[1], combat.units[2]

            Status.apply(combat, a, "status_inspiration")
            Status.apply(combat, a, "status_poison")

            assert(Fixture.strike(combat, h, h, "consumable_the_tithe"), "the tithe is collected")
            assert(Status.has(h, "status_inspiration"), "the blessing is copied over")
            assert(Status.has(a, "status_inspiration"), "and the ally keeps theirs -- nothing is taken")
            assert(not Status.has(h, "status_poison"), "the affliction is not tithed")
        end,
    },
}

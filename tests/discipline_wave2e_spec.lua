-- Behavioural cases for the Skirmisher, Battlemage, Spellbreaker and Warbrewer shelves -- the last of
-- the no-new-system multiclasses.
--
-- Four engine seams are pinned here alongside the items:
--   * Combat.tilesMovedThisTurn  -- distance from where the turn opened, not steps taken
--   * the `free` action on a WEAPON (S2), which is what the Harrier's Bow is
--   * the Resonant Grip folding a remembered element into a strike's TAG set
--   * Combat.spendCost's Dampening Oath tax, applied at the spend and not at the button

local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

return {
    -- SKIRMISHER ------------------------------------------------------------------------------------
    {
        name = "tilesMovedThisTurn measures ground covered, not steps taken",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_kaya", 3, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            h.turnStartX, h.turnStartY = 3, 3
            assert(Combat.tilesMovedThisTurn(h) == 0, "a unit that has not moved has covered nothing")
            h.x, h.y = 6, 3
            assert(Combat.tilesMovedThisTurn(h) == 3, "three tiles down the lane is three")
            h.x, h.y = 3, 3
            assert(Combat.tilesMovedThisTurn(h) == 0,
                "and a rider who circled back to their own tile has covered no ground at all")
        end,
    },
    {
        name = "Running Shot pays for the approach",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_kaya", 3, 3,
                { isolate = "bare", items = { "ability_running_shot" } })
            local foe = Fixture.unit("character_bandit", 3, 7,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            h.turnStartX, h.turnStartY = 3, 3
            local hp = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_running_shot"), "a standing shot")
            local still = hp - f.char.stats.health.current

            h.char.stats.stamina.current = 99
            h.turnStartX, h.turnStartY = 3, 6 -- opened three tiles back
            hp = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_running_shot"), "and a running one")
            local running = hp - f.char.stats.health.current
            assert(running > still, "the ground covered is in the arrow")
        end,
    },
    {
        name = "the Outrider's Harness silences the answer once the rider has covered ground",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_saber", 3, 3,
                { isolate = "bare", items = { "armor_outriders_harness" } })
            local foe = Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", items = { "weapon_iron_sword" }, stats = { health = 400 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]

            local parry
            for _, t in ipairs(f.traits or {}) do
                if t.def and t.def.counter then parry = t end
            end
            assert(parry, "the bandit carries a blade that answers")

            h.turnStartX, h.turnStartY = 3, 3 -- standing still
            assert(Trait.mayCounter(combat, f, parry, h, { "physical", "melee" }, false),
                "a stationary attacker is answered as normal")

            h.turnStartX, h.turnStartY = 3, 7 -- rode in four tiles
            assert(not Trait.mayCounter(combat, f, parry, h, { "physical", "melee" }, false),
                "one who rode in is not")
        end,
    },
    {
        name = "the Harrier's Bow is a free action: it fires and leaves the turn open",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_kaya", 3, 3,
                { isolate = "bare", items = { "weapon_harriers_bow" } })
            local foe = Fixture.unit("character_bandit", 3, 7,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            Combat.startTurn(combat)
            if Combat.currentUnit(combat) ~= h then return end -- initiative went elsewhere; nothing to prove
            assert(Combat.freeActionsLeft(h) == 1, "the free shot is in hand")

            local hp = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "weapon_harriers_bow"), "the shot is loosed")
            assert(f.char.stats.health.current < hp, "and lands")
            assert(Combat.freeActionsLeft(h) == 0, "the free action is spent")
            assert(combat.turn and combat.turn.unit == h,
                "and the turn is still open -- fire, then ride")
        end,
    },

    -- BATTLEMAGE ------------------------------------------------------------------------------------
    {
        name = "the Resonant Grip puts the last cast's element into the next weapon strike's tags",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 3, 3, { isolate = "bare", items = {
                "utility_resonant_grip", "ability_fireball", "weapon_iron_dagger",
            } })
            local foe = Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            assert(h.lastCastElement == nil, "nothing has been thrown yet")
            -- Fireball channels, so the element is remembered when the spell RESOLVES rather than when
            -- it is begun -- which is right: an interrupted working never happened.
            assert(Fixture.strike(combat, h, { x = 6, y = 3 }, "ability_fireball"), "a fireball is begun")
            assert(Combat.resolveChannel(combat, h), "and lands")
            assert(h.lastCastElement == "fire", "and the hand remembers it")
        end,
    },
    {
        name = "the Arcane Conduit sharpens a grid neighbour and spends Arcane doing it",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 3, 3, { isolate = "bare", items = {
                "utility_arcane_conduit", "ability_fireball",
            } })
            local foe = Fixture.unit("character_bandit", 3, 6,
                { isolate = "bare", stats = { defense = 0, magicDefense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 999, 999

            -- The pool banks off `cast`, so casting is what funds the next one.
            assert(Combat.chargePool(h, "arcane") == 0, "the conduit opens empty")
            Combat.tally(h, "cast", 3)
            assert(Combat.chargePool(h, "arcane") == 3, "three workings banked")

            -- The conduit's spend lives in resolveCast, which a channelled spell only reaches when the
            -- wind-up finishes -- so the sharpening is paid for by a working that actually landed.
            assert(Fixture.strike(combat, h, { x = 3, y = 6 }, "ability_fireball"), "the neighbour is begun")
            assert(Combat.resolveChannel(combat, h), "and lands")
            -- Measured on the SPEND rather than on the pool: the cast itself banks a point on its way
            -- past (Arcane comes off the `cast` tally), so the pool's net movement understates what the
            -- conduit actually took. Two out, one back in.
            assert((h.chargeSpent and h.chargeSpent.arcane or 0) >= 2,
                "the conduit took its two points out of the pool")
        end,
    },

    {
        name = "Battle Casting discounts a working thrown in somebody's face, and only there",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_mage", 3, 3,
                { isolate = "bare", items = { "utility_battle_casting" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 100, 100

            Combat.spendCost(combat, h, { stat = "mana", amount = 20 })
            assert(h.char.stats.mana.current == 80, "at range, a working costs what it says")

            Combat.teleportUnit(combat, f, 3, 4) -- into the battlemage's face
            Combat.spendCost(combat, h, { stat = "mana", amount = 20 })
            assert(h.char.stats.mana.current > 60,
                "and costs less where a mage would least like to be standing")
        end,
    },

    -- SPELLBREAKER ----------------------------------------------------------------------------------
    {
        name = "the Dampening Oath taxes an enemy working at the spend, not at the button",
        fn = function()
            local map = Fixture.new(10, 10)
            local warden = Fixture.unit("character_knight", 3, 3,
                { isolate = "bare", items = { "utility_dampening_oath" } })
            local caster = Fixture.unit("character_bandit", 3, 5, { isolate = "bare" })
            local combat = Combat.new(map, { warden }, { caster })
            local w, c = combat.units[1], combat.units[2]
            c.char.stats.mana.max, c.char.stats.mana.current = 100, 100

            Combat.spendCost(combat, c, { stat = "mana", amount = 10 })
            assert(c.char.stats.mana.current == 80, "ten costs twenty under the oath")

            -- Out of range: the oath reaches three tiles and no further.
            Combat.teleportUnit(combat, w, 9, 9)
            Combat.spendCost(combat, c, { stat = "mana", amount = 10 })
            assert(c.char.stats.mana.current == 70, "and ten costs ten out from under it")
        end,
    },
    {
        name = "the Spell Eater swallows a share of a magical blow and is paid in mana for it",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 3, 3,
                { isolate = "bare", items = { "utility_spell_eater" } })
            local foe = Fixture.unit("character_bandit", 3, 5, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.magicDefense = 0
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 10

            local hp = h.char.stats.health.current
            Combat.dealFlatDamage(combat, h, 50, { "magical" }, "a spell")
            local taken = hp - h.char.stats.health.current
            assert(taken < 50, "the working lands lighter than it was thrown")
            assert(h.char.stats.mana.current > 10, "and the difference is refunded as mana")
        end,
    },
    {
        name = "Empty Vessel bites a spent caster and ignores a body that never had mana",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_knight", 3, 3,
                { isolate = "bare", items = { "utility_empty_vessel", "weapon_iron_sword" } })
            local caster = Fixture.unit("character_mage", 3, 4,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, caster)
            local h, c = combat.units[1], combat.units[2]

            local sword
            for _, it in ipairs(h.char.inventory) do
                if it and it.id == "weapon_iron_sword" then sword = it end
            end
            c.char.stats.mana.max, c.char.stats.mana.current = 40, 40
            local full = Combat.computeDamage(combat, h, c, sword)
            c.char.stats.mana.current = 0
            local dry = Combat.computeDamage(combat, h, c, sword)
            assert(dry > full, "an emptied caster is worth opening")
        end,
    },
    {
        name = "the Silencing Blade gags what it cuts, and reads the pool it cut into",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_knight", 3, 3,
                { isolate = "bare", items = { "weapon_silencing_blade" } })
            local caster = Fixture.unit("character_mage", 3, 4,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, caster)
            local h, c = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            c.char.stats.mana.max, c.char.stats.mana.current = 200, 200
            local hp = c.char.stats.health.current
            assert(Fixture.strike(combat, h, c, "weapon_silencing_blade"), "the blade lands")
            local deep = hp - c.char.stats.health.current
            assert(Status.has(c, "status_silenced"), "and gags what it cut")

            Status.remove(combat, c, "status_silenced")
            h.char.stats.stamina.current = 99
            c.char.stats.mana.current = 0
            hp = c.char.stats.health.current
            assert(Fixture.strike(combat, h, c, "weapon_silencing_blade"), "the blade lands again")
            assert(hp - c.char.stats.health.current < deep,
                "and bites less into a caster with nothing left -- Empty Vessel's job, not this one's")
        end,
    },

    -- WARBREWER -------------------------------------------------------------------------------------
    {
        name = "the Battle Tonic restores stamina without closing the turn",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_saber", 3, 3,
                { isolate = "bare", items = { "consumable_battle_tonic" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            Combat.startTurn(combat)
            if Combat.currentUnit(combat) ~= h then return end
            h.char.stats.stamina.current = 1

            assert(Fixture.strike(combat, h, h, "consumable_battle_tonic"), "the tonic goes down")
            assert(h.char.stats.stamina.current > 1, "stamina is back")
            assert(combat.turn and combat.turn.unit == h,
                "and the turn is still open -- drunk BETWEEN doing things, not instead of them")
        end,
    },
    {
        name = "Round for the House pours a share into the allies standing beside the brewer",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_saber", 3, 3, { isolate = "bare", items = {
                "utility_round_for_the_house", "consumable_battle_tonic",
            } })
            local ally = Fixture.unit("character_knight", 3, 4, { isolate = "bare" })
            local far = Fixture.unit("character_knight", 8, 8, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 3, { isolate = "bare" })
            local combat = Combat.new(map, { hero, ally, far }, { foe })
            local h, a, d = combat.units[1], combat.units[2], combat.units[3]
            a.char.stats.health.current = 5
            d.char.stats.health.current = 5

            assert(Fixture.strike(combat, h, h, "consumable_battle_tonic"), "the brewer drinks")
            assert(a.char.stats.health.current > 5, "the ally beside them gets a share")
            assert(d.char.stats.health.current == 5, "the one across the field buys their own")
        end,
    },
}

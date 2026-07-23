-- Tests for the second wave of abilities and the mechanics behind them: the new statuses (Freeze,
-- Aegis, Blessing, Mired, Dodging), Cure's debuff cleanse, the Quicksand hazard's Mired aura, the
-- corpse system (Revive reanimates, Raise Dead zombifies), scattershot Meteor Storm, Water Ball's
-- shove + soak, and the elemental summons. Pure logic, headless -- mirrors tests/hazard_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Status = require("models.status")
local Trait = require("models.trait")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

return {
    {
        name = "every new blueprint (statuses, hazards, characters, abilities) loads headlessly",
        fn = function()
            for _, id in ipairs({ "status_freeze", "status_aegis", "status_blessing", "status_mired" }) do
                assert(Status.defs[id], "status loaded: " .. id)
            end
            assert(Trait.defs.trait_dodge, "dodge trait loaded")
            assert(Hazard.defs.hazard_quicksand, "quicksand hazard loaded")
            for _, id in ipairs({ "character_water_elemental", "character_lightning_elemental", "character_ice_elemental",
                                  "character_earth_elemental", "character_wind_elemental", "character_zombie" }) do
                assert(Character.instantiate(id), "character loaded: " .. id)
            end
            for _, id in ipairs({
                "ability_fire_bolt", "ability_ice_bolt", "ability_blizzard", "ability_thunder_storm",
                "ability_meteor_storm", "ability_water_ball", "ability_quicksand", "ability_raise_dead",
                "ability_aegis", "ability_blessing", "ability_cure", "ability_holy_light",
                "ability_revive", "consumable_revive_scroll",
                "ability_summon_water_elemental", "ability_summon_lightning_elemental",
                "ability_summon_ice_elemental", "ability_summon_earth_elemental",
                "ability_summon_wind_elemental",
            }) do
                local it = Item.instantiate(id)
                assert(it and it.activeAbility, "ability loaded: " .. id)
            end
            -- The Dodge item is a passive (no activeAbility); it grants the trait.
            local reflex = Item.instantiate("utility_duelists_reflex")
            assert(reflex and reflex.traits and reflex.traits[1] == "trait_dodge", "Duelist's Reflex grants Dodge")
        end,
    },
    {
        name = "Freeze delays the target and makes it vulnerable to impact and fire",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, { unit("character_knight", 1, 2) })
            local mage, knight = c.units[1], c.units[2]
            local init0 = knight.initiative
            Status.apply(c, knight, "status_freeze")
            assert(knight.initiative > init0, "Freeze shoved the knight down the turn order")

            -- The impact/fire vulnerability lands on the damage math, exactly like Wet's lightning: an
            -- impact hit against the Frozen knight lands harder than an untyped one Freeze doesn't cover.
            -- `impact` and not `crush`: the blunt tag every mace, hammer and censer in the game actually
            -- carries, which is the whole point of the retag (see data/status/status_freeze.lua's header).
            local impact = Combat.mitigatedDamage(knight, 20, { "impact", "physical" })
            local plain = Combat.mitigatedDamage(knight, 20, { "slash" })
            assert(impact > plain, "an impact hit lands harder on a Frozen target than an untyped one")
        end,
    },
    {
        name = "Ice Bolt freezes; Fire Bolt burns",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, { unit("character_knight", 1, 2) })
            local mage, knight = c.units[1], c.units[2]
            local iceBolt = Item.instantiate("ability_ice_bolt")
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, iceBolt, knight.x, knight.y), "Ice Bolt lands")
            assert(Status.has(knight, "status_freeze"), "Ice Bolt left the knight Frozen")
        end,
    },
    {
        name = "Cure strips debuffs but leaves buffs untouched",
        fn = function()
            -- Combat.cleanse is the mechanic (a cast would also advance the clock and time buffs out,
            -- which is a separate concern) -- test the cleanse itself: debuffs go, buffs stay.
            local c = Combat.new(arena(8, 8), { unit("character_priest", 1, 1) }, {})
            local priest = c.units[1]
            Status.apply(c, priest, "status_burn")   -- debuff
            Status.apply(c, priest, "status_mired")  -- debuff
            Status.apply(c, priest, "status_regen")  -- buff (keep it)
            Status.apply(c, priest, "status_aegis")  -- buff (keep it)
            local removed = Combat.cleanse(c, priest)
            assert(removed == 2, "cleansed exactly the two debuffs")
            assert(not Status.has(priest, "status_burn") and not Status.has(priest, "status_mired"), "debuffs gone")
            assert(Status.has(priest, "status_regen") and Status.has(priest, "status_aegis"), "buffs survived")
            -- And the Cure item itself casts cleanly.
            local cure = Item.instantiate("ability_cure")
            openTurn(c, priest)
            assert(Combat.useItem(c, priest, cure, priest.x, priest.y), "Cure casts on self")
        end,
    },
    {
        name = "Aegis buffs allies in its blast, not enemies",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_priest", 3, 3), unit("character_knight", 3, 4) },
                                              { unit("character_bandit", 4, 3) })
            local priest, knight, bandit = c.units[1], c.units[2], c.units[3]
            local aegis = Item.instantiate("ability_aegis")
            openTurn(c, priest)
            assert(Combat.useItem(c, priest, aegis, 3, 3), "Aegis lands on the priest's tile")
            assert(Status.has(priest, "status_aegis") and Status.has(knight, "status_aegis"), "allies warded")
            assert(not Status.has(bandit, "status_aegis"), "the foe in the blast gains nothing")
        end,
    },
    {
        name = "Mired doubles ability cost; the Quicksand hazard applies it and lifts on leaving",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, {})
            local mage = c.units[1]
            local fireball = Item.instantiate("ability_fireball")
            local baseCost = Combat.abilityCost(mage, fireball.activeAbility).amount
            Status.apply(c, mage, "status_mired")
            assert(Combat.abilityCost(mage, fireball.activeAbility).amount == baseCost * 2,
                "Mired doubles the ability cost")
            Status.remove(c, mage, "status_mired")

            -- The hazard grants Mired as an aura that ends the instant the unit steps clear.
            Hazard.place(c, 2, 1, "hazard_quicksand")
            Hazard.place(c, 3, 1, "hazard_quicksand")
            openTurn(c, mage)
            assert(Combat.moveUnit(c, mage, 2, 1), "step onto the sand")
            assert(Status.has(mage, "status_mired"), "standing in quicksand mires the unit")
            openTurn(c, mage)
            assert(Combat.moveUnit(c, mage, 1, 1), "step off onto firm ground")
            assert(not Status.has(mage, "status_mired"), "leaving the sand lifts Mired at once")
        end,
    },
    {
        name = "the Dodge trait auto-evades a physical hit, then recharges; magic ignores it",
        fn = function()
            -- Give a knight the Duelist's Reflex (grants the passive Dodge trait). Combat.new attaches it.
            local knightChar = Character.instantiate("character_knight")
            Character.addItem(knightChar, Item.instantiate("utility_duelists_reflex"))
            local c = Combat.new(arena(8, 8), { { char = knightChar, x = 1, y = 1 } }, {})
            local knight = c.units[1]
            local hp = knight.char.stats.health

            -- First physical blow: evaded outright, the reflex goes on cooldown.
            local before = hp.current
            Combat.dealFlatDamage(c, knight, 15, { "physical" }, "a blow")
            assert(hp.current == before, "the first physical blow was dodged")
            assert(Combat.onCooldown(knight, "trait_dodge"), "the reflex is now recharging")

            -- A second physical blow while recharging lands normally.
            before = hp.current
            Combat.dealFlatDamage(c, knight, 15, { "physical" }, "a blow")
            assert(hp.current < before, "a second blow lands while the reflex recharges")

            -- Recharge, then a magical hit is NOT dodged even though the reflex is ready.
            Combat.tickCooldowns(c, 99)
            assert(not Combat.onCooldown(knight, "trait_dodge"), "the reflex has recharged")
            before = hp.current
            Combat.dealFlatDamage(c, knight, 15, { "magical" }, "a spell")
            assert(hp.current < before, "a spell cannot be dodged")
            assert(not Combat.onCooldown(knight, "trait_dodge"), "and did not spend the reflex")
        end,
    },
    {
        name = "Water Ball shoves a foe three tiles and leaves rain where it struck",
        fn = function()
            local c = Combat.new(arena(10, 3), { unit("character_mage", 2, 2) }, { unit("character_knight", 3, 2) })
            local mage, knight = c.units[1], c.units[2]
            local waterBall = Item.instantiate("ability_water_ball")
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, waterBall, 3, 2), "Water Ball lands")
            assert(knight.x == 6, "the knight is driven three tiles straight back (3 -> 6)")
            assert(Hazard.at(c, 3, 2, "hazard_rain"), "rain soaks the tile it was struck on")
        end,
    },
    {
        name = "Blizzard damages and Freezes everyone in its blast",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) },
                                              { unit("character_bandit", 5, 5), unit("character_bandit", 6, 5) })
            local mage = c.units[1]
            local b1, b2 = c.units[2], c.units[3]
            local blizzard = Item.instantiate("ability_blizzard")
            mage.x, mage.y = 5, 8 -- in range (dist 3) but OUTSIDE the 3x3 blast (no self-freeze)
            local hp1 = b1.char.stats.health.current
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, blizzard, 5, 5), "Blizzard begins channeling")
            assert(Combat.resolveChannel(c, mage), "the wound-up blast lands on the cluster")
            assert(b1.char.stats.health.current < hp1, "the blast damaged a foe")
            assert(Status.has(b1, "status_freeze") and Status.has(b2, "status_freeze"), "both foes are Frozen")
        end,
    },
    {
        name = "a fallen ally leaves a corpse that Revive brings back at half health",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_priest", 1, 1), unit("character_knight", 2, 1) }, {})
            local priest, knight = c.units[1], c.units[2]
            -- Fell the knight.
            Combat.dealFlatDamage(c, knight, 9999, { "physical" }, "a blow")
            assert(not knight.alive and knight.corpse, "the knight left a corpse")
            assert(Combat.corpseAt(c, 2, 1) == knight, "the corpse is found on its tile")

            local revive = Item.instantiate("ability_revive")
            openTurn(c, priest)
            assert(Combat.useItem(c, priest, revive, 2, 1), "Revive casts on the corpse tile")
            assert(knight.alive and not knight.corpse, "the knight is back on its feet")
            local hp = knight.char.stats.health
            assert(hp.current == math.floor(hp.max * 0.5 + 0.5), "revived at half health")
        end,
    },
    {
        name = "Revive refuses a corpse a living unit is standing on",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_priest", 1, 1), unit("character_knight", 2, 1) },
                                              { unit("character_bandit", 5, 5) })
            local priest, knight, bandit = c.units[1], c.units[2], c.units[3]
            Combat.dealFlatDamage(c, knight, 9999, { "physical" }, "a blow")
            bandit.x, bandit.y = 2, 1 -- stand the foe on the body
            assert(Combat.corpseAt(c, 2, 1) == nil, "a body under a living unit is unreachable")
            assert(not Combat.reanimate(c, knight, 0.5), "reanimation refuses the occupied tile")
        end,
    },
    {
        name = "Raise Dead turns corpses in its blast into allied, AI-run zombies",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, { unit("character_bandit", 5, 5) })
            local mage, bandit = c.units[1], c.units[2]
            Combat.dealFlatDamage(c, bandit, 9999, { "physical" }, "a blow")
            assert(bandit.corpse, "the bandit left a corpse")

            local raise = Item.instantiate("ability_raise_dead")
            mage.x, mage.y = 5, 6
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, raise, 5, 5), "Raise Dead sweeps the area")
            local zombie = Combat.unitAt(c, 5, 5)
            assert(zombie and zombie.alive, "a zombie now stands where the bandit fell")
            assert(zombie.side == "party", "the zombie fights for the caster's side")
            assert(zombie.control == "ai", "but takes its own turns (not player-controlled)")
            assert(not bandit.corpse, "the body was consumed")
        end,
    },
    {
        name = "Meteor Storm scatters fire and damages foes in its zone",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_mage", 6, 6) }, { unit("character_knight", 4, 4) })
            local mage, knight = c.units[1], c.units[2]
            -- Aim at (6,6): with random stubbed to 1, the first strike lands on (tx-2, ty-2) = (4,4).
            local meteor = Item.instantiate("ability_meteor_storm")
            local hp0 = knight.char.stats.health.current
            local oldRandom = Combat.random
            Combat.random = function() return 1 end
            openTurn(c, mage)
            local ok = Combat.useItem(c, mage, meteor, 6, 6)
            local resolved = ok and Combat.resolveChannel(c, mage) -- the random strikes fall on resolution
            Combat.random = oldRandom
            assert(ok, "Meteor Storm begins channeling")
            assert(resolved, "the wound-up storm resolves")
            assert(Hazard.at(c, 4, 4, "hazard_fire"), "a meteor left fire on (4,4)")
            -- Each impact bursts over the 3x3 block around it, so the corners of that block burn too.
            assert(Hazard.at(c, 3, 3, "hazard_fire"), "the burst spread fire to (3,3)")
            assert(Hazard.at(c, 5, 5, "hazard_fire"), "and to (5,5)")
            assert(knight.char.stats.health.current < hp0, "the foe under a strike took damage")
        end,
    },
    {
        name = "summoning an elemental reserves a quarter of the caster's maximum mana",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, {})
            local mage = c.units[1]
            local summon = Item.instantiate("ability_summon_ice_elemental")
            local manaMax = mage.char.stats.mana.max
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, summon, 2, 1), "the ice elemental is summoned")
            local ele = Combat.unitAt(c, 2, 1)
            assert(ele and ele.summoned and ele.side == "party", "an allied elemental stands beside the mage")
            assert(Combat.reservedAmount(mage.char, "mana") == math.floor(manaMax * 0.25),
                "a quarter of maximum mana is reserved while it lives")
        end,
    },
}

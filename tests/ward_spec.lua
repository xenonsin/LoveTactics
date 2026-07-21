-- Tests for the wards and reflexes added alongside the transformation system: multi-hit barriers,
-- the two mirrors (Reflect Magic / Reflect Steel), Counter Magic, Sleep's break-on-damage, magic
-- denial, flight, and the two potion-drinking reflexes. Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

local function armed(id, ids)
    local char = Character.instantiate(id)
    char.inventory = {}
    for _, itemId in ipairs(ids) do Character.addItem(char, Item.instantiate(itemId)) end
    return char
end

return {
    {
        name = "a barrier stands for as many hits as it was granted, then is spent",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            Status.apply(c, bandit, "status_physical_barrier", { magnitude = 3 })

            for i = 1, 3 do
                assert(Combat.dealFlatDamage(c, bandit, 30, { "physical" }, "test") == 0,
                    "hit " .. i .. " is swallowed")
                assert(Status.has(bandit, "status_physical_barrier") == (i < 3),
                    "the ward stands until its last charge is spent")
            end
            assert(Combat.dealFlatDamage(c, bandit, 30, { "physical" }, "test") > 0,
                "the fourth hit lands: the ward is gone")
        end,
    },
    {
        name = "forging a barrier buys coverage: more hits, not a bigger number",
        fn = function()
            local base = Item.instantiate("ability_physical_barrier", 1, 0)
            local forged = Item.instantiate("ability_physical_barrier", 1, 10)
            assert(base.activeAbility.hits == 1, "a base ward swallows one blow")
            assert(forged.activeAbility.hits > base.activeAbility.hits,
                "a fully forged one swallows more")
            -- `hits` is the ability's magnitude, so it heads the tooltip and arrives as fx.amount.
            local value, label = Item.primaryStat(forged)
            assert(label == "Hits" and value == forged.activeAbility.hits,
                "and it is the stat the item leads with")
        end,
    },
    {
        name = "Reflect Magic turns a single-target spell back on its caster, and spares an area one",
        fn = function()
            local caster = armed("character_mage", { "ability_fire_bolt", "ability_fireball" })
            -- A BARE knight: the blueprint's own kit carries Parry, whose counter-swing would land on
            -- the mage and be indistinguishable here from a reflection. The mirror is what's on trial.
            local c = Combat.new(arena(10, 10), { { char = armed("character_knight", {}), x = 5, y = 4 } },
                { { char = caster, x = 5, y = 5 } })
            local knight, mage = c.units[1], c.units[2]

            Status.apply(c, knight, "status_reflect_magic")
            local mageHp = mage.char.stats.health.current
            local knightHp = knight.char.stats.health.current

            -- Thrown through dealDamage rather than useItem, for the same reason the area half below is:
            -- the ward path lives in dealDamage, and useItem would also run Fire Bolt's OTHER effect --
            -- the Burn it leaves on its target, which no mirror ever claimed to catch. That Burn sears on
            -- the clock, so the rebase ending the cast would cost the knight a point of health and this
            -- assertion could no longer tell a reflected bolt from a landed one.
            Combat.dealDamage(c, mage, knight, caster.inventory[1]) -- Fire Bolt: single target
            assert(knight.char.stats.health.current == knightHp, "the mirrored bolt does not land")
            assert(mage.char.stats.health.current < mageHp, "it lands on the mage instead")

            -- An area spell has no single thread back to its caster, so the mirror does not catch it.
            -- Fireball is CHANNELED, so it is thrown through Combat.dealDamage directly here rather
            -- than through useItem (which would only start the wind-up) -- the ward path being tested
            -- lives in dealDamage either way.
            mageHp = mage.char.stats.health.current
            knightHp = knight.char.stats.health.current
            local fireball = caster.inventory[2]
            assert(fireball.activeAbility.aoe, "fixture check: Fireball is an area spell")
            Combat.dealDamage(c, mage, knight, fireball)
            assert(knight.char.stats.health.current < knightHp, "an area spell goes through the mirror")
            assert(mage.char.stats.health.current == mageHp, "and does not rebound")
        end,
    },
    {
        name = "Reflect Steel mirrors a blade, and two mirrors do not catch each other",
        fn = function()
            -- Bare bodies on both sides: a blueprint's stock reflex (the knight's Parry) would answer
            -- the swing and muddy what the assertion is actually measuring.
            local c = Combat.new(arena(8, 8), { { char = armed("character_knight", { "weapon_iron_sword" }), x = 1, y = 1 } },
                { { char = armed("character_bandit", {}), x = 1, y = 2 } })
            local knight, bandit = c.units[1], c.units[2]
            -- Both sides mirrored: the first mirror to catch the blow is the one that throws it, and
            -- the return must not bounce back and forth forever.
            Status.apply(c, knight, "status_reflect_physical")
            Status.apply(c, bandit, "status_reflect_physical")

            local knightHp = knight.char.stats.health.current
            Combat.dealDamage(c, knight, bandit, Combat.defaultWeapon(knight.char))
            assert(knight.char.stats.health.current < knightHp,
                "the bandit's mirror throws the knight's own swing back at it")
        end,
    },
    {
        name = "Counter Magic unravels a spell for mana, then must recharge",
        fn = function()
            local caster = armed("character_mage", { "ability_fire_bolt" })
            local target = armed("character_mage", { "utility_counter_magic" }) -- a mage has the mana to run it
            local c = Combat.new(arena(8, 8), { { char = target, x = 5, y = 4 } },
                { { char = caster, x = 5, y = 5 } })
            local warded, attacker = c.units[1], c.units[2]

            local hp = warded.char.stats.health.current
            local mana = warded.char.stats.mana.current
            -- Through dealDamage, where the ward lives: useItem would also land Fire Bolt's Burn, which
            -- the counter does not stop and which now sears on the clock (see the mirror spec above).
            Combat.dealDamage(c, attacker, warded, caster.inventory[1])
            assert(warded.char.stats.health.current == hp, "the spell is unravelled entirely")
            assert(warded.char.stats.mana.current < mana, "and paid for in the warded mage's mana")

            -- On cooldown now: the next spell in the same flurry gets through.
            hp = warded.char.stats.health.current
            Combat.dealDamage(c, attacker, warded, caster.inventory[1])
            assert(warded.char.stats.health.current < hp, "a second spell lands while it recharges")
        end,
    },
    {
        name = "Sleep shoves the sleeper down the order, and any hit wakes it and refunds the rest",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local bandit = c.units[2]
            bandit.char.stats.magicDefense = 0
            local before = bandit.initiative

            local s = Status.apply(c, bandit, "status_sleep")
            assert(bandit.initiative == before + s.remaining, "the sleeper is shoved by what it sleeps")

            -- Any damage at all wakes it and hands back the time it had not served.
            Combat.dealFlatDamage(c, bandit, 5, { "physical" }, "test")
            assert(not Status.has(bandit, "status_sleep"), "the blow wakes it")
            assert(bandit.initiative == before, "and gives back every unserved tick")
        end,
    },
    {
        name = "a natural sleep refunds nothing: the sleeper genuinely waited",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local bandit = c.units[2]
            bandit.char.stats.magicDefense = 0
            local before = bandit.initiative
            local s = Status.apply(c, bandit, "status_sleep")
            local shove = s.remaining

            Status.tick(c, shove) -- the whole window elapses
            assert(not Status.has(bandit, "status_sleep"), "the sleep runs out on its own")
            assert(bandit.initiative == before + shove,
                "and the shove stands -- a served sentence is not refunded")
        end,
    },
    {
        name = "the Skeptic's Harness denies its wearer magic, but not a potion or a blade",
        fn = function()
            local char = armed("character_knight", { "armor_skeptics_harness", "ability_fire_bolt", "weapon_iron_sword",
                                           "consumable_healing_potion" })
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]

            assert(Status.has(knight, "status_magic_denied"), "the harness lays its denial at the bell")
            local spell, sword, potion = char.inventory[2], char.inventory[3], char.inventory[4]
            assert(Combat.itemBlockReason(knight, spell), "a spell is refused")
            assert(Combat.itemBlockReason(knight, spell).kind == "denied", "and says why")
            assert(not Combat.itemBlockReason(knight, sword), "a sword is not magic")
            assert(not Combat.itemBlockReason(knight, potion), "and neither is a draught")
        end,
    },
    {
        name = "the denial is not a debuff: a Panacea cannot wash it off and keep the armor",
        fn = function()
            local char = armed("character_knight", { "armor_skeptics_harness", "ability_fire_bolt" })
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]

            Combat.cleanse(c, knight)
            assert(Status.has(knight, "status_magic_denied"), "a cleanse does not lift a conviction")
            assert(Combat.itemBlockReason(knight, char.inventory[2]), "the spell is still refused")
        end,
    },
    {
        name = "Zephyr Striders cross any ground at cost 1, but never a wall",
        fn = function()
            local a = arena(8, 8)
            a.tiles[1][2] = { type = "water", moveCost = 3, walkable = false, sightCost = 0 }
            a.tiles[2][2] = { type = "bog", moveCost = 2, walkable = true, sightCost = 0 }

            local char = armed("character_knight", { "utility_zephyr_striders" })
            local c = Combat.new(a, { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 8, 8) })
            local knight = c.units[1]
            assert(Combat.isFlying(knight), "the wearer is airborne")

            local reach = Combat.reachable(c, knight)
            assert(reach["2,1"], "it crosses water nobody can walk on")
            assert(reach["2,1"].cost == 1, "at cost 1, got " .. tostring(reach["2,1"].cost))
            -- (2,2) is two tiles away, so cost 2 -- one per tile, and the bog's own moveCost of 3 is
            -- never paid. A grounded walker reaching the same cell pays 1 + 3 = 4.
            assert(reach["2,2"] and reach["2,2"].cost == 2,
                "the bog costs a flier nothing extra, got " .. tostring(reach["2,2"] and reach["2,2"].cost))

            -- The same knight, grounded, pays the terrain and cannot cross the water at all.
            Character.removeItem(char, char.inventory[1])
            Combat.refreshPassives(knight)
            assert(not Combat.isFlying(knight), "the boots are off")
            local grounded = Combat.reachable(c, knight)
            assert(not grounded["2,1"], "water is impassable on foot")
            assert(grounded["2,2"] and grounded["2,2"].cost == 3,
                "and the bog is slow, got " .. tostring(grounded["2,2"] and grounded["2,2"].cost))
        end,
    },
    {
        name = "the Survivor's Reflex drinks a healing potion when a blow leaves its bearer bloodied",
        fn = function()
            local char = armed("character_knight", { "utility_survivors_reflex", "consumable_healing_potion" })
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]
            local potion = char.inventory[2]
            local stock = potion.quantity

            -- A scratch does not trigger it: the reflex answers a wound, not a poke.
            Combat.dealFlatDamage(c, knight, 5, { "physical" }, "test")
            assert(potion.quantity == stock, "a light hit leaves the flask alone")

            -- A blow that takes it under the threshold does.
            -- Raw, and enough to land under the reflex's 0.4 share of a 70-point pool (the poke
            -- above was mitigated to 1, so the bearer is standing at 69 going into this).
            Combat.dealFlatDamage(c, knight, 45, { "physical" }, "test", nil, { raw = true })
            assert(potion.quantity == stock - 1, "the flask is opened on reflex")
            assert(knight.char.stats.health.current > 0, "and the knight is still standing")
        end,
    },
    {
        name = "the Alchemist's Reservoir casts a spell out of a flask when the mana runs dry",
        fn = function()
            local char = armed("character_mage", { "utility_alchemists_reservoir", "consumable_mana_potion", "ability_fire_bolt" })
            local c = Combat.new(arena(8, 8), { { char = char, x = 5, y = 4 } }, { unit("character_bandit", 5, 5) })
            local mage, bandit = c.units[1], c.units[2]
            local flask, spell = char.inventory[2], char.inventory[3]
            mage.char.stats.mana.current = 0 -- bone dry

            assert(not Combat.itemBlockReason(mage, spell),
                "the spell is not greyed out: the flask would cover it")
            local hp = bandit.char.stats.health.current
            assert(Combat.useItem(c, mage, spell, 5, 5), "and the cast goes through")
            assert(flask.quantity == 0, "the draught was drunk to pay for it")
            assert(bandit.char.stats.health.current < hp, "the bolt landed")
        end,
    },
    {
        name = "with no flask left, the Reservoir blocks the cast like any other empty pool",
        fn = function()
            local char = armed("character_mage", { "utility_alchemists_reservoir", "ability_fire_bolt" })
            local c = Combat.new(arena(8, 8), { { char = char, x = 5, y = 4 } }, { unit("character_bandit", 5, 5) })
            local mage = c.units[1]
            mage.char.stats.mana.current = 0

            local blocked = Combat.itemBlockReason(mage, char.inventory[2])
            assert(blocked and blocked.kind == "cost", "an empty alchemist is refused normally")
        end,
    },
    {
        name = "the Resonance Prism sharpens adjacent magic, and only magic",
        fn = function()
            local char = Character.instantiate("character_mage")
            char.inventory = {}
            -- Cells 1 and 3 flank the prism in cell 2 (row-major 3x3; 1,2,3 is the top row).
            char.inventory[1] = Item.instantiate("ability_fire_bolt") -- magical
            char.inventory[2] = Item.instantiate("utility_resonance_prism")
            char.inventory[3] = Item.instantiate("weapon_iron_sword")        -- not magical

            local bolt, sword = char.inventory[1], char.inventory[3]
            local prism = char.inventory[2]
            assert(Combat.auraApplies(prism.aura, bolt), "the prism sharpens an adjacent spell")
            assert(not Combat.auraApplies(prism.aura, sword), "but not an adjacent blade")
        end,
    },
    {
        name = "Adrenal Surge pulls its bearer's next turn sooner when it is hit",
        fn = function()
            local char = armed("character_knight", { "utility_adrenal_surge" })
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]
            knight.initiative = 20

            Combat.dealFlatDamage(c, knight, 5, { "physical" }, "test")
            assert(knight.initiative == 20 - 3, "the blow pulls its turn closer, got " .. knight.initiative)

            -- Cooldown: it answers the first blow of an exchange, not the whole flurry.
            local after = knight.initiative
            Combat.dealFlatDamage(c, knight, 5, { "physical" }, "test")
            assert(knight.initiative == after, "a second blow in the same flurry does not surge again")
        end,
    },
}

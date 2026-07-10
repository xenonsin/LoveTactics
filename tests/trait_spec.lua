-- Tests for traits (models/trait.lua) and their four hooks into models/combat.lua: the opener that
-- fires once the field is built, the reaction that fires on damage survived, the reaction on a
-- finished cast, and the one on death.
--
-- The load-bearing guarantees, each of which a boss depends on:
--   * onDamaged fires AFTER mitigation (a hook sees what actually landed) and only on a SURVIVOR
--     (the blow that kills you grants no rage; a health-threshold phase never fires on a corpse),
--   * a hook that deals damage cannot retrigger itself into a stack overflow,
--   * the damage PREVIEW never advances a trait,
--   * an item in the 3x3 grid grants its traits to whoever carries it -- the general-relic loop.
--
-- Pure logic, headless. Fixture defs are registered on Trait.defs and removed afterwards, the way
-- trap_spec registers throwaway traps.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Trait = require("models.trait")
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

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

-- Run `fn` with fixture trait defs installed under `defs`, cleaning up either way.
local function withTraits(defs, fn)
    for id, def in pairs(defs) do Trait.defs[id] = def end
    local ok, err = pcall(fn)
    for id in pairs(defs) do Trait.defs[id] = nil end
    if not ok then error(err, 0) end
end

-- A character instance carrying `traits`, built off an existing blueprint so its stats are real.
local function charWithTraits(id, traits)
    local char = Character.instantiate(id)
    char.traits = traits
    return char
end

return {
    {
        name = "onCombatStart fires once the field is built, for every unit that carries a trait",
        fn = function()
            withTraits({
                test_opener = {
                    name = "Opener",
                    onCombatStart = function(ctx)
                        -- The field must be finished by now: every other unit is already placed.
                        ctx.trait.sawUnits = #ctx.combat.units
                        ctx.addBonus("damage", 5)
                    end,
                },
            }, function()
                local knight = charWithTraits("knight", { "test_opener" })
                local c = Combat.new(arena(6, 6),
                    { unit(knight, 1, 1) }, { unit("bandit", 4, 4) })

                local u = c.units[1]
                assert(#u.traits == 1, "the trait should be attached from the character blueprint")
                assert(u.traits[1].sawUnits == 2, "the opener must see both units on the field")
                assert(u.bonus.damage == 5, "the opener's bonus should be folded in")

                assert(#c.units[2].traits == 0, "a unit with no traits gets an empty list, not nil")
            end)
        end,
    },
    {
        name = "onDamaged reports the POST-mitigation amount, not the raw blow",
        fn = function()
            withTraits({
                test_watcher = {
                    name = "Watcher",
                    onDamaged = function(ctx) ctx.trait.lastAmount = ctx.amount end,
                },
            }, function()
                local knight = charWithTraits("knight", { "test_watcher" })
                local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit("bandit", 4, 4) })
                local u = c.units[1]

                local dealt = Combat.dealFlatDamage(c, u, 30, { "physical" }, "test")
                assert(dealt < 30, "the knight's defense should have absorbed some of it")
                assert(u.traits[1].lastAmount == dealt,
                    "the hook must see the damage that landed, not the damage that was swung")
            end)
        end,
    },
    {
        name = "onDamaged does not fire on the blow that kills: no rage from the killing hit",
        fn = function()
            withTraits({
                test_counter = {
                    name = "Counter",
                    onDamaged = function(ctx) ctx.trait.hits = (ctx.trait.hits or 0) + 1 end,
                },
            }, function()
                local knight = charWithTraits("knight", { "test_counter" })
                local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit("bandit", 4, 4) })
                local u = c.units[1]

                Combat.dealFlatDamage(c, u, 20, nil, "test")
                assert(u.traits[1].hits == 1, "a survived hit fires the hook")

                Combat.dealFlatDamage(c, u, 9999, nil, "test")
                assert(not u.alive, "the second blow should be lethal")
                assert(u.traits[1].hits == 1, "the lethal blow must NOT fire onDamaged")
            end)
        end,
    },
    {
        name = "a trait that wounds its own bearer terminates rather than recursing forever",
        fn = function()
            withTraits({
                test_selfharm = {
                    name = "Self Harm",
                    onDamaged = function(ctx)
                        ctx.trait.fired = (ctx.trait.fired or 0) + 1
                        ctx.damage(ctx.unit, 1) -- re-enters dealFlatDamage on this very unit
                    end,
                },
            }, function()
                local knight = charWithTraits("knight", { "test_selfharm" })
                local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit("bandit", 4, 4) })
                local u = c.units[1]
                local before = u.char.stats.health.current

                -- The outer blow lands, then the hook's 1 damage lands (floored to 1 by mitigation),
                -- and that inner hit must NOT dispatch onDamaged a second time.
                local dealt = Combat.dealFlatDamage(c, u, 40, nil, "test")

                assert(u.traits[1].fired == 1, "the hook must not retrigger itself")
                assert(u.char.stats.health.current == before - dealt - 1,
                    "the self-damage should land exactly once, on top of the blow that provoked it")
                assert(u.alive, "the knight survives its own scratch")
            end)
        end,
    },
    {
        name = "wrath_rising banks a damage bonus per hit survived, and shows it as a badge",
        fn = function()
            local ira = Character.instantiate("general_wrath")
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit(ira, 5, 5) })
            local boss = c.units[2]

            local baseDamage = boss.bonus.damage or 0
            local gain = Trait.defs.wrath_rising.magnitude

            for i = 1, 3 do
                Combat.dealFlatDamage(c, boss, 10, nil, "test")
                assert(boss.alive, "260 health should survive three light hits")
                assert(boss.bonus.damage == baseDamage + gain * i,
                    "each survived hit should add exactly one gain")
            end

            local badge = Status.get(boss, "wrath")
            assert(badge, "the wrath badge should be visible on the general")
            assert(badge.magnitude == gain * 3, "the badge should read the total banked")
            assert(not badge.def.statBonus,
                "the badge must grant nothing: the trait already added the damage")
        end,
    },
    {
        name = "an item in the 3x3 grid grants its traits -- take the relic, take the rule",
        fn = function()
            -- A knight with no rage of their own.
            local plain = Character.instantiate("knight")
            local c1 = Combat.new(arena(6, 6), { unit(plain, 1, 1) }, { unit("bandit", 4, 4) })
            assert(#c1.units[1].traits == 0, "a knight has no innate trait")

            -- The same knight, wearing what was taken off Ira's body.
            local armed = Character.instantiate("knight")
            Character.addItem(armed, Item.instantiate("mail_of_the_unappeased"))
            local c2 = Combat.new(arena(6, 6), { unit(armed, 1, 1) }, { unit("bandit", 4, 4) })
            local u = c2.units[1]

            assert(Trait.has(u, "wrath_rising"), "the mail should carry Wrath's rule to its wearer")
            assert(u.traits[1].item and u.traits[1].item.id == "mail_of_the_unappeased",
                "the trait should remember which item granted it")

            local base = u.bonus.damage or 0
            Combat.dealFlatDamage(c2, u, 12, nil, "test")
            assert(u.bonus.damage > base, "the wearer now grows on damage taken, exactly as she did")
        end,
    },
    {
        name = "the damage preview never advances a trait",
        fn = function()
            local ira = Character.instantiate("general_wrath")
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 5) }, { unit(ira, 4, 4) })
            local knight, boss = c.units[1], c.units[2]

            local before = boss.bonus.damage or 0
            local sword = knight.char.inventory[1]
            Combat.previewAbility(c, knight, sword, boss.x, boss.y)

            assert((boss.bonus.damage or 0) == before,
                "hovering a target must not feed its rage -- preview routes around dealFlatDamage")
            assert(not Status.get(boss, "wrath"), "and it must not paint a badge either")
        end,
    },
    {
        name = "onDeath fires while the dying unit's summons are still standing",
        fn = function()
            withTraits({
                test_lastwords = {
                    name = "Last Words",
                    onDeath = function(ctx)
                        ctx.trait.summonsAlive = 0
                        for _, u in ipairs(ctx.combat.units) do
                            if u.alive and u.summoner == ctx.unit then
                                ctx.trait.summonsAlive = ctx.trait.summonsAlive + 1
                            end
                        end
                    end,
                },
            }, function()
                local Summon = require("models.summon")
                local mage = charWithTraits("mage", { "test_lastwords" })
                local c = Combat.new(arena(8, 8), { unit(mage, 1, 1) }, { unit("bandit", 6, 6) })
                local u = c.units[1]

                Summon.spawn(c, u, "wolf_grunt", 2, 1)
                Combat.dealFlatDamage(c, u, 9999, nil, "test")

                assert(not u.alive, "the mage should be dead")
                assert(u.traits[1].summonsAlive == 1,
                    "onDeath must run before the summon-dismiss cascade unwinds the wolf")
            end)
        end,
    },
    {
        name = "the Hollow Crown wears a general as its health falls past a threshold",
        fn = function()
            local lord = Character.instantiate("demon_lord")
            local c = Combat.new(arena(10, 10), { unit("knight", 1, 1) }, { unit(lord, 5, 5) })
            local boss = c.units[2]

            assert(#c.units == 2, "no shades before the first threshold")

            -- 600 health; ~186 lands after its 14 defense, leaving it near 69%: one threshold crossed.
            Combat.dealFlatDamage(c, boss, 200, nil, "test")
            assert(boss.alive, "it should still be standing")
            assert(#c.units == 3, "crossing 75% should call up exactly one shade")

            local shade = c.units[3]
            assert(shade.summoner == boss, "the shade is sustained by the Crown")
            assert(shade.side == "enemy", "and fights on its side")

            -- One enormous blow can cross two thresholds at once, and owes a shade for each.
            Combat.dealFlatDamage(c, boss, 300, nil, "test")
            assert(boss.alive, "still alive at ~21%")
            assert(#c.units == 5, "a blow past both 50% and 25% should call up two more")

            -- Killing the Crown takes its borrowed shapes with it -- what keeps `assassinate` honest.
            Combat.dealFlatDamage(c, boss, 9999, nil, "test")
            assert(not boss.alive, "the Crown falls")
            assert(not shade.alive, "and the shades fall with the thing that was wearing them")
            assert(#c.units == 5, "the lethal blow summons nothing: onDamaged skips a corpse")
        end,
    },
}

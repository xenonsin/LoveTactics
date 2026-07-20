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

-- A character instance with an EMPTY grid, built off an existing blueprint so its stats are real.
-- Any item may carry traits to its holder, so an empty grid is the only honest "this unit's traits
-- are exactly what I gave it" baseline: a knight carries Oathward on its signature relic, and every
-- sword in the game now carries Parry (data/traits/parry.lua), so even a plain bandit is not
-- trait-free while it holds its iron sword. Item-delivered traits have their own case below.
local function plainChar(id)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

-- A trait-free character instance (see plainChar) carrying exactly `traits` from its blueprint.
local function charWithTraits(id, traits)
    local char = plainChar(id)
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
                local knight = charWithTraits("character_knight", { "test_opener" })
                local c = Combat.new(arena(6, 6),
                    { unit(knight, 1, 1) }, { unit(plainChar("character_bandit"), 4, 4) })

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
                local knight = charWithTraits("character_knight", { "test_watcher" })
                local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit("character_bandit", 4, 4) })
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
                local knight = charWithTraits("character_knight", { "test_counter" })
                local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit("character_bandit", 4, 4) })
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
                local knight = charWithTraits("character_knight", { "test_selfharm" })
                local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit("character_bandit", 4, 4) })
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
        name = "a counter's fx cues land a beat AFTER the blow that provoked them",
        fn = function()
            withTraits({
                test_riposter = {
                    name = "Riposter",
                    onDamaged = function(ctx) ctx.damage(ctx.attacker, 5) end,
                },
            }, function()
                local knight = charWithTraits("character_knight", { "test_riposter" })
                local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit("character_bandit", 2, 1) })
                local defender, attacker = c.units[1], c.units[2]

                Combat.dealFlatDamage(c, defender, 20, { "physical" }, nil, attacker)

                local events = Combat.drainFx(c)
                assert(events and #events == 2, "the blow and the counter should each raise a cue")
                assert(events[1].unit == defender and events[1].beat == 0,
                    "the blow itself is beat 0 -- the action the player took")
                assert(events[2].unit == attacker and events[2].beat == 1,
                    "the counter answers it, so its cue must be a beat later")
            end)
        end,
    },
    {
        name = "an ordinary action's cues all share beat 0: nothing is deferred without a reaction",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit(plainChar("character_knight"), 1, 1) },
                { unit(plainChar("character_bandit"), 2, 1) })
            Combat.dealFlatDamage(c, c.units[2], 5, { "physical" }, nil, c.units[1])

            local events = Combat.drainFx(c)
            assert(events and #events >= 1, "the hit should raise a cue")
            for _, e in ipairs(events) do
                assert(e.beat == 0, "an unanswered blow raises no later beat")
            end
        end,
    },
    {
        -- Her rule is the threshold of SENSATION, not a tally of blows: she was raised to feel
        -- nothing, and the only thing that reaches her is being close to gone (docs/story.md, "The
        -- Colosseum"). So the bonus is a function of missing health, and hitting her once for forty
        -- differs from hitting her forty times for one by exactly what it should.
        name = "wrath_rising scales with how close to death it is, and shows it as a badge",
        fn = function()
            local ira = Character.instantiate("character_general_wrath")
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, { unit(ira, 5, 5) })
            local boss = c.units[2]
            local peak = Trait.defs.trait_wrath_rising.magnitude -- worth this much at death's door
            local hp = boss.char.stats.health
            -- Her grid already grants damage of its own (the Unappeased Heart), so the rule's
            -- contribution is measured against that baseline rather than against zero.
            local rested = boss.bonus.damage or 0

            -- Halfway down: half the curve.
            hp.current = math.floor(hp.max / 2) + 1
            Combat.dealFlatDamage(c, boss, 1, nil, "test")
            assert(boss.alive, "she is nowhere near dead")
            local half = (boss.bonus.damage or 0) - rested
            assert(half >= math.floor(peak * 0.45) and half <= math.floor(peak * 0.55),
                "at about half health she should carry about half the curve, got " .. tostring(half))

            -- Nearly gone: nearly all of it, and strictly more than at half.
            hp.current = math.floor(hp.max * 0.1) + 1
            Combat.dealFlatDamage(c, boss, 1, nil, "test")
            assert((boss.bonus.damage or 0) - rested > half,
                "closer to death is strictly worse for whoever put her there")

            local badge = Status.get(boss, "status_wrath")
            assert(badge, "the wrath badge should be visible on the general")
            assert(badge.magnitude == (boss.bonus.damage or 0) - rested,
                "the badge should read what the rule has added, not her resting kit")
            assert(not badge.def.statBonus,
                "the badge must grant nothing: the trait already added the damage")
        end,
    },
    {
        -- Nothing she has ever felt has gone away. A rage a potion could soothe would be a mood
        -- rather than a self, so the bonus only ever climbs.
        name = "wrath_rising never cools: healing her does not take the rage back",
        fn = function()
            local ira = Character.instantiate("character_general_wrath")
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, { unit(ira, 5, 5) })
            local boss = c.units[2]
            local hp = boss.char.stats.health

            hp.current = math.floor(hp.max * 0.2)
            Combat.dealFlatDamage(c, boss, 1, nil, "test")
            local banked = boss.bonus.damage
            assert(banked and banked > 0, "nearly dead, she is carrying the curve")

            hp.current = hp.max -- mended, whatever the fiction of it
            Combat.dealFlatDamage(c, boss, 1, nil, "test")
            assert(boss.bonus.damage == banked, "the bonus must not fall back with her health")
        end,
    },
    {
        name = "an item in the 3x3 grid grants its traits -- take the relic, take the rule",
        fn = function()
            -- A bandit with no rage of their own, and an empty grid besides: a starter like the knight
            -- carries an innate trait on its relic, and a bandit's own iron sword now carries Parry,
            -- so the "no trait" baseline has to be a character holding nothing at all (plainChar).
            local plain = plainChar("character_bandit")
            local c1 = Combat.new(arena(6, 6), { unit(plain, 1, 1) }, { unit("character_wolf_grunt", 4, 4) })
            assert(#c1.units[1].traits == 0, "an empty-handed bandit has no innate trait")

            -- The same bandit, wearing what was taken off Ira's body -- and nothing else, so the mail's
            -- rule is unambiguously the first (and only) trait it carries.
            local armed = plainChar("character_bandit")
            Character.addItem(armed, Item.instantiate("armor_mail_of_the_unappeased"))
            local c2 = Combat.new(arena(6, 6), { unit(armed, 1, 1) }, { unit("character_bandit", 4, 4) })
            local u = c2.units[1]

            assert(Trait.has(u, "trait_wrath_rising"), "the mail should carry Wrath's rule to its wearer")
            assert(u.traits[1].item and u.traits[1].item.id == "armor_mail_of_the_unappeased",
                "the trait should remember which item granted it")

            -- Hit hard enough to actually be in danger: the rule answers how close to death the
            -- wearer is, so a scratch correctly buys nothing. That is the trap the relic is --
            -- it only pays out once you want what she wanted.
            local base = u.bonus.damage or 0
            local hp = u.char.stats.health
            hp.current = math.floor(hp.max * 0.25)
            Combat.dealFlatDamage(c2, u, 1, nil, "test")
            assert(u.bonus.damage and u.bonus.damage > base,
                "the wearer now sharpens as they bleed out, exactly as she did")
        end,
    },
    {
        name = "the damage preview never advances a trait",
        fn = function()
            local ira = Character.instantiate("character_general_wrath")
            local c = Combat.new(arena(8, 8), { unit("character_knight", 4, 5) }, { unit(ira, 4, 4) })
            local knight, boss = c.units[1], c.units[2]

            local before = boss.bonus.damage or 0
            local sword = knight.char.inventory[1]
            Combat.previewAbility(c, knight, sword, boss.x, boss.y)

            assert((boss.bonus.damage or 0) == before,
                "hovering a target must not feed its rage -- preview routes around dealFlatDamage")
            assert(not Status.get(boss, "status_wrath"), "and it must not paint a badge either")
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
                local mage = charWithTraits("character_mage", { "test_lastwords" })
                local c = Combat.new(arena(8, 8), { unit(mage, 1, 1) }, { unit("character_bandit", 6, 6) })
                local u = c.units[1]

                Summon.spawn(c, u, "character_wolf_grunt", 2, 1)
                Combat.dealFlatDamage(c, u, 9999, nil, "test")

                assert(not u.alive, "the mage should be dead")
                assert(u.traits[1].summonsAlive == 1,
                    "onDeath must run before the summon-dismiss cascade unwinds the wolf")
            end)
        end,
    },
    {
        name = "Keen Senses answers an attack BEFORE it lands, and pays stamina for the privilege",
        fn = function()
            local priest = charWithTraits("character_priest", { "trait_keen_senses" })
            Character.addItem(priest, Item.instantiate("weapon_parasitic_staff"))
            local c = Combat.new(arena(6, 6), { unit(priest, 1, 1) }, { unit("character_bandit", 2, 1) })
            local p, b = c.units[1], c.units[2]
            local stamina = Combat.resource(p.char, "stamina")
            local banditHP = b.char.stats.health.current
            local priestHP = p.char.stats.health.current

            local dealt = Combat.dealFlatDamage(c, p, 12, nil, nil, b)

            assert(b.char.stats.health.current < banditHP, "the counter should have struck the attacker")
            assert(Combat.resource(p.char, "stamina") == stamina - 6, "the counter costs 6 stamina")
            -- The attacker lived, so their blow still arrives -- this reflex reorders an exchange, it
            -- does not cancel one.
            assert(dealt > 0 and p.char.stats.health.current == priestHP - dealt,
                "a counter that only wounds must not stop the blow that provoked it")
            -- The bandit's iron sword carries Parry, which must read our counter as an ANSWER and let
            -- it through: the priest is hit exactly once, by the blow they preempted.
            assert(b.alive, "the bandit survives a single counter")
        end,
    },
    {
        name = "Keen Senses' counter kills the attacker, and the attack dies with them",
        fn = function()
            local priest = charWithTraits("character_priest", { "trait_keen_senses" })
            Character.addItem(priest, Item.instantiate("weapon_parasitic_staff"))
            local c = Combat.new(arena(6, 6), { unit(priest, 1, 1) }, { unit("character_bandit", 2, 1) })
            local p, b = c.units[1], c.units[2]
            b.char.stats.health.current = 1
            local priestHP = p.char.stats.health.current

            local dealt = Combat.dealFlatDamage(c, p, 12, nil, nil, b)

            assert(not b.alive, "the counter should fell a bandit at 1 HP")
            assert(dealt == 0 and p.char.stats.health.current == priestHP,
                "a swing from a corpse never arrives")
        end,
    },
    {
        -- No reflex recharges any more. What stops a priest answering a whole flurry is that each
        -- answer in a round costs double the last, so the pool prices them out -- and a priest's pool
        -- is wanted for casting besides.
        name = "Keen Senses answers again and again, at double the price each time, until it can't",
        fn = function()
            local priest = charWithTraits("character_priest", { "trait_keen_senses" })
            Character.addItem(priest, Item.instantiate("weapon_parasitic_staff"))
            local c = Combat.new(arena(6, 6), { unit(priest, 1, 1) }, { unit("character_bandit", 2, 1) })
            local p, b = c.units[1], c.units[2]
            local swing = Item.instantiate("weapon_parasitic_staff").activeAbility.cost.amount

            local before = Combat.resource(p.char, "stamina")
            Combat.dealFlatDamage(c, p, 6, nil, nil, b)
            assert(Combat.resource(p.char, "stamina") == before - swing, "the first answer costs one swing")

            -- A second attack in the same round is still answered -- the old contract refused it --
            -- but it costs twice as much.
            before = Combat.resource(p.char, "stamina")
            local banditHP = b.char.stats.health.current
            Combat.dealFlatDamage(c, p, 6, nil, nil, b)
            assert(b.char.stats.health.current < banditHP, "a second answer comes, unlike under a cooldown")
            assert(Combat.resource(p.char, "stamina") == before - swing * 2, "at double the price")

            -- The third is priced beyond what a priest has left, so the blow simply lands.
            before = Combat.resource(p.char, "stamina")
            banditHP = b.char.stats.health.current
            assert(before < swing * 4, "the fixture's pool must be short of a third answer")
            Combat.dealFlatDamage(c, p, 6, nil, nil, b)
            assert(b.char.stats.health.current == banditHP, "the third answer prices itself out")
            assert(Combat.resource(p.char, "stamina") == before, "and declining costs nothing")
        end,
    },
    {
        name = "Keen Senses goes quiet on an empty pool, and on a foe beyond reach",
        fn = function()
            local priest = charWithTraits("character_priest", { "trait_keen_senses" })
            Character.addItem(priest, Item.instantiate("weapon_parasitic_staff"))
            local c = Combat.new(arena(6, 6), { unit(priest, 1, 1) }, { unit("character_bandit", 2, 1) })
            local p, b = c.units[1], c.units[2]
            local banditHP = b.char.stats.health.current

            p.char.stats.stamina.current = 5 -- one short of the 6 a counter costs
            assert(Combat.dealFlatDamage(c, p, 12, nil, nil, b) > 0, "the blow lands unanswered")
            assert(b.char.stats.health.current == banditHP, "no stamina, no answer")
            assert(p.char.stats.stamina.current == 5, "and nothing is spent on the reflex that never fired")

            -- Sensing a blow is not reaching the one who threw it: a sword answers only its own range.
            p.char.stats.stamina.current = 40
            b.x = 5
            assert(Combat.dealFlatDamage(c, p, 12, nil, nil, b) > 0, "the distant blow lands")
            assert(b.char.stats.health.current == banditHP, "a sword cannot answer across the field")
            assert(p.char.stats.stamina.current == 40, "and the unfired reflex costs nothing")
        end,
    },
    {
        name = "the Hollow Crown wears a general as its health falls past a threshold",
        fn = function()
            local lord = Character.instantiate("character_demon_lord")
            local c = Combat.new(arena(10, 10), { unit("character_knight", 1, 1) }, { unit(lord, 5, 5) })
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

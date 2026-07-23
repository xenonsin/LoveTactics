-- Tests for the seven items and the three engine verbs added with them:
--
--   * the Intercessor's Staff  -- a weapon whose damage heals a NAMED THIRD PARTY (weapon + trait)
--   * the Hunting Horn         -- Combat.perform, the fourth wait swap and the only CYCLING one
--   * Emplace Sentry           -- a summon with movement 0
--   * Break Off                -- fx.retreat on an ability, and the fx-table parity it needs
--   * Graven Circle            -- a friendly zone that pays its OWNER and nobody else
--   * Second Utterance         -- a banked charge that strips a channel's wind-up
--   * Knell                    -- a countdown that kills, and must NOT kill when cleansed
--
-- Pure logic, headless. Fixture style mirrors tests/weapon_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")
local Hazard = require("models.hazard")

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

-- An EMPTY grid, so a case controls exactly what its units carry (every item can carry traits).
local function plainChar(id)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function give(char, id, slot)
    local item = Item.instantiate(id)
    char.inventory[slot or 1] = item
    return item
end

local function hp(u) return u.char.stats.health.current end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

return {
    -- ---------------------------------------------------------------- Intercessor's Staff
    {
        name = "the Intercessor's Staff mends the ally it named, not the priest swinging it",
        fn = function()
            local priest = plainChar("character_priest")
            local staff = give(priest, "weapon_intercessors_staff")
            local ward = plainChar("character_knight")
            local c = Combat.new(arena(8, 4),
                { unit(priest, 1, 1), unit(ward, 2, 1) },
                { unit(plainChar("character_bandit"), 1, 2) })
            local p, w, foe = c.units[1], c.units[2], c.units[3]

            -- The trait names the ally with the least health, so wound the ward first (and the priest
            -- harder, to prove the healing does not simply go to whoever is worst off at swing time).
            w.char.stats.health.current = w.char.stats.health.max - 20
            Trait.setup(c)
            assert(p.intercession == w, "the staff's bearer names an ally at combat start")
            assert(Status.has(w, "status_intercession"), "the named ally wears the badge")

            p.char.stats.health.current = p.char.stats.health.max - 30
            local priestBefore, wardBefore = hp(p), hp(w)
            openTurn(c, p)
            assert(Combat.useItem(c, p, staff, foe.x, foe.y), "the staff swings")

            assert(hp(w) > wardBefore, "the blow mends the NAMED ally")
            assert(hp(p) == priestBefore, "and gives the priest nothing -- this is not lifesteal")
        end,
    },
    {
        -- The oath was to a person, not to a slot: a fallen ward is not silently re-picked, and the
        -- staff must not error when it swings with a dead name on it.
        name = "an intercessor whose ward has fallen swings on as an ordinary staff",
        fn = function()
            local priest = plainChar("character_priest")
            local staff = give(priest, "weapon_intercessors_staff")
            local c = Combat.new(arena(8, 4),
                { unit(priest, 1, 1), unit(plainChar("character_knight"), 2, 1) },
                { unit(plainChar("character_bandit"), 1, 2) })
            local p, w, foe = c.units[1], c.units[2], c.units[3]
            Trait.setup(c)
            assert(p.intercession == w, "named the only ally there was")

            w.alive = false
            local before = hp(p)
            openTurn(c, p)
            assert(Combat.useItem(c, p, staff, foe.x, foe.y), "the staff still swings")
            assert(hp(p) == before, "and still heals nobody, least of all the priest")
        end,
    },

    -- ---------------------------------------------------------------- the Hunting Horn / Perform
    {
        name = "a horn swaps Wait into Perform, and each Perform sounds the NEXT air in order",
        fn = function()
            local hunter = plainChar("character_archer")
            give(hunter, "utility_hunting_horn")
            local c = Combat.new(arena(8, 4), { unit(hunter, 2, 2) }, { unit(plainChar("character_bandit"), 6, 2) })
            local h = c.units[1]

            local behavior = Combat.waitBehavior(h)
            assert(behavior.kind == "perform", "the horn's holder Performs instead of waiting")
            assert(#behavior.songs == 3, "three airs")

            -- The cycle is fixed and it starts at the first air.
            local song = Combat.nextSong(h, behavior)
            assert(song.name == "The Chase", "the first press sounds The Chase")

            openTurn(c, h)
            assert(Combat.perform(c, h), "the first air plays")
            assert(Status.has(h, "status_hasted"), "The Chase hastens the bearer")
            assert(Combat.nextSong(h, behavior).name == "The Scent", "and the cursor advances")

            openTurn(c, h)
            assert(Combat.perform(c, h), "the second air plays")
            assert(Status.has(h, "status_inspiration"), "The Scent inspires")

            openTurn(c, h)
            assert(Combat.perform(c, h), "the third air plays")
            assert(Status.has(h, "status_regen"), "The Feast mends")

            -- ...and it wraps, rather than running out. The order is the cost: reaching an air again
            -- means walking the whole cycle again.
            assert(Combat.nextSong(h, behavior).name == "The Chase", "the cycle wraps to the start")
        end,
    },
    {
        name = "an air reaches every ally in earshot, and no enemy at any distance",
        fn = function()
            local hunter = plainChar("character_archer")
            give(hunter, "utility_hunting_horn")
            local c = Combat.new(arena(10, 4),
                { unit(hunter, 2, 2), unit(plainChar("character_knight"), 3, 2), unit(plainChar("character_mage"), 9, 2) },
                { unit(plainChar("character_bandit"), 2, 3) })
            local h, near, far, foe = c.units[1], c.units[2], c.units[3], c.units[4]

            openTurn(c, h)
            assert(Combat.perform(c, h), "the horn sounds")
            assert(Status.has(h, "status_hasted"), "the bearer hears its own horn")
            assert(Status.has(near, "status_hasted"), "an ally inside earshot hears it")
            assert(not Status.has(far, "status_hasted"), "an ally seven tiles off does not")
            -- The foe is ADJACENT and still gets nothing: earshot is a range, side is a gate.
            assert(not Status.has(foe, "status_hasted"), "and an enemy standing beside it gets nothing")
        end,
    },
    {
        -- Both payoffs ride the forge; `earshot` and `speed` deliberately do not (models/item.lua).
        name = "forging a horn buys a longer, stronger air -- never a wider one, and never cheaper tempo",
        fn = function()
            local base = Item.instantiate("utility_hunting_horn")
            local honed = Item.instantiate("utility_hunting_horn", nil, 10)
            assert(honed.waitBehavior.duration > base.waitBehavior.duration, "a forged air holds longer")
            assert(honed.waitBehavior.amount > base.waitBehavior.amount, "and pours more into the air that scales")
            assert(honed.waitBehavior.earshot == base.waitBehavior.earshot, "but never carries further")
            assert(honed.waitBehavior.speed == base.waitBehavior.speed, "and never buys back tempo")
        end,
    },

    -- ---------------------------------------------------------------- Emplace Sentry
    {
        name = "an emplaced sentry cannot move at all, and shoots four tiles",
        fn = function()
            -- Any body may carry any item (`class` never gates equipment, docs/classes.md), so the
            -- caster here is simply whoever has the mana to bind it.
            local alch = plainChar("character_mage")
            local ability = give(alch, "ability_emplace_sentry")
            local c = Combat.new(arena(10, 4), { unit(alch, 2, 2) }, { unit(plainChar("character_bandit"), 8, 2) })
            local a = c.units[1]

            openTurn(c, a)
            assert(Combat.useItem(c, a, ability, 3, 2), "the sentry is emplaced")
            local sentry
            for _, u in ipairs(c.units) do
                if u.char.name == "Ordnance Sentry" then sentry = u end
            end
            assert(sentry, "a sentry stands where it was set down")
            assert(sentry.x == 3 and sentry.y == 2, "on the aimed tile")

            -- Bolted down: its movement budget is zero, so `reachable` offers it nothing but its own tile.
            assert(Combat.moveBudget(sentry) == 0, "a sentry has no movement budget")

            -- The arm reaches four and never one -- the dead zone is the counterplay.
            local bolt = sentry.char.inventory[1]
            assert(bolt and bolt.id == "weapon_sentry_bolt", "it carries its crossbow arm")
            assert(bolt.activeAbility.range == 4, "which reaches four tiles")
            assert(bolt.activeAbility.minRange == 2, "and has no shot at point-blank")
        end,
    },

    -- ---------------------------------------------------------------- Break Off / fx.retreat
    {
        name = "Break Off lands the shot, then steps the hunter one tile back from the target",
        fn = function()
            local hunter = plainChar("character_archer")
            give(hunter, "weapon_iron_bow", 1)          -- the adjacency gate: a bow beside it in the grid
            local ability = give(hunter, "ability_break_off", 2)
            local c = Combat.new(arena(10, 3), { unit(hunter, 5, 2) }, { unit(plainChar("character_bandit"), 6, 2) })
            local h, foe = c.units[1], c.units[2]
            local before = hp(foe)

            openTurn(c, h)
            assert(Combat.useItem(c, h, ability, foe.x, foe.y), "the shot is loosed from inside the dead zone")
            assert(hp(foe) < before, "and it hurt")
            assert(h.x == 4 and h.y == 2, "the hunter gave one tile of ground, straight away from the target")
        end,
    },
    {
        -- fx.retreat existed on resolveCast's fx table alone; the weapon-strike table (which a
        -- hit-and-run WEAPON's effect actually runs through, un-pcalled) and both inert preview tables
        -- lacked it. Any weapon calling it would have crashed the swing.
        name = "fx.retreat is present on every fx table, so a hit-and-run weapon cannot crash its own swing",
        fn = function()
            -- NOT plainChar: a wolf's fangs are its body, and emptying the grid would disarm it.
            local c = Combat.new(arena(8, 3), { unit(plainChar("character_knight"), 4, 2) },
                { unit("character_wolf_grunt", 5, 2) })
            local w, prey = c.units[2], c.units[1]
            local fangs
            for _, it in ipairs(w.char.inventory) do
                if it.id == "weapon_wolf_fangs" then fangs = it end
            end
            assert(fangs, "the wolf bites with its fangs")

            -- The live swing: this is the path that had no `retreat` at all.
            openTurn(c, w)
            local result = Combat.strikeWith(c, w, fangs, prey.x, prey.y)
            assert(result.damageDealt > 0, "the wolf bites")
            assert(w.x == 6 and w.y == 2, "and springs back out of reach")

            -- The preview path must survive the same effect without erroring, or hovering a wolf's
            -- attack would take the panel down.
            local out = Combat.abilityOutput(nil, fangs)
            assert(out and out.damage > 0, "and the damage preview still quotes the bite")
        end,
    },

    -- ---------------------------------------------------------------- Graven Circle
    {
        name = "a graven circle cheapens the caster's own casts, and only while it stands in them",
        fn = function()
            local mage = plainChar("character_mage")
            local ability = give(mage, "ability_graven_circle")
            local c = Combat.new(arena(10, 6), { unit(mage, 5, 3) }, { unit(plainChar("character_bandit"), 9, 3) })
            local m = c.units[1]

            local spell = { cost = { stat = "mana", amount = 20 } }
            local full = Combat.abilityCosts(m, spell)[1].amount

            openTurn(c, m)
            assert(Combat.useItem(c, m, ability, m.x, m.y), "the circle is cut")
            assert(Hazard.at(c, m.x, m.y, "hazard_graven_circle"), "the ground under the mage is graven")
            assert(Status.has(m, "status_graven"), "and the mage standing in it is Graven")
            assert(Combat.abilityCosts(m, spell)[1].amount < full, "so its casts cost less")

            -- Step off, and the zone-bound status lifts: the discount is nailed to the tiles.
            Combat.teleportUnit(c, m, 9, 6)
            Hazard.reap(c, m)
            assert(not Status.has(m, "status_graven"), "leaving the circle ends it")
            assert(Combat.abilityCosts(m, spell)[1].amount == full, "and the casts cost full again")
        end,
    },
    {
        -- The line that makes it pride: every OTHER friendly zone pays allies and skips its owner. This
        -- one pays the owner and skips everyone, which is the whole reason it is on the Arcanum's shelf.
        name = "a graven circle pays its owner and nobody else -- an ally standing in it gains nothing",
        fn = function()
            local mage = plainChar("character_mage")
            local ability = give(mage, "ability_graven_circle")
            local c = Combat.new(arena(10, 6),
                { unit(mage, 5, 3), unit(plainChar("character_knight"), 5, 4) },
                { unit(plainChar("character_bandit"), 9, 3) })
            local m, ally = c.units[1], c.units[2]

            openTurn(c, m)
            assert(Combat.useItem(c, m, ability, m.x, m.y), "the circle is cut")
            assert(Hazard.at(c, ally.x, ally.y, "hazard_graven_circle"), "the ally is inside the 3x3")
            assert(Status.has(m, "status_graven"), "the mage is Graven")
            assert(not Status.has(ally, "status_graven"), "and the ally standing in it is not")
        end,
    },

    -- ---------------------------------------------------------------- Second Utterance
    {
        name = "Second Utterance strips the wind-up from the NEXT channel, then is spent",
        fn = function()
            local mage = plainChar("character_mage")
            give(mage, "utility_second_utterance", 1)
            local spell = give(mage, "ability_meteor_storm", 2)
            -- Within Meteor Storm's range 4, so the cast is legal and only the wind-up is under test.
            local c = Combat.new(arena(12, 8), { unit(mage, 2, 4) }, { unit(plainChar("character_bandit"), 6, 4) })
            local m = c.units[1]
            m.char.stats.mana.current = m.char.stats.mana.max
            Trait.attach(m)
            assert(Trait.has(m, "trait_second_utterance"), "the charm carries its trait")
            assert(spell.activeAbility.channel and spell.activeAbility.channel > 0, "the spell really does channel")

            -- With no charge banked, the cast winds up as normal.
            openTurn(c, m)
            local ok, info = Combat.useItem(c, m, spell, 6, 4)
            assert(ok and info and info.channeling, "the first cast telegraphs")
            assert(m.channel, "and a channel is pending")

            -- Landing it banks the charge.
            assert(Combat.resolveChannel(c, m), "the channel resolves")
            assert(Status.has(m, "status_second_utterance"), "which banks a free wind-up")

            -- The next channel skips the telegraph entirely and lands on the spot.
            m.char.stats.mana.current = m.char.stats.mana.max
            openTurn(c, m)
            local ok2, info2 = Combat.useItem(c, m, spell, 6, 4)
            assert(ok2, "the second cast goes off")
            assert(not (info2 and info2.channeling), "with no wind-up at all")
            assert(not m.channel, "and nothing left pending")
            assert(not Status.has(m, "status_second_utterance"), "the charge is spent")
        end,
    },
    {
        -- The charge is worth one BIG spell, so the model must not let a small one eat it.
        name = "an unchanneled spell walks past a banked Second Utterance without spending it",
        fn = function()
            local mage = plainChar("character_mage")
            local bolt = give(mage, "ability_fire_bolt", 1)
            local c = Combat.new(arena(10, 4), { unit(mage, 2, 2) }, { unit(plainChar("character_bandit"), 5, 2) })
            local m = c.units[1]
            m.char.stats.mana.current = m.char.stats.mana.max
            Status.apply(c, m, "status_second_utterance")
            assert(not bolt.activeAbility.channel, "a fire bolt does not channel")

            openTurn(c, m)
            assert(Combat.useItem(c, m, bolt, 5, 2), "the bolt is cast")
            assert(Status.has(m, "status_second_utterance"), "and the charge is still in hand")
        end,
    },
    {
        name = "an INTERRUPTED channel banks nothing -- the charge is paid for by a spell that landed",
        fn = function()
            local mage = plainChar("character_mage")
            give(mage, "utility_second_utterance", 1)
            local spell = give(mage, "ability_meteor_storm", 2)
            -- Within Meteor Storm's range 4, so the cast is legal and only the wind-up is under test.
            local c = Combat.new(arena(12, 8), { unit(mage, 2, 4) }, { unit(plainChar("character_bandit"), 6, 4) })
            local m = c.units[1]
            m.char.stats.mana.current = m.char.stats.mana.max
            Trait.attach(m)

            openTurn(c, m)
            assert(Combat.useItem(c, m, spell, 6, 4), "the cast begins")
            assert(Combat.interruptChannel(c, m, "stunned"), "and is shattered before it lands")
            assert(not Status.has(m, "status_second_utterance"), "so no charge is banked")
        end,
    },

    -- ---------------------------------------------------------------- Knell
    {
        name = "Knell kills when its count runs out, whatever health is left",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit(plainChar("character_knight"), 1, 1) },
                { unit(plainChar("character_bandit"), 3, 3) })
            local victim = c.units[2]
            victim.char.stats.health.current = victim.char.stats.health.max
            Status.apply(c, victim, "status_knell", { duration = 10 })

            Status.tick(c, 6)
            assert(victim.alive, "the hour has not come yet")
            assert(hp(victim) == victim.char.stats.health.max, "and it does no damage on the way")

            Status.tick(c, 6) -- past the count
            assert(not victim.alive, "the hour comes, and full health does not save it")
        end,
    },
    {
        -- The bug this case exists for. Status.remove and Status.cleanse both fire a def's `onExpire`
        -- on EVERY removal path, so a Knell that killed from there would kill the moment it was Cured --
        -- turning the one counterplay into the trigger. The kill fires from onTick instead.
        name = "curing a Knell saves the unit rather than killing it -- the whole counterplay",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit(plainChar("character_knight"), 1, 1) },
                { unit(plainChar("character_bandit"), 3, 3) })
            local victim = c.units[2]
            Status.apply(c, victim, "status_knell", { duration = 10 })

            Status.tick(c, 6)
            assert(victim.alive and Status.has(victim, "status_knell"), "the count is running")
            Status.cleanse(c, victim)
            assert(not Status.has(victim, "status_knell"), "a cleanse lifts the sentence")

            Status.tick(c, 20) -- well past what the count would have been
            assert(victim.alive, "and the hour never comes")
        end,
    },
    {
        name = "Toll the Knell telegraphs: it channels, and a shattered cast lays nothing",
        fn = function()
            local mage = plainChar("character_mage")
            local spell = give(mage, "ability_knell")
            local c = Combat.new(arena(12, 6), { unit(mage, 2, 3) }, { unit(plainChar("character_bandit"), 6, 3) })
            local m, foe = c.units[1], c.units[2]
            m.char.stats.mana.current = m.char.stats.mana.max
            assert(spell.activeAbility.channel > 0, "the sentence is announced before it is passed")

            openTurn(c, m)
            local ok, info = Combat.useItem(c, m, spell, foe.x, foe.y)
            assert(ok and info.channeling, "the cast winds up")
            assert(not Status.has(foe, "status_knell"), "and nothing has landed yet")

            Combat.interruptChannel(c, m, "stunned")
            assert(not Status.has(foe, "status_knell"), "a shattered cast names no hour")
        end,
    },
}

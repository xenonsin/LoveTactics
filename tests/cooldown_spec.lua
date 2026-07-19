-- Tests for the cooldown primitive (Combat.setCooldown/onCooldown/tickCooldowns) and for the rules
-- that REPLACED it on the counter traits: an answer is gated by reach and paid for in stamina, at an
-- escalating price, with no timer anywhere. Pure logic, headless.
--
-- The cooldown primitive itself is still load-bearing -- Dodge, Counter Magic, Cleansing Ward and the
-- Oathward redirect all hang their timers on it -- so it keeps its own case here. What went away is
-- the counter family's use of it.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
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

-- A unit whose character carries the given innate traits (attached by Combat.new / Trait.setup).
local function unitWithTraits(id, x, y, traits)
    local char = Character.instantiate(id)
    char.traits = traits
    return { char = char, x = x, y = y }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

local function stamina(u) return u.char.stats.stamina.current end

return {
    {
        name = "a cooldown counts down through rebase ticks and clears at 0",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_knight", 1, 1) }, {})
            local u = c.units[1]
            Combat.setCooldown(u, "test", 8)
            assert(Combat.onCooldown(u, "test"), "on cooldown after being set")

            Combat.tickCooldowns(c, 5)
            assert(Combat.onCooldown(u, "test"), "still recharging after 5 of 8 ticks")
            Combat.tickCooldowns(c, 3)
            assert(not Combat.onCooldown(u, "test"), "cleared once the ticks run out")
        end,
    },
    {
        -- The heart of the rework: nothing recharges, so a swordsman answers every blow they can
        -- reach for as long as the pool holds out -- and the pool is what runs down, in public.
        name = "melee_counter answers every adjacent blow it can pay for -- no timer gates it",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { unitWithTraits("character_knight", 1, 1, { "trait_melee_counter" }) },
                { unit("character_bandit", 1, 2) })
            local knight, bandit = c.units[1], c.units[2]
            local weapon = Combat.defaultWeapon(bandit.char)

            local hp0 = bandit.char.stats.health.current
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(bandit.char.stats.health.current < hp0, "the knight counters the adjacent striker")
            assert(not Combat.onCooldown(knight, "trait_melee_counter"),
                "and sets no cooldown doing it -- the timer is gone")

            -- Immediately again: the old contract refused this outright. Now it is allowed, and what
            -- it costs is what stops it running away.
            local hp1 = bandit.char.stats.health.current
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(bandit.char.stats.health.current < hp1,
                "a second blow in the same round is answered too")
        end,
    },
    {
        -- The replacement for the cooldown's "you cannot parry twice in one flurry" job.
        name = "each answer in a round costs double the last, and acting again clears the tally",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { unitWithTraits("character_knight", 1, 1, { "trait_melee_counter" }) },
                { unit("character_bandit", 1, 2) })
            local knight, bandit = c.units[1], c.units[2]
            local weapon = Combat.defaultWeapon(bandit.char)
            -- The knight answers with its iron sword, which costs 8 stamina to swing.
            local swing = Combat.defaultWeapon(knight.char).activeAbility.cost.amount

            local before = stamina(knight)
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(stamina(knight) == before - swing, "the first answer costs one swing")

            before = stamina(knight)
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(stamina(knight) == before - swing * 2, "the second costs double")

            before = stamina(knight)
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(stamina(knight) == before - swing * 4, "and the third quadruple")

            -- Coming back around to act is what resets the price (Combat.startTurn).
            knight.initiative = 0
            for _, u in ipairs(c.units) do if u ~= knight then u.initiative = 5 end end
            Combat.startTurn(c)
            assert(knight.answersThisRound == 0, "taking a turn clears the tally")

            knight.char.stats.stamina.current = knight.char.stats.stamina.max
            before = stamina(knight)
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(stamina(knight) == before - swing, "so the next answer is back to one swing")
        end,
    },
    {
        name = "an exhausted defender simply eats the blow -- and is never billed for declining",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { unitWithTraits("character_knight", 1, 1, { "trait_melee_counter" }) },
                { unit("character_bandit", 1, 2) })
            local knight, bandit = c.units[1], c.units[2]
            local weapon = Combat.defaultWeapon(bandit.char)

            knight.char.stats.stamina.current = 1 -- nowhere near a swing's price
            local hp0 = bandit.char.stats.health.current
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(bandit.char.stats.health.current == hp0, "no stamina, no answer")
            assert(stamina(knight) == 1, "and the refusal cost nothing")
        end,
    },
    {
        name = "melee_counter ignores a ranged hit (the attacker stood too far to answer in kind)",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { unitWithTraits("character_knight", 1, 1, { "trait_melee_counter" }) },
                { unit("character_archer", 1, 3) }) -- two tiles away: a ranged strike
            local knight, archer = c.units[1], c.units[2]
            local bow = Combat.defaultWeapon(archer.char)

            local hp0 = archer.char.stats.health.current
            local sp0 = stamina(knight)
            Combat.dealDamage(c, archer, knight, bow)
            assert(archer.char.stats.health.current == hp0, "a melee counter does not answer a ranged shot")
            assert(stamina(knight) == sp0, "and nothing was spent refusing")
        end,
    },
    {
        -- The rule the whole system is built to teach: reach is the gate, and a bow's dead zone is
        -- part of its reach. Close on an archer and you shut its counter off.
        name = "ranged_counter answers a shot from range, but never a foe in its face",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { unitWithTraits("character_archer", 1, 1, { "trait_ranged_counter" }) },
                { unit("character_bandit", 1, 3), unit("character_wolf_grunt", 1, 2) })
            local archer = c.units[1]
            local shooter, mauler = c.units[2], c.units[3]

            local hp0 = shooter.char.stats.health.current
            Combat.dealDamage(c, shooter, archer, Combat.defaultWeapon(shooter.char))
            assert(shooter.char.stats.health.current < hp0, "the archer returns fire on a distant attacker")

            -- Adjacent: inside the bow's minRange dead zone. The archer holds a bow and nothing else,
            -- and does not drop it to throw a punch.
            local hp1 = mauler.char.stats.health.current
            Combat.dealDamage(c, mauler, archer, Combat.defaultWeapon(mauler.char))
            assert(mauler.char.stats.health.current == hp1,
                "a bow cannot answer point-blank -- closing the distance is the counter to a counter")
        end,
    },
    {
        -- Which weapon answers is a question of reach, not of slot order: the old code took whichever
        -- weapon sorted first in the grid and so answered a bowshot with a sword.
        name = "a unit holding both a sword and a bow answers each blow with the weapon that reaches",
        fn = function()
            -- One reflex, and it declares no reach of its own: the sword's Parry, which under the
            -- reach rule answers anything a weapon in the grid can reach back at.
            local char = Character.instantiate("character_knight")
            char.inventory[1] = Item.instantiate("weapon_iron_sword") -- sorts first: range 1, grants Parry
            char.inventory[2] = Item.instantiate("weapon_iron_bow")   -- range 3, dead zone 2
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } },
                { unit("character_bandit", 1, 2), unit("character_bandit", 1, 4) })
            local hero, near, far = c.units[1], c.units[2], c.units[3]

            assert(Combat.answeringWeapon(c, hero, 1).id == "weapon_iron_sword",
                "an adjacent blow is answered with the blade")
            assert(Combat.answeringWeapon(c, hero, 3).id == "weapon_iron_bow",
                "and one from three tiles off with the bow, whatever order the grid holds them in")

            local nearHp = near.char.stats.health.current
            Combat.dealDamage(c, near, hero, Combat.defaultWeapon(near.char))
            assert(near.char.stats.health.current < nearHp, "the adjacent striker is cut back at")

            local farHp = far.char.stats.health.current
            Combat.dealDamage(c, far, hero, Combat.defaultWeapon(far.char))
            assert(far.char.stats.health.current < farHp, "and the distant one is shot back at")
        end,
    },
    {
        -- The read behind the item grid's recharge clock. It survives the rework, but only serves the
        -- reflexes that still HAVE a timer -- all of them passive utilities with no ability of their
        -- own, which is what keeps the clock off a slot the player could still act with.
        name = "itemCooldown traces a recharging reflex back to the grid slot that granted it",
        fn = function()
            local ward = Item.instantiate("utility_cleansing_ward")
            local char = Character.instantiate("character_knight")
            char.inventory[1] = ward
            local c = Combat.new(arena(6, 6), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 1, 2) })
            local knight = c.units[1]

            assert(Combat.itemCooldown(knight, ward) == nil, "a ward that has not fired is ready")

            Combat.setCooldown(knight, "trait_cleansing_ward", 20)
            local cd = Combat.itemCooldown(knight, ward)
            assert(cd and cd.remaining == 20, "the fresh cooldown reports its full length")
            assert(cd.total == 20, "priced against the trait's own magnitude")
            assert(cd.trait.id == "trait_cleansing_ward", "and names the reflex that is recharging")

            Combat.tickCooldowns(c, 14)
            local left = Combat.itemCooldown(knight, ward)
            assert(left and left.remaining == 6, "it counts down with every other duration")
            assert(left.total == 20, "while the total it is measured against holds")

            -- A slot that granted no trait never reads as recharging, cooldowns on the bearer or not.
            local plain = Item.instantiate("weapon_iron_sword")
            assert(Combat.itemCooldown(knight, plain) == nil, "an item with no reflex has no clock")

            Combat.tickCooldowns(c, 6)
            assert(Combat.itemCooldown(knight, ward) == nil, "and the clock clears once it recovers")
        end,
    },
    {
        -- A sword grants Parry, which no longer sets a cooldown -- so the slot the player attacks with
        -- can never wear a recovery clock. This is the confusion the rework was for.
        name = "a sword slot never reads as recharging, however hard its parry has been working",
        fn = function()
            local sword = Item.instantiate("weapon_iron_sword")
            local char = Character.instantiate("character_knight")
            char.inventory[1] = sword
            local c = Combat.new(arena(6, 6), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 1, 2) })
            local knight, bandit = c.units[1], c.units[2]
            assert(Trait.has(knight, "trait_parry"), "the iron sword carries Parry")

            Combat.dealDamage(c, bandit, knight, Combat.defaultWeapon(bandit.char))
            assert(Combat.itemCooldown(knight, sword) == nil,
                "a sword that has just parried is still a sword you can swing")
        end,
    },
}

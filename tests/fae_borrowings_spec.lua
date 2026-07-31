-- Three borrowings from Fae Tactics, folded onto the existing systems (see the design in-session):
--   * a "weak point struck" CUE stamped on the damage fx when a blow lands on a vulnerability
--     (Feature 1 -- pure signal, the extra damage was already the vulnerability's own);
--   * GATHER, a wait-behavior that coils the next blow (Feature 3 -- Empowered, the offensive twin
--     of Defend), carried by the monk's Centering Charm;
--   * FOLLOW-UP, an ally-strike reflex (Feature 4 -- strike a foe an ally just hit beside you),
--     carried by the fighter's Pincer Banner and priced like a counter.
-- Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

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

-- A character with a chosen loadout dropped into its grid, so traits attach and weapons resolve.
local function charWith(id, items)
    local ch = Character.instantiate(id)
    for i, itemId in ipairs(items) do ch.inventory[i] = Item.instantiate(itemId) end
    return ch
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

local function findDamageFx(fx)
    for _, e in ipairs(fx or {}) do
        if e.type == "damage" then return e end
    end
end

return {
    -- ---------------------------------------------------------------- Feature 1
    {
        name = "a blow into a matching vulnerability is flagged on its damage cue; a plain one is not",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 1, 1) }, { unit("character_bandit", 2, 1) })
            local atk, tgt = c.units[1], c.units[2]
            tgt.char.stats.health.current, tgt.char.stats.health.max = 200, 200
            Combat.drainFx(c) -- clear the setup cues

            -- No weakness: a slash leaves vulnerable = false on the cue.
            Combat.dealFlatDamage(c, tgt, 10, { "slash" }, nil, atk)
            local e1 = findDamageFx(Combat.drainFx(c))
            assert(e1, "a damage cue was pushed")
            assert(e1.vulnerable == false, "a plain hit is not flagged vulnerable")

            -- Vulnerable: Slash up, and the same slash flags the cue.
            Status.apply(c, tgt, "status_vulnerable_slash")
            Combat.dealFlatDamage(c, tgt, 10, { "slash" }, nil, atk)
            local e2 = findDamageFx(Combat.drainFx(c))
            assert(e2 and e2.vulnerable == true, "a slash into Vulnerable: Slash is flagged vulnerable")

            -- A NON-matching tag ignores the slash weakness, even with it standing.
            Combat.dealFlatDamage(c, tgt, 10, { "impact" }, nil, atk)
            local e3 = findDamageFx(Combat.drainFx(c))
            assert(e3 and e3.vulnerable == false, "an impact hit does not read the slash weakness")
        end,
    },

    -- ---------------------------------------------------------------- Feature 3
    {
        name = "the Centering Charm swaps Wait -> Gather and resolves its stored force to a number",
        fn = function()
            local uChar = charWith("character_rowan", { "weapon_iron_sword", "utility_centering_charm" })
            local c = Combat.new(arena(8, 8), { { char = uChar, x = 1, y = 1 } }, { unit("character_bandit", 2, 1) })
            local u = c.units[1]
            local wb = Combat.waitBehavior(u)
            assert(wb.kind == "gather", "the charm swaps Wait -> Gather")
            assert(type(wb.power) == "number" and wb.power > 0, "the charm's power resolved to a number")
        end,
    },
    {
        name = "Gather Empowers the next blow by its stored force, and the blow spends it",
        fn = function()
            local uChar = charWith("character_rowan", { "weapon_iron_sword", "utility_centering_charm" })
            local c = Combat.new(arena(8, 8), { { char = uChar, x = 1, y = 1 } }, { unit("character_bandit", 2, 1) })
            local u, foe = c.units[1], c.units[2]
            foe.char.stats.health.current, foe.char.stats.health.max = 200, 200
            local weapon = Combat.defaultWeapon(u.char)
            local power = Combat.waitBehavior(u).power

            openTurn(c, u)
            assert(Combat.gather(c, u), "Gather resolves")
            assert(Status.has(u, "status_empowered"), "the gatherer is left Empowered")

            -- The empower adds exactly its magnitude to the outgoing blow (both figures subtract the
            -- same defense, so the DIFFERENCE is the stored force alone).
            local boosted = Combat.computeDamage(c, u, foe, weapon)
            Status.remove(c, u, "status_empowered")
            local plain = Combat.computeDamage(c, u, foe, weapon)
            assert(boosted - plain == power,
                string.format("Empowered adds its %d force (boosted %d, plain %d)", power, boosted, plain))

            -- A landed blow spends the stance; a coil re-applied is gone the instant it draws blood.
            Status.apply(c, u, "status_empowered", { magnitude = power })
            assert(Status.has(u, "status_empowered"), "the coil is re-applied")
            local dealt = Combat.dealDamage(c, u, foe, weapon)
            assert(dealt > 0, "the empowered blow landed")
            assert(not Status.has(u, "status_empowered"), "the empower is spent on the blow it powered")
        end,
    },

    -- ---------------------------------------------------------------- Feature 4
    {
        name = "an ally striking an adjacent foe draws a Follow-Up, priced as an escalating answer",
        fn = function()
            -- A(2,1) and B(4,1) flank F(3,1). Both wear the Pincer Banner; A opens on F.
            local aChar = charWith("character_rowan", { "weapon_iron_sword", "utility_pincer_banner" })
            local bChar = charWith("character_rowan", { "weapon_iron_sword", "utility_pincer_banner" })
            local c = Combat.new(arena(8, 3),
                { { char = aChar, x = 2, y = 1 }, { char = bChar, x = 4, y = 1 } },
                { unit("character_bandit", 3, 1) })
            local a, b, f = c.units[1], c.units[2], c.units[3]
            f.char.stats.health.current, f.char.stats.health.max = 200, 200
            Combat.restoreResource(b.char, "stamina", 100)
            local weaponA = Combat.defaultWeapon(a.char)

            local solo = Combat.computeDamage(c, a, f, weaponA)
            assert(solo > 0, "the opener draws blood")
            local before = f.char.stats.health.current
            Combat.dealDamage(c, a, f, weaponA)
            local lost = before - f.char.stats.health.current

            assert(lost > solo, "the foe took the opener AND the follow-up on top of it")
            assert((b.answersThisRound or 0) == 1, "B's follow-up was tallied as one escalating answer")
            -- The recursion guard: A opened (a real strike, not an answer), so A never follows up on
            -- B's follow-up -- exactly one pile-on, no volley.
            assert((a.answersThisRound or 0) == 0, "the opener is not itself an answer, so it never chains")
        end,
    },
    {
        name = "a foe an ally hits that is NOT beside the bearer draws no Follow-Up",
        fn = function()
            local aChar = charWith("character_rowan", { "weapon_iron_sword" })
            local bChar = charWith("character_rowan", { "weapon_iron_sword", "utility_pincer_banner" })
            local c = Combat.new(arena(10, 3),
                { { char = aChar, x = 2, y = 1 }, { char = bChar, x = 8, y = 1 } },
                { unit("character_bandit", 3, 1) })
            local a, b, f = c.units[1], c.units[2], c.units[3]
            f.char.stats.health.current, f.char.stats.health.max = 200, 200
            Combat.restoreResource(b.char, "stamina", 100)
            local weaponA = Combat.defaultWeapon(a.char)

            local solo = Combat.computeDamage(c, a, f, weaponA)
            local before = f.char.stats.health.current
            Combat.dealDamage(c, a, f, weaponA)
            assert(before - f.char.stats.health.current == solo,
                "a bearer six tiles away seizes no opening")
            assert((b.answersThisRound or 0) == 0, "and throws no answer")
        end,
    },
}

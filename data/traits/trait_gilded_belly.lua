-- GILDED BELLY: Avaritia lies on gold, and it sticks (reviewed 2026-09-25, "Avaritia, the Unspent"; round 2
-- approved BOTH readings of the note "AOE around her").
--
--   * +2 Defense and +2 Magic Defense for every coin heap within 2 tiles of her body, read live off the
--     board -- loot a heap near her, or let her own fire melt it, and the armour comes off that moment.
--   * THE SAME BONUS REACHES HER SIDE within 2 of her (a `presence` whose value is her own count), so a
--     kobold standing in her shadow is as hard to cut as she is.
--   * THE BARE SCALE: while she is winding anything up she rears, and the belly is off -- for her and for
--     everyone leaning on it -- and every pierce blow into her is a critical (`bareWhileChanneling`,
--     Combat.forcesCrit). Her biggest threat, the breath, is her biggest opening.
--
-- Every read is pure: it runs inside every stat read and every forecast.
local PER_HEAP = 2
local REACH = 2

local function belly(bearer, combat)
    if not (bearer and combat) or bearer.channel then return 0 end
    return PER_HEAP * require("models.hoard").heapsNear(combat, bearer, REACH)
end

local function lent(bearer, combat) return belly(bearer, combat) end

return {
    name = "Gilded Belly",
    description = "Increase defense and magic defense by 2 per coin heap within 2, shared within 2. Winding up, pierce always crits you.",
    bareWhileChanneling = true,
    live = function(ctx)
        local n = belly(ctx.unit, ctx.combat)
        if n <= 0 then return nil end
        return { defense = n, magicDefense = n }
    end,
    presence = { allies = true, radius = REACH, defense = lent, magicDefense = lent },
}

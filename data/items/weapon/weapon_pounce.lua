-- POUNCE: the Sabertooth's bite, and the whole of its threat. Out of hiding it reaches THREE tiles -- the
-- cat lands beside its mark and bites -- and the bite is a critical every time (Combat.forcesCrit reads
-- `critFromHiding`). Seen, it is a plain bite from beside you, and a below-average one. Rengar's passive
-- (Unseen Predator), taken on review in round two of "The Sabertooth": the round-one pounce that only
-- pinned was denied for doing no damage.
--
-- "OUT OF HIDING" IS Combat.unseenFor: the turn was opened Invisible -- the Tawny Hide's veil after a
-- turn that drew no blood, or a veil the Longfang kept. `hiddenRange` is read by Combat.abilityRange, so
-- the threat overlay, the planner and the swing agree about the reach.
--
-- THE POUNCE BREAKS COVER, and that is the counterplay the review approved -- "hit it in the round after
-- it strikes". Striking does not end Invisible anywhere else in this engine (a ninja stays hidden through
-- the round after his blow), so the bite ends it here, once it has landed. The one exception is the
-- Longfang's kill (data/traits/trait_the_unbroken_stalk.lua): a pounce that DOWNS its mark under that rule
-- leaves her hidden.
--
-- A natural weapon: creature kit, no price, noSteal. No leap is sold to the company -- "too similar to
-- leap" on review; the Ambush Charm is its crit, the Stalker's Mantle its patience.
local Curve = require("models.curve")
local Stoop = require("models.stoop")

local function gap(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

return {
    name = "Pounce",
    description = "Bites an adjacent foe. On a turn opened Invisible, reaches three tiles, lands beside the target and is a critical.",
    flavor = "You do not hear it arrive. You hear the grass stop moving.",
    sprite = "assets/items/weapon_pounce.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee", "pierce" },
    noSteal = true, -- the teeth are the cat's
    activeAbility = {
        target = "enemy",
        range = 1,
        hiddenRange = 3,
        critFromHiding = true,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        -- Low for a bite on purpose: out of hiding every one of these lands x3 (Combat.CRIT_MULTIPLIER),
        -- and it is the only blow this body makes.
        damage = Curve.ramp(2, 12),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if gap(fx.user, t) > 1 then Stoop.landBeside(fx, t) end
            fx.damage(t)
            if not fx.user.alive then return end
            local kept = not t.alive and require("models.trait").flag(fx.user, "keepsVeilOnKill")
            if not kept and fx.hasStatus(fx.user, "status_invisible") then
                fx.clearStatus(fx.user, "status_invisible")
            end
        end,
    },
}

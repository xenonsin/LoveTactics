-- MAN-EATER: a foe that goes down beside a Manticore is eaten where it falls. Its revive window closes on
-- the spot -- the body is a cold corpse at once, as status_downed's own expiry would leave it -- and the
-- manticore's Tail Volley comes straight back off cooldown: a kill turns into another volley.
--
-- NOT PERMADEATH, and that is the line it was approved on (2026-09-23). A cold corpse is still carried
-- out after a won fight (Combat.reviveFallenParty takes `incapacitated OR corpse`), so what this costs is
-- the mid-fight revive and nothing past the battle. The injury a body carries home is the ordinary one.
--
-- A REACTION, NOT A TURN. The pitch had the manticore spend its bite on a body already down, but the
-- planner only ever aims at the living (Combat.abilityTargets), and teaching it a downed target is a new
-- kind of aim for one animal. So it eats in the moment the body drops, and only one within reach (1):
-- the counterplay is not going down next to it, which a company can see coming off the Quilled badges.
--
-- Only foes, only the manticore's own reach, and only a body that is still revivable when it falls -- a
-- demon is a corpse at once and there is no window to close.
return {
    name = "Man-eater",
    description = "A foe that falls beside it is eaten: it cannot be revived this battle, and Tail Volley is ready again.",
    reach = 1,
    onAnyDeath = function(ctx)
        local fallen, u = ctx.fallen, ctx.unit
        if not (fallen and u and u.alive) or fallen == u then return end
        if fallen.side == u.side or not fallen.incapacitated then return end
        if ctx.gap(fallen) > ctx.param("reach", 1) then return end
        fallen.incapacitated = false
        fallen.corpse = true
        fallen.noRevive = true
        ctx.clearStatus(fallen, "status_downed")
        -- The tail's cooldown is keyed on the item (Combat.castCooldownKey), so it is found by walking
        -- the grid for the volley rather than by naming a slot.
        local Combat = require("models.combat")
        for _, item in ipairs(u.char.inventory or {}) do
            if item and item.activeAbility and item.activeAbility.cooldown and u.cooldowns then
                u.cooldowns[Combat.castCooldownKey(item)] = nil
            end
        end
        ctx.log("death", string.format("%s eats %s where they fell.",
            (u.char and u.char.name) or "It", (fallen.char and fallen.char.name) or "the body"),
            { u, fallen })
    end,
}

-- THE OFFERING: the Godling's rite told from the dead side. Vesh takes a kobold skeleton standing beside
-- him -- it crumbles into him -- and his pool gains 30 mana: one Foreclosure, or most of a death refused.
-- His escort doubles as his battery, and the company reads it off his blue bar (approved 2026-09-25).
local OFFERED = "character_kobold_skeleton"
local GAIN = 30

local function offeringBeside(combat, unit)
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and u ~= unit and u.side == unit.side and u.char and u.char.id == OFFERED
            and math.abs(u.x - unit.x) + math.abs(u.y - unit.y) <= 1 then
            return u
        end
    end
    return nil
end

return {
    name = "The Offering",
    description = "Consumes an adjacent Kobold Skeleton on your side: restore 30 mana.",
    flavor = "They gave themselves to a god that ate them once already. It is easier the second time.",
    sprite = "assets/items/ability_the_offering.png",
    type = "ability",
    class = "creature",
    tags = { "dark" },
    noSteal = true,
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 3,
        support = true,
        ai = { priority = "urgent", act = "cast", label = "his pool is low, and a kobold kneels beside him",
               whenFn = function(ctx)
                   local mana = ctx.unit.char.stats.mana
                   if not (type(mana) == "table" and mana.current < 40) then return false end
                   return offeringBeside(ctx.combat, ctx.unit) ~= nil
               end },
        effect = function(fx)
            local t = fx.target
            if not (t and t.alive and t ~= fx.user and t.side == fx.user.side and t.char
                and t.char.id == OFFERED) then return end
            local gone
            if t.summoned then gone = fx.dismiss(t) else gone = fx.devour(t) end
            if gone then fx.restore(fx.user, "mana", GAIN) end
        end,
    },
}

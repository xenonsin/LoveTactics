local Curve = require("models.curve")

-- FORECLOSURE: Vesh's signature, and what he drops. A telegraphed turn's wind-up on one foe's tile, then
-- heavy dark damage there -- and a body it DOWNS gets back up as a skeleton of itself on the caster's side
-- (Summon.copyOf's bones: its own kit, Bare Bones, Grave-Cold). The skeleton stands on the body it was
-- made from, so the fallen cannot be revived until it is felled again; nothing is lost for good, since the
-- original lies in its ordinary revive window underneath. Step off the marked tile, or break the wind-up,
-- and it lands on nobody. One skeleton at a time: the copy holds the cast while it stands.
return {
    name = "Foreclosure",
    description = "After a turn's wind-up, deals heavy dark damage. A foe it fells rises as a skeleton on your side.",
    flavor = "Everything you own is his the moment you stop needing it. He is only collecting early.",
    sprite = "assets/items/ability_foreclosure.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "necromancer",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        windup = 5, -- a turn: the tell, and the counterplay
        speed = 6,
        cost = { stat = "mana", amount = 30 },
        damage = Curve.ramp(24, 40),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            if not t.alive and t.incapacitated then
                fx.copyOf(t, t.x, t.y, { bones = true, health = 1.0 })
            end
        end,
    },
}

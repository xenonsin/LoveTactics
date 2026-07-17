-- Thorns: the spiked mail bites back. When the bearer survives a MELEE physical blow -- one struck
-- from an adjacent tile -- the attacker takes a share of the damage it just dealt, straight back
-- (raw-ish flat reflection through ctx.damage). A ranged or magical hit provokes nothing: you can
-- only cut a hand that reached in. `magnitude` is the reflected percentage. Fires only on a survived
-- hit (Trait.onDamaged isn't called on the killing blow), so a lethal strike is never answered.
--
-- The reflection re-enters the damage core and so could trip the attacker's own reactions; the
-- dispatch guards in models/trait.lua (unit._reacting + MAX_DEPTH) keep that from looping.
--
-- What provokes it is declared in `counter` and checked by ctx.mayCounter (models/trait.lua), so the
-- hover preview can warn the player of the spikes through the same rules that bite. Spikes hold no
-- guard to be worn down: no cooldown, no cost, and they answer an answer as readily as an attack.
return {
    name = "Thorns",
    description = "Melee attackers take a share of the damage they deal back.",
    magnitude = 40, -- percent of the blow reflected
    counter = { reach = "melee", requiresTag = "physical", answersReactions = true, reflect = true },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        local reflected = math.floor((ctx.amount or 0) * ctx.def.magnitude / 100)
        if reflected < 1 then return end
        ctx.damage(ctx.attacker, reflected, { "physical" })
    end,
}

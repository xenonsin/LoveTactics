-- Warden's Parry: the Warden's Tongue's answer, and the `covers` idea (armor_oathkeeper_shield,
-- weapon_crozier) spoken through a reflex instead of a wait swap. The warden parries in the ordinary way
-- -- blow taken, blade answering -- and the same motion drops every ally standing beside them into a
-- brace (status_defending).
--
-- Which inverts what a sword is FOR. An ordinary parry is a private argument between the swordsman and
-- whoever swung; this one turns being attacked into the party's cue to close up. Standing at the front of
-- a line stops being the price of carrying a sword and becomes the reason to.
--
-- A note on what it is NOT, because the obvious version of this weapon does not work: it does not answer
-- a blow struck at an ally. Trait.onDamaged fires on the body that was hit and on no other, so a reflex
-- that reached across to a neighbour's exchange would need a hook that does not exist -- and would also
-- break the reach rule the whole counter system rests on (docs/weapons.md: "reach is the gate, and the
-- only one"), since the warden would be answering blows thrown at a tile they cannot touch. The brace is
-- the honest version of the same sentence: what the warden spends on their own answer, the line gets too.
return {
    name = "Warden's Parry",
    description = "When struck by a foe your blade can reach, spend a swing's stamina to cut back and brace every ally beside you.",
    counter = {},
    -- How deep the brace the answer hands out runs. Under a shield's own Defend on purpose: this is a
    -- side effect of a sword swinging, not a wall being planted.
    magnitude = 4,
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.log("action", string.format("%s parries, and the line closes up!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(ctx.attacker)
        local amount = (ctx.def and ctx.def.magnitude) or 4
        for _, u in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, 1)) do
            if u ~= ctx.unit and u.alive and u.side == ctx.unit.side then
                ctx.applyStatus(u, "status_defending", { magnitude = amount })
            end
        end
    end,
}

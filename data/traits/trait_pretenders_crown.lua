-- THE PRETENDER'S CROWN: kill a foe, wear its shape until you kill another (data/items/utility/
-- utility_pretenders_crown.lua). The shape is a copy of the body as it fell (Summon.copyChar: its kit and its
-- stats), worn through the transform, so the bearer's pools carry across and nothing about the kill heals them.
--
-- THE CROWN STAYS IN ITS CELL. A shape brings its own grid, and the crown has to be in the shape for the next kill
-- to be heard -- so it is put back into the cell it was worn in, over whatever the shape carried there.
return {
    name = "Pretender's Crown",
    description = "When you kill a foe, wear its shape until you kill another. Your health stays yours.",
    onAnyDeath = function(ctx)
        local me, fallen = ctx.unit, ctx.fallen
        if not (me and me.alive and fallen and fallen.char) then return end
        if fallen.side == me.side or fallen.lastAttacker ~= me then return end
        local Transform = require("models.transform")
        local Character = require("models.character")
        local crown, cell = ctx.item, nil
        local own = Transform.originalChar(me) or me.char
        for i = 1, Character.MAX_INVENTORY do
            if me.char.inventory[i] == crown or own.inventory[i] == crown then cell = i end
        end
        if Transform.isTransformed(me) then Transform.revert(ctx.combat, me) end
        local shape = Transform.apply(ctx.combat, me, nil, { char = require("models.summon").copyChar(fallen.char) })
        if not shape then return end
        if crown then
            shape.inventory[cell or Character.MAX_INVENTORY] = crown
            local Combat = require("models.combat")
            Combat.refreshPassives(me)
            require("models.trait").attach(me, ctx.combat)
        end
    end,
}

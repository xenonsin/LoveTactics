-- A Gagging Storm: a squall of static so loud that no incantation carries through it. Anything standing
-- in it is Silenced -- it may swing, it may walk, it may answer, it may not spend mana.
--
-- Silence rather than Denial, deliberately. Denial refuses the whole CRAFT (anything magical, however
-- it is paid for), which over a wide zone for several turns would simply delete the enemy caster from
-- the fight. Silence gags the INCANTATION -- what is paid for in mana -- so a mage caught in the storm
-- still swings its enchanted staff and still throws whatever its stamina buys. It is a tax on one
-- resource, in one place, which is a thing a player can play around and a thing an enemy AI can walk
-- out of. See the two flags' own comments in models/status.lua for the line this is drawn along.
--
-- And it INTERRUPTS: Silence carries `interruptsChannel = "mana"`, so a storm dropped onto a mage
-- winding up a long working shatters it and the mana is gone unrefunded. That is the play the spell is
-- really for, and it is why the storm is worth the turn even against a line that will just walk out.
return {
    name = "Gagging Storm",
    description = "Screaming static: nothing standing in it can spend mana on a working.",
    sprite = "assets/hazards/gagging_storm.png",
    tags = { "lightning", "conductable" }, -- it is a storm: a bolt cast into it carries, as it should
    duration = 12,            -- ~2.5 turns
    disposition = "hostile",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_silenced")
    end,
}

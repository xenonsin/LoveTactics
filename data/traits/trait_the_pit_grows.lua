-- The Pit Grows: where a body falls near the bearer, a mandrake comes up out of the floor it fell on.
--
-- THE LEGEND AGAIN, AND THE ALRAUNE LINE'S FICTION. Mandrake grows where the dead fall; this line grows
-- out of the Cathedral's unmarked pit, where the blooding's failures are dumped. The Anchoress carries it
-- (utility_the_anchorhold), and so does the trinket a company can carry out of her cell
-- (utility_the_pit_grows) -- the same rule twice, the numbers told apart by Trait.param.
--
-- A BROADCAST HOOK (onAnyDeath), so "whose death?" is asked here and nowhere else:
--   * within `radius` of the bearer, or it is somebody else's garden;
--   * `foesOnly` for the carried trinket, which grows on the company's kills and never on its dead --
--     the Anchoress's own bond grows on ANY death, hers included, because the pit is not particular;
--   * never on a mandrake. A shriek that sprouted a mandrake would sprout the next one when that one
--     died, and a fight that cannot run out of mandrakes cannot end;
--   * never on an object -- a felled hedge or a tree is not a body, and nothing is buried under it.
--
-- The sprout is a SUMMON of the bearer's (noClaim, so a second death sprouts a second one), which means
-- it goes when she does: cut the Anchoress and the garden she grew goes back into the floor, without a
-- scream -- a dismissal fires no death hook (Combat.dismiss).
return {
    name = "The Pit Grows",
    description = "When a body dies near the bearer, a Mandrake sprouts where it fell.",
    radius = 3,
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not (fallen and fallen.char) then return end
        if fallen.char.id == "character_mandrake" or fallen.char.race == "object" then return end
        if ctx.param("foesOnly", false) and fallen.side == ctx.unit.side then return end
        if ctx.gap(fallen) > ctx.param("radius", ctx.def.radius or 3) then return end
        local x, y = fallen.x, fallen.y
        if ctx.unitAt(x, y) then x, y = ctx.openTileNear(x, y) end
        if not x then return end
        local sprout = ctx.summon("character_mandrake", x, y, { noClaim = true })
        if sprout and sprout.alive then
            ctx.log("status", "A mandrake pushes up out of the floor where the body fell.")
        end
    end,
}

-- OPEN SPAN: the spire's signature ground (data/biomes/spire.lua). Up a tower there is nothing overhead and
-- nothing to put your back to, and a body standing out on the open landing is a body any archer can see whole.
--
-- VULNERABLE: PIERCE, zone-bound. The status declares no `lingers`, so Hazard's applyStatus stamps this zone's
-- id on it as `source`: it does not age, and it lifts the moment its bearer steps off the span
-- (Hazard.reap). Standing still out here is what costs; crossing costs a tile's worth of exposure and no more.
--
-- WHY A FILE OF ITS OWN. The spire used to name hazard_exposure, the Coveted Blood's cloud. That cloud is
-- SIDED to the alchemist who carries it (`if ctx.isAlly(ctx.unit) then return end`), and a patch the arena
-- lays has no owner, so Hazard.allied read every body as an ally and the ground opened nobody -- and it ran out
-- after the censer's twelve ticks besides. Terrain is unsided: the gilded rank is as open on the span as the
-- company is, which is what makes it a place both sides manoeuvre around rather than a trap one side laid.
--
-- It is the castle's Threshold told from the other side: a keep punishes the body holding a doorway, a tower
-- punishes the body that stopped moving in the open.
return {
    name = "Open Span",
    description = "Inflicts Vulnerable: Pierce on units standing on it.",
    tags = { "air" },
    duration = 9999, -- the ground does not expire
    disposition = "hostile",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_vulnerable_pierce")
    end,
}

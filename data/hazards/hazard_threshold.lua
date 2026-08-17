-- THRESHOLD: the castle's signature ground, and a doorway that remembers what it is for.
--
-- Pride's circle is built on adjacency -- both halves of the rank rule are measured live off who is
-- standing beside you (data/traits/trait_close_ranks.lua) -- and the `rooms` carve makes a doorway the
-- place a formation comes apart. This is that doorway, stated as ground.
--
-- DISARMED, which is the one status that fits. A threshold is where a house decides who may come in
-- armed, and a body standing in one cannot bring its weapon to bear. Mechanically it means the tile that
-- BREAKS a rank also punishes whoever holds it, so the obvious play against a Pride formation -- pull
-- them through the door one at a time -- costs something to execute rather than being free.
--
-- Unsided, like all terrain. The gilded rank is disarmed standing in its own doorway too, which is what
-- makes a threshold a place both sides manoeuvre around rather than a trap one side laid.
return {
    name = "Threshold",
    description = "Inflicts Disarmed on units standing on it.",
    tags = { "arcane" },
    duration = 20,
    disposition = "hostile",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_disarmed")
    end,
}

-- Lying Low: the Shoalkin's cover, and the reason the chaff of the Mere is worth a thought (2026-11-19,
-- the creature identity pass). The audit's finding was that a Shoalkin alone was "lowest_hp chaff": its
-- one trick, a knife that bites a soaked body harder, is invisible until somebody else has soaked you.
-- So the cover is the WATER, which is the one thing about this body a player can see before it acts.
--
-- A LIVE passive (Trait.liveBonus -> flatStat -> Combat.avoid), Tailwind's shape exactly: +`avoid` while
-- the bearer stands on a tile a swimmer belongs in (`cell.swim` -- the ford and the deep channel), and
-- nothing at all the moment it is on dry ground. The forecast's hit chance reads it, so the number on
-- the panel is the tell.
--
-- THE ANSWERS ARE THE FACTION'S OWN WEAKNESS, which is the point of choosing it over a hit-and-run. Pull
-- it onto the bank (any drag, a harpy's snatch, the Undertow Pike pointed back), or do not aim at all:
-- the ground it hides in conducts, a naga takes lightning -4, and a charge put through the water reaches
-- every body standing in it. The same channel that hides it is the one that kills it.
--
-- 25, Tailwind's number on the animal: one size of "hard to hit" across the bestiary.
return {
    name = "Lying Low",
    grade = 0.5, -- weighed beside the rule (Grade.traitValue reads it): Avoid on water tiles only
    description = "+25 Avoid while standing in water.",
    avoid = 25,
    live = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit and unit.x and unit.y) then return nil end
        local tiles = combat.arena and combat.arena.tiles
        local row = tiles and tiles[unit.y]
        local cell = row and row[unit.x]
        if not (cell and cell.swim) then return nil end
        local Trait = require("models.trait")
        return { avoid = Trait.param(ctx.trait, "avoid", 25) }
    end,
}

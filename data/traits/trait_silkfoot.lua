-- SILKFOOT: a spider's feet on its own web. A flag rather than a hook, read in two places:
-- data/hazards/hazard_web.lua (a strand does not catch this body; it gets status_on_the_web instead) and
-- that hazard's `welcomes`, which is how the AI knows to route ONTO the web rather than around it.
--
-- Granted by utility_silkfoot (the spider line's own kit) and by armor_gossamer_mantle, which is the
-- same feet rebuilt as something a person can wear.
return {
    name = "Silkfoot",
    description = "Walks web freely instead of being caught, and moves farther and acts quicker while standing on it.",
    walksSilk = true,
}

-- Hemophage: when a bleeding foe falls, its Bleed jumps to the nearest body of its own side, every stack
-- of it (Engine.onFell, models/engine.lua). A flag rather than a hook, because the fall is read where the
-- damage core still has the body's wounds on it -- by the time onAnyDeath fires they are gone.
--
-- The Poacher's: rogue Bloodletting carried into the hunter's Reaper. The Poacher already takes its turn
-- back for killing a Rooted foe; spreading the wound on the kill is what keeps the pack bleeding.
return {
    name = "Hemophage",
    description = "When a bleeding foe falls, its Bleed jumps to the nearest of its allies.",
    hemophage = true,
}

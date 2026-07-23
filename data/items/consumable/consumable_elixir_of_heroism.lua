-- Elixir of Heroism: the third and dearest of the elixirs. Raises both defenses -- and, alone on the
-- shelf, sells something that is not a number: while it lasts the drinker cannot be Halted
-- (data/status/status_heroism.lua).
--
-- That clause is what it is FOR. Stand Down (data/items/ability/ability_stand_down.lua) takes a turn
-- away without touching the body, and there is nothing in a stat line that answers it; a party walking
-- into the Bastion drinks this at the door. It is also the shelf saying the quiet part: envy does not
-- only covet strength, it covets standing -- and what the Crucible bottles here is the appearance of
-- a person who cannot be told what to do.
--
-- Priced above its two siblings, because a refusal is worth more than a bonus and both houses know it.
return {
    name = "Elixir of Heroism",
    description = "Raises an ally's defenses for most of the battle, and makes them proof against Halt.",
    flavor = "Courage, distilled. The Crucible is careful to sell only the distillate.",
    sprite = "assets/items/consumable_elixir_of_heroism.png",
    type = "consumable",
    tags = { "potion", "elixir", "restorative" },
    class = "alchemist",
    price = 220,
    repRank = 3,
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 3,
        consumesItem = true,
        ai = { priority = "low", act = "support", targetPref = "self" },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_heroism", { duration = 45 + 3 * fx.level })
        end,
    },
}

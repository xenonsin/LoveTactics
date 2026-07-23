-- Elixir of the Adept: the arcane half of the elixir shelf. A long window of raised Magic Damage
-- (data/status/status_arcane_cultivation.lua). See the Elixir of the Giant
-- (data/items/consumable/consumable_elixir_of_the_giant.lua) for what the shelf is arguing.
--
-- Deliberately a SEPARATE elixir rather than one bottle with a choice in it, so a caster can hold both
-- open at once and a battlemage can run the fight on nothing but purchased gifts. Two statuses in
-- flatStat's sum is how that falls out with nobody writing a rule for it.
--
-- The Arcanum has opinions about this bottle. Pride does not care to be told its talent is available
-- by the measure, and the Crucible sells it two streets away regardless.
return {
    name = "Elixir of the Adept",
    description = "Raises an ally's Magic Damage for most of the battle.",
    flavor = "The Arcanum has never once acknowledged that this works. It has never denied it either.",
    sprite = "assets/items/consumable_elixir_of_the_adept.png",
    type = "consumable",
    tags = { "potion", "elixir", "restorative" },
    class = "alchemist",
    price = 140,
    repRank = 2,
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 3,
        consumesItem = true,
        ai = { priority = "low", act = "support", targetPref = "self" },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_arcane_cultivation", { duration = 45 + 3 * fx.level })
        end,
    },
}

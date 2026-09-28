-- THE THOUSAND ARMS: Furor's organ. He opens with four arms (one more landing on every bare-handed blow), and
-- as his chi rises they GROW: a pair at 4 chi and another at 8 (`armsGrow`, read by Asura.grownHits), up to
-- eight arms and four landings. Nothing takes them away -- the author ruled out severing twice -- so what
-- keeps him small is keeping him cold.
--
-- It also carries his fire +5 (approved on review 2026-09-27/28): his own halo's heat. It rides the organ, the
-- way the oni's physical line rides the Horn, because the bestiary check puts a humanoid's per-type resist on
-- something it carries rather than on the blueprint.
return {
    name = "The Thousand Arms",
    description = "Bare-handed strikes land once more, and once more again at 4 and at 8 chi. Resists fire.",
    flavor = "The statues give him a thousand. The statues were carved by people who had only seen him angry.",
    sprite = "assets/items/utility_thousand_arms.png",
    type = "utility",
    tags = { "natural", "fist" },
    class = "creature",
    noSteal = true,
    bound = true,
    arms = 4,
    armsGrow = { 4, 8 },
    unarmedBonus = { hits = 1 },
    resist = { fire = 5 },
}

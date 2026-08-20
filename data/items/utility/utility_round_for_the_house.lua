-- Round for the House: the fighter half of the Warbrewer (fighter x alchemist). When you drink, the
-- people standing next to you get a share.
--
-- The author's note, built as a passive rather than as the splashing hammer it was drafted as -- which
-- makes it work on every draught you own instead of only the ones you hit somebody with. It attaches to
-- the consumable TYPE, so a Warbrewer who buys a new potion next week gets it poured out automatically
-- and this file never learns its name.
--
-- It is what turns the Crucible's shelf into a party buff without authoring a single new potion, and it
-- is the reason the Warbrewer is a support build wearing plate rather than a fighter with a satchel.
--
-- A FAITHFUL APPROXIMATION, and the header says so the way this codebase expects. The true version would
-- re-run the drink's own effect against each neighbour, which the engine has no shape for: an effect
-- closure is bound to one fx context and one caster, and re-entering it with a substituted user would
-- fire every self-targeted clause on the wrong body. What happens instead is that each neighbour is
-- handed a share of the two pools a draught actually moves -- health and stamina. That covers the
-- restoratives, which is most of the shelf, and under-delivers on the exotic ones.
return {
    name = "Round for the House",
    description = "When you drink anything, allies beside you are restored a share of it.",
    flavor = "It is not generosity. A brawl goes better when everyone in it is upright.",
    sprite = "assets/items/utility_round_for_the_house.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "warbrewer",
    price = 345,
    unlockQuests = 2,
    traits = { "trait_round_for_the_house" },
}

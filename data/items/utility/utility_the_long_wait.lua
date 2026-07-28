-- The Long Wait: the rogue half of the Poacher (rogue x hunter). Your blows against a Rooted or Marked
-- body cannot be answered at all.
--
-- The safety half of snare-execute. A Poacher's whole method is to walk up to something that cannot
-- leave and open its throat, and the obvious problem with that method is that the thing can still swing
-- back. This removes the swing -- every kind of it, since it gates in Trait.mayCounter, the one door
-- every parry, riposte, thorn and reflecting ward passes through.
--
-- Rooted OR Marked, so it collects off both halves of the shelf: Bolas roots, Quarry's Due marks
-- whatever the traps catch, and the hunter's own quarry-sign was already on the Lodge's shelf. A Poacher
-- who has done any of its setup is covered.
--
-- Note what it does not do: it does not stop the victim acting on its own turn. A rooted foe with a bow
-- will still shoot you next initiative. What you have bought is the freedom to swing without paying for
-- it, which is worth exactly as much as the number of swings you can fit before its turn comes round --
-- and that is the poacher's real skill, and the reason the discipline reads as patience.
return {
    name = "The Long Wait",
    description = "Attacks against a Rooted or Marked foe cannot be countered.",
    flavor = "It has been in the wire since dawn. He has been in the hedge rather longer.",
    sprite = "assets/items/utility_the_long_wait.png",
    type = "utility",
    tags = { "charm", "guile" },
    class = "rogue",
    discipline = "poacher",
    price = 420,
    repRank = 4,
    traits = { "trait_the_long_wait" },
}

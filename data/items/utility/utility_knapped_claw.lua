-- KNAPPED CLAW: her rule, rebuilt as a thing somebody can carry.
--
-- WHY IT IS NOT HER CLAWS. weapon_great_claws is `class = "creature"` with no axis at all, so the pool
-- cannot mint it and no counter can stock it -- that is the rule a boss's whole fight lives behind
-- (docs/bestiary.md, and the seventeen items that learned it the hard way). This is the legitimate
-- route, and the one the Unseeing's own list takes: a NEW item that carries the same rule, priced and
-- shelved and findable, standing beside the sealed original rather than being it.
--
-- WHY A UTILITY AND NOT A WEAPON. The object is a claw worked to an edge, which reads as a weapon and
-- would be the wrong build of one: trait_fury_swipes fires on the CAST, so hung on a weapon the rule
-- would only work while you were swinging that particular claw, and the whole point of taking it home is
-- that it teaches your own arm the habit. Carried, it works with the sword you already chose -- which is
-- also what makes the slash keying a real constraint rather than a formality. A party with no edge in it
-- gets nothing from this.
--
-- WHAT IT ACTUALLY HANDS OVER, stated plainly because it is a boss's signature: four stacks at two
-- apiece is +8 slash vulnerability on one body, which is exactly what status_vulnerable_slash grants for
-- a whole ability -- and it takes four consecutive LANDED blows on the same body to get there, decaying
-- the moment you break off or miss. The ceiling is the balance and it is the same ceiling she fights
-- under. See data/status/status_fury_swipes.lua.
--
-- AND THE WOUND IS THE PARTY'S. It sits on the body rather than between two units, so the bearer opens
-- somebody up and everybody with an edge spends it. That is the reason this is worth carrying into a
-- company rather than onto one fighter, and it is the same fact that makes her cub expensive to leave
-- standing (data/characters/character_sow.lua).
--
-- Dearer than the hide and under the pelt, which is the order the list is authored in: depth IS the
-- rarity here (Spoils.rankBand), so this is the piece you meet once and the pelt is the one you are
-- still after.
return {
    name = "Knapped Claw",
    description = "Each landed blow on the same body deepens Fury Swipes, up to 4.",
    flavor = "Struck down to an edge the way flint is. It had already been doing this for years.",
    sprite = "assets/items/utility_knapped_claw.png",
    type = "utility",
    tags = { "trophy", "beast" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS: the house that takes the animal apart and carries
    -- the useful bits away. `class` is the vendor shelf and never an equip gate -- anyone may carry it.
    class = "poacher",
    unlockLevel = 7,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    traits = { "trait_fury_swipes" },
}

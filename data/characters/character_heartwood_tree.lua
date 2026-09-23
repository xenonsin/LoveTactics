-- THE HEARTWOOD TREE: the Hamadryad's own yew, planted beside her at the bell by her Heartwood
-- (data/traits/trait_heartwood.lua). While it stands she cannot die -- every blow that would kill her
-- leaves her at 1 and sets her down beside it (data/status/status_heartbound.lua).
--
-- SO IT IS THE REAL TARGET OF THE CHURCHYARD YEW, and it is built to be one: a big bar for an object and
-- a heavy defense against magic, but no coat against an edge -- a yew is felled with an axe, not argued
-- with. It takes no turns and it is a PLANT (models/grove.lua), so the Nymphs step out beside it.
return {
    name = "Heartwood Tree",
    race = "object",
    tier = 0,
    plant = true,
    sprite = "assets/chars/heartwood_tree.png",
    stats = {
        health = 60, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 4, magicDefense = 12, -- warded against spells; open to a blade
        movement = 0,
        speed = 0,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 0, luck = 0,
    },
    startingItems = {},
}

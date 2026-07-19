-- Lifted off Acedia's body, and it kept her rule. `traits` on an item reach whoever carries it in
-- their 3x3 grid (models/trait.lua): the bearer's enemies are sworn into pairs nobody chose, and
-- bitten for ending a turn apart. You fought that mechanic; now you are it.
--
-- It is a trap dressed as a reward, exactly as it was when she carried it -- and its trap is the
-- opposite of the Mail of the Unappeased's. The mail only pays if you are being hit. This only pays
-- if you make the enemy CLUMP, and a clumped enemy is a wall, so the pike rewards you for producing
-- precisely the stuck, immobile board its owner spent thirty years arguing the world already was.
--
-- A spear, so it owes the spear contract (docs/weapons.md): the two-tile line is the family's
-- defining trait and this keeps it. It differs in TYPE from Wrath's armor on purpose -- the seven
-- relics are a set of unlike things, never a matched trophy rack (docs/story.md, "The seven keys").
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
--
-- The FLAVOR carries this general's fragment naming the Gate Below (docs/item-text.md: the line is
-- story, not a rule, and the tooltip prints it italic at the foot). The Gate is keyed off the QUEST
-- you finished, never off this item (see questGate in models/quest.lua) -- so stashing it, wearing
-- it, or losing it can never cost you the endgame.
return {
    name = "The Forsworn Pike",
    description = "Swears your enemies into pairs. Each one that ends its turn apart from its partner is bitten.",
    flavor = "She planted it in the gateway and walked out past it. Cut into the shaft: \"past the " ..
        "gate that was opened from within\".",
    sprite = "assets/items/forsworn_pike.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee", "relic" },
    hands = 2, -- a two-handed polearm, like every spear (Dual Wield pairs it only once forged to +5)
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_unrelieved" },
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the direction the thrust runs
        allowOccupied = true,  -- the first tile may hold a foe -- the thrust starts there and drives on
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 3,
        cost = { stat = "stamina", amount = 9 },
        damage = { 9, 10, 10, 11, 12, 12, 13, 14, 14, 15, 16 },
        aoe = { shape = "line", length = 2 }, -- the spear's two tiles: the family contract, kept
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}

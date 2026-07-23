-- A bow, so it owes the family's contract (docs/weapons.md): ranged physical, `requiresSight`, the dead
-- point-blank band, two hands. What it adds over data/items/weapon/weapon_iron_bow.lua is a WAIT SWAP:
-- its holder's Wait becomes Overwatch (Combat.waitBehavior / Combat.overwatch). Instead of delaying,
-- the archer settles in, and anything that walks into its band is shot on every step it spends there
-- until the stamina runs out.
--
-- Still-hunting is the practice the bow is named for: you do not go to the animal, you become part of
-- the place it is already walking through. So this is the bow that turns the whole of a turn into
-- ground the enemy cannot cross, and it is the only weapon that does -- the swap has lived on a
-- utility until now (data/items/utility/utility_overwatch_scope.lua), which meant paying a grid cell
-- for it. Here it is the weapon, which is the trade: an archer that wants to watch no longer has to
-- give up a slot to do it, and pays instead in the arrows it does not loose.
--
-- Because that is the real price, and the damage curve says it out loud: this bow is WORSE than iron
-- in the hand, flatly and at every level. A stillhunter that spends its turns shooting has bought a
-- penalty. The item is only worth carrying by someone willing to spend whole turns doing nothing
-- visible, which is the discipline it is named after.
--
-- Two things it deliberately does NOT do, both of them the staff/censer line drawn again
-- (docs/weapons.md): it lays no ground, and it grants no second swap. `waitBehavior` is first-in-grid
-- wins, so an Overwatch Scope beside it is redundant rather than additive -- carry one or the other.
return {
    name = "Stillhunter",
    description = "Replaces Wait with Overwatch: shoots anything that walks into range, for stamina.",
    flavor = "You do not go to the animal. You become part of the place it is already walking through.",
    sprite = "assets/items/stillhunter.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2, -- every bow is two-handed (docs/weapons.md)
    class = "hunter",
    price = 300,
    repRank = 3,
    -- The extra, whole. `speed` is the steep tempo the stance costs and deliberately does not scale
    -- with the forge (models/item.lua): an upgrade buys steadier shooting, never the turn back.
    waitBehavior = { kind = "overwatch", speed = 12, stamina = { 6, 6, 5, 5, 5, 4, 4, 4, 3, 3, 3 } },
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2,
        requiresSight = true,
        speed = 2,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- under an iron bow at every level: see above
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}

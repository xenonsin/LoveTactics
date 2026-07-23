-- A wand, so it owes the family's contract (docs/weapons.md): ranged magical, `requiresSight`, and no
-- point-blank dead zone. What it adds over data/items/weapon/weapon_wand.lua is that it never fires
-- the same bolt twice running. It alternates -- fire, frost, fire, frost -- and the wielder is immune
-- to both of the things it hands out.
--
-- The alternation is not decoration; it is a two-cast combo the weapon plays against ITSELF. The frost
-- bolt leaves the target Frozen (data/status/status_freeze.lua), and Frozen is BRITTLE: it takes extra
-- damage from fire. The very next thing this wand does is throw fire. So a mage who simply keeps
-- shooting is alternately setting up and cashing in, and the payoff arrives without a second item, a
-- second caster, or a plan -- which is exactly what a lone mage on the back line does not otherwise
-- have. Where the Emberwand (data/items/weapon/weapon_emberwand.lua) asks where the enemy is willing
-- to stand, this one asks nothing at all and simply pays for patience with the rhythm.
--
-- The freeze it lands is a SHORT one (2 ticks of delay against Ice Bolt's 5): this is a weapon, not a
-- data/items/ability/ability_ice_bolt.lua, and a basic attack that reliably shoves the turn order
-- around would be worth more than the spell it is imitating. What the wand sells is the brittleness,
-- not the delay.
--
-- The immunity is the Arcanum's own conceit, and the reason the item is priced where it is: the
-- bearer cannot Burn and cannot Freeze. Its own fire is harmless to it, and so is everyone else's --
-- an enemy Blizzard, a Fireball, a burning floor. That is a genuinely wide defensive perk for a
-- weapon, and it is deliberately not free: this bolt is the feeblest wand in the catalog per cast,
-- and it costs more mana than the plain one to throw.
--
-- The rhythm lives on the UNIT (`fx.user.turningYear`), never on the item. A field on the item would
-- persist in the inventory between battles and a fight could open on whichever half the last one
-- happened to end on; on the unit it is rebuilt with the battle, so every fight opens with fire. That
-- also means two casters sharing one wand each keep their own half of the year, which is the only
-- reading that makes sense of a rhythm belonging to the hand rather than the stick.
return {
    name = "Wand of the Turning Year",
    description = "Alternates a fire bolt and a frost bolt. Its bearer can neither Burn nor Freeze.",
    flavor = "Two seasons, one argument. The Arcanum has never been able to decide which half is the point.",
    sprite = "assets/items/turning_year.png",
    type = "weapon",
    -- No element tag of its own: each cast ADDS the one it is throwing (collectTags folds opts.tags
    -- in), so armor resists and the Frozen vulnerability read the bolt that was actually fired rather
    -- than a wand that claims to be both things at once.
    tags = { "wand", "magical", "ranged" },
    class = "mage",
    price = 620,
    repRank = 4,
    -- Immune to what it deals, from any source. Scoped to debuffs by Status.namedImmunity, so it
    -- refuses nothing the bearer wants.
    statusImmunity = { "status_burn", "status_freeze" },
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 6 }, -- dearer than a plain wand's 4: the rhythm is not free
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9 }, -- the feeblest wand per cast; the pairing is the weapon
        effect = function(fx)
            -- Which half of the year this bolt is, flipped before it is thrown so the NEXT cast is
            -- already committed to the other one. A battle always opens on fire (nil is falsy), which
            -- means the frost -- the setup half -- is what the mage's second shot buys.
            local frost = fx.user.turningYear or false
            fx.user.turningYear = not frost
            if frost then
                -- Winter: a shard, and the brittleness that is the whole point of it. The delay rides
                -- the blow (`inflicts`) so it lands after mitigation is settled -- the ice cannot make
                -- the bolt that made it hit harder.
                fx.damage(fx.target, { tags = { "ice" }, inflicts = { id = "status_freeze", magnitude = 2 } })
            else
                -- Summer, and the collection: a fire hit against anything still Frozen from the last
                -- cast is read as `vulnerable` by Combat.mitigatedDamage, with no help from anybody.
                fx.damage(fx.target, { tags = { "fire" }, inflicts = { id = "status_burn" } })
            end
        end,
    },
}

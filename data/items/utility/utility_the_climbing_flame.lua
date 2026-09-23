-- THE CLIMBING FLAME: what a company carries out of a flue, and it is the elite's own sentence rather
-- than either of its halves.
--
-- A FIRE CLIMBS BECAUSE IT DRAGS AIR IN BEHIND IT. The Whirl Elemental is that made into a body: its haul takes
-- a burning foe the whole length of the room and a cold one a single stumbling tile
-- (data/items/weapon/weapon_chimney_draw.lua). What a player gets is the same rule at a hand's scale --
-- your fire is the handhold, and what it holds is whatever you set alight.
--
-- SO IT IS THE ONLY PIECE THE STRATUM SELLS THAT IS ABOUT THE COMBINATION. The flock sells the shove
-- (utility_the_updraught), the coils sell the tether (utility_the_slow_circle), the Fire Elemental sells the
-- retaliation and the Wind Elemental the stance. This one does nothing at all until two of the player's own
-- systems are pointed at the same body, which is the correct shape for the thing at the bottom of the
-- floor.
--
-- WHY IT SHELVES AT THE BOMBARDIER. "Throws bombs at range. Each one leaves a hazard on the ground where
-- it lands, and a blast sets off any other bomb near it" (data/classes/bombardier.lua) -- a house whose
-- entire stock lights people up and then covers the ground in things you would like them to walk over.
-- Combat.pull and Combat.knockback resolve a drag one tile at a time, springing every trap and hazard on
-- the way, so this is the piece that makes them walk over it. `class` is the vendor shelf and never an
-- equip gate (docs/classes.md): anyone who can put fire on a target can carry this, and a company with
-- no fire at all carries a blank.
--
-- A PULL AND NOT A SHOVE, AND THE DIRECTION IS WHAT LETS THE GATE BE THIS LOOSE. trait_stooping_blow is
-- melee-only because a shove on every arrow is a free disengage -- strictly good, never once a decision.
-- A drag on every arrow brings the thing you are shooting one tile nearer, which is a decision every
-- time. See data/traits/trait_climbing_flame.lua for the rest of that argument, and for why it declines
-- to fire in melee at all.
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "The Climbing Flame",
    -- "at range" is a banned phrase here (tests/item_text_style_spec): the target/range rows carry that
    -- on an item that HAS them, and a flat ban is cheaper than a per-item judgement. Said as the
    -- condition it actually is instead -- the drag needs somewhere to drag from.
    description = "A burning foe you hit without standing beside it is dragged a tile toward you.",
    flavor = "It is not reaching for you. It is reaching for the air behind you, and you are in it.",
    sprite = "assets/items/the_climbing_flame.png",
    type = "utility",
    tags = { "charm", "fire" },
    class = "bombardier",
    -- Rung 14, an empty one on this shelf and deliberately near the top of it: this is the elite's own
    -- piece, it does nothing at all until the bearer already commands fire, and a Bombardier who does
    -- not is exactly who a cheap rung would hand it to. The ramp wants the deep end carrying more than
    -- the front (tools/shelf_curve.lua, tests/unlock_ladder_spec.lua).
    unlockLevel = 4,
    traits = { "trait_climbing_flame" },
}

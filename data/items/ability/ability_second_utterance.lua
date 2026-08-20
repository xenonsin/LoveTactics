-- Second Utterance: hand an ALLY the thing every channelled working in this game pays for. A wind-up
-- resolves AT ONCE -- no telegraph anyone can step out of, and nothing a stun can shatter.
--
-- WHICH wind-up depends on what the ally is doing when the word is spoken, and that is one idea rather
-- than two. Catch them already mid-working and the spell in their mouth lands on this beat
-- (fx.hastenChannel): the blast falls before the bodies under it get their turn to walk clear, and
-- before anything on the field gets to shatter it. Catch them holding none and the promise is banked
-- instead (data/status/status_second_utterance.lua) against the next one they speak. Either way the
-- purchase is the same sentence -- the tell goes away -- and the ally's tempo is untouched by it: a
-- hastened channeler still pays its spell's recovery from where it stands, so its next real turn falls
-- on the tick it was always going to (see endTurn's out-of-band branch in models/combat.lua).
--
-- The mid-working half is why this wants to be aimed at somebody in trouble. A channel is the one
-- commitment in the game that can be taken away after it is paid for -- knocked, displaced, dismissed,
-- or simply out-walked -- and this is the only thing in the game that answers that, from range 2, on
-- somebody else's behalf.
--
-- Why this exists as an ability at all. The effect used to live on a WAND aimed at a friend, which is not
-- a thing a weapon should be: a weapon pointed at your own side cannot be graded (its damage has no
-- honest number -- see Balance.gradesOnMagnitude) and docs/weapons.md carried a ⚠️ against it. The wand
-- became a wand again; this is where the gift belongs, on the shelf where every other single-target
-- blessing already lives.
--
-- It is not a duplicate of data/items/utility/utility_second_utterance.lua, and the difference is the
-- whole reason both are worth a slot. The charm banks the free cast for ITS OWN BEARER, and only after a
-- channel of theirs has already landed -- it rewards a mage who got one through. This one is a cast, it
-- goes to SOMEBODY ELSE, and it asks nothing first. A mage carrying it can hand a greatswordsman an
-- untelegraphed Avalanche or let an archer loose a Knell-Shaft the turn they decide to, neither of which
-- the charm can do for anyone.
--
-- Priced and gated like the charm rather than under it. Handing the party's heaviest single blow a
-- deleted telegraph is the same purchase whichever direction it points, and a cheaper version of a
-- 520-gold charm sitting two shelves earlier would simply retire it.
--
-- Slow on purpose (speed 8, as Reflect Magic is): the mage spends a real slice of their own tempo to buy
-- somebody else's. It needs a channelled weapon in the party to mean anything at all, so a mage who
-- bought it for a company of daggers has bought nothing -- which is the read, and it is theirs to get
-- wrong.
return {
    name = "Second Utterance",
    description = "Resolves an ally's channeled spell at once. If they hold none, grants them Second Utterance instead.",
    flavor = "Saying it once was always enough. The Arcanum spent four hundred years finding out who had to say it.",
    sprite = "assets/items/ability_second_utterance.png",
    type = "ability",
    tags = { "arcane", "protective" },
    class = "mage",
    price = 80,
    unlockQuests = 0,
    activeAbility = {
        target = "ally", -- includes the caster: a unit is its own ally, so a mage may speak for itself
        support = true,
        range = 2,
        speed = 8,
        cost = { stat = "mana", amount = 22 },
        effect = function(fx)
            -- Already mid-working: the word finishes it here. Holding none: the word is kept for the
            -- next one. Written as a fall-through rather than two branches because there is only one
            -- thing being bought, and a body can never be in both states at once.
            if not fx.hastenChannel(fx.target) then
                fx.applyStatus(fx.target, "status_second_utterance")
            end
        end,
    },
}

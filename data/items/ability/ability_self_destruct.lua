-- Self-Destruct: the Bomblet stops waiting to be killed and sets itself off
-- (data/characters/character_demon_bomblet.lua, which carries this beside the Volatile Core the burst
-- actually lives in). The ACTIVE half of data/traits/trait_volatile.lua -- same ring, same 12, same
-- friend-and-foe blast -- and the reason the two exist together is that a bomb nobody chooses to
-- trigger is a bomb the player can simply walk around. The trait is what happens when you kill it; this
-- is what happens when you don't.
--
-- IT IS A CHANNEL, and that is the whole of its counterplay. The bomber winds up for two ticks wearing
-- the channeling badge, exactly as the Champion's Roar does (data/items/ability/ability_demon_roar.lua),
-- and the party gets a real turn inside the tell with three separate answers to it:
--   * STEP OUT -- the blast lands on the tile the bomber is standing on, so a body that walks one tile
--     clear takes nothing. The only answer the passive trait never allowed.
--   * SHOVE IT -- any knockback breaks a channel (Combat.interruptChannel via shoveStep), and the
--     wind-up is wasted. A mace, the Sworn Aegis, Clear Out: the bomb is defused, not merely moved.
--   * KILL IT -- which does NOT deny the blast: the trait answers the death with the same ring. That
--     asymmetry is the point. Killing a bomblet in your own teeth was always the wrong answer, and a
--     bomber that can pull the pin itself is what stops "kill it later" from being a right one.
--
-- No cost: the Bomblet has no stamina and no mana, and pricing a suicide in a pool it does not own
-- would just mean it never fires. What it spends is itself -- fx.expendSelf takes it off the field as
-- a DISMISSAL rather than a death, which is what keeps the trait from bursting a second time over the
-- corpse of a bomber that already burst (see the helper in models/combat.lua for the full reasoning).
--
-- The AI rule rides on the ability rather than on the Bomblet's blueprint, because it is a fact about
-- the ability: anything ever handed this wants to use it the same way, and the scoring does the rest --
-- Combat.previewAbility prices the ring from every tile the bomber could walk to, the plan takes the
-- best one, and the `outcome > 0` gate means it only ever pulls the pin with somebody in the blast.
-- Its own removal is not priced at all (fx.expendSelf is inert in the dry run), which is correct for
-- the one unit that carries it: the body IS the ammunition.
--
-- Unpriced and class-less, like the Volatile Core: not gear anyone shops for. The Volatile Carapace
-- (data/items/armor/armor_volatile_carapace.lua) deliberately does NOT grant it -- the player's version
-- of this rule is a death you plan for, not a button you press.
return {
    name = "Self-Destruct",
    description = "Channeled: bursts in area, allies included.",
    flavor = "It was never meant to come home. It has stopped pretending otherwise.",
    sprite = "assets/items/ability_blast_charge.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "fire", "explosive" },
    bound = true, -- what the thing IS; never lifted off it
    activeAbility = {
        -- Centred on the bomber: there is nothing to aim, only somewhere to stand (see Clear Out's
        -- header on the same shape). `support = false` because a self-target otherwise reads as a
        -- kindness and would preview green -- Combat.isSupportAbility.
        target = "self",
        support = false,
        range = 0,
        windup = 2, -- the tell: the window a step, a shove or a stun has to answer it
        speed = 4,
        -- The same 12 the trait throws, and it must STAY the same 12: the Bomblet promises that the
        -- damage only ever comes from the burst, however the burst is triggered, and a player who
        -- learned the number from a bomblet they shot must not be surprised by one that jumped them.
        -- tests/demon_champion_spec.lua pins the two together.
        damage = 12,
        aoe = { shape = "diamond", radius = 1 }, -- the four tiles around it: Combat.unitsNear's ring
        ai = {
            -- High, and unconditional on purpose: the Bomblet has no other action, so "is there anyone
            -- to kill at all" is the only question worth asking here. Whether the ring is worth
            -- spending itself on is settled by the score, not by this rule -- with nobody in the blast
            -- the outcome is 0, the rule takes nothing, and the posture walks it closer instead.
            { priority = "high", act = "cast", when = { subject = "any_foe", test = "exists" } },
        },
        effect = function(fx)
            -- The blast, exactly as trait_volatile throws it: everything in the ring but the bomber
            -- itself, friend and FOE alike (no side filter). You can bait one into its own kind, and a
            -- clustered pack chain-reacts as each blast kills the next and its trait answers.
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user then fx.damage(u) end
            end
            -- ...and the bomber is gone. Last, so the ring is thrown from the tile it stood on -- and
            -- guarded inside the helper, because a chain can already have taken it.
            fx.expendSelf(string.format("%s bursts.", fx.user.char.name or "The bomber"))
        end,
    },
}

-- THE PEERLESS: Pride's apex, and the one apex in the descent that is NOT a four-tile body.
--
-- That is deliberate and it is the circle stating itself. Every other stratum's apex occupies ground --
-- a door closed, a road blocked, a wall of animal. This one refuses to be surrounded on principle: it
-- duels, it carries the rank rule like everything else here, and it is at its worst in the open and its
-- best in a doorway where only one of you can reach it at a time.
--
-- So the castle's `rooms` carve, which the whole circle is built around, is the Peerless's advantage
-- rather than the player's. On every other floor a warren is where you break a formation. Here it is
-- where the formation only needs to be one body wide.
--
-- Tier 3's band is 81-154 health; it sits high, because a single-tile body meant to hold a door has to
-- survive being focused.
return {
    name = "The Peerless",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/the_peerless.png",
    stats = {
        health = 148, mana = 20, stamina = 26,
        staminaRegen = 3,
        damage = 17, magicDamage = 0,
        defense = 13, magicDefense = 10,
        movement = 4,
        speed = 5, -- it acts often, which is most of what makes a duellist a duellist
    },
    -- THREE ITEMS, because an Elite humanoid is a signature relic and a rule list that reads rather than
    -- a health pool with a sword (tests/bestiary_spec.lua). The First Blade is the signature -- the duel
    -- rule that inverts its own circle -- and the rank kit is what it shares with everything else here.
    startingItems = { "weapon_gilded_pike", "utility_first_blade", "utility_rank_and_file" },
    defaultAction = "weapon_gilded_pike",
    -- Basic tactics (models/ai.lua): `aggressive` on whoever is closest to falling. It picks one and
    -- stays on it, which is what a body paid for duelling should do.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}

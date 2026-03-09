// Simple dialogue with choices
VAR player_name = "Stranger"

=== start ===
An old man looks up as you enter.
"Ah, a visitor! What brings you to my shop?"

* "I'm just browsing."
    "Take your time, {player_name}."
    -> shop_browse
* "I'm looking for something specific."
    "Oh? And what might that be?"
    -> shop_specific
* "Who are you?"
    "Me? I'm just an old shopkeeper. Been here for 40 years."
    -> start

=== shop_browse ===
You look around the cluttered shelves.
-> END

=== shop_specific ===
* "A magic sword."
    "Hmm, I might have one somewhere..."
* "A healing potion."
    "Ah yes, very popular item!"
- -> END

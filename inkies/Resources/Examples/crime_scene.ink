// Crime Scene - A simple interactive mystery
VAR found_clues = 0

=== start ===
The room was dark, save for the single pool of light around the body.

* [Examine the body]
    -> examine_body
* [Look around the room]
    -> look_around
* {found_clues >= 2} [Make an accusation]
    -> accusation

=== examine_body ===
~ found_clues++
The victim was a middle-aged man. There was a strange mark on his neck.
-> start

=== look_around ===
~ found_clues++
You notice a half-empty wine glass on the table.
-> start

=== accusation ===
"It was poison in the wine!" you declare.
-> END

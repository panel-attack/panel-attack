Custom Puzzles

This guide will teach you how to make custom puzzle files for Panel Attack

Puzzle files should be named something like WhateverName.txt and placed into your puzzles folder.
ie. %appdata%\Panel Attack\puzzles
Each puzzle file can contain as many puzzle sets as you like. Each set within a file can contain any number of 
individual puzzles.

The contents of each puzzle file should be formatted something like this:

{
"set name 1":
[
["numbers mapping out puzzle 1 in this set", Number of moves allowed],
["numbers mapping out puzzle 2 in this set", Number of moves allowed],
["numbers mapping out puzzle 3 in this set", Number of moves allowed]
],
"set name 2":
[
["numbers mapping out puzzle 1 in this set", Number of moves allowed],
["numbers mapping out puzzle 2 in this set", Number of moves allowed],
["numbers mapping out puzzle 3 in this set", Number of moves allowed]
]
}


Note: carriage returns in your file are very helpful for readability,
 but are not necessary, and unfortunately don't get automatically put into the example 
 "stock (example).txt" file.
 
Be sure to use the correct delimiters in the right places, i.e: 
curly braces {} to start and end the file,
square brackets [] around individual puzzles and around puzzle sets,
quotes "" around set names and panel maps
commas between elements, but not after the last element in a list.

See the example file at the bottom of the guide for reference.


About the numbers mapping out each puzzle now:

Panel Attack reads the numbers that represent what each panel's color should be from right to left,
filling the play field with panels starting at the bottom right corner, from right to left, bottom to top.

This allows us to lay out our text representation of the puzzle how it would look in the game, like this:

001200
002100
002100

Note: you do have to remove the carriage returns when you're done making the individual puzzle.
The same all on one line would be like this:
001200002100002100

Carriage returns in the file are OK, but not in the middle of the panel maps for each individual puzzle.

panel colors:
0 = empty
1 = red
2 = green
3 = light blue
4 = yellow
5 = purple
6 = dark blue
7 = orange (not really used in the game so far, but it exists)
8 = exclamation block [!]
9 = block with no color (dark grey, doesn't match with anything)

For reference: here's how to make a file with classic sets 1 and 2:
I'll change the set names slightly (by adding an !), since you can't load two sets with the same name.

{
"Classic set 1!":
[
["10110",1],
["3000033030",1],
["2100001200001200",1],
["6400006400004600006400006400",1],
["2000223303",1],
["115155",1],
["1000001000003000001000001000003300",1],
["40000040055450",1],
["3000002300002230",1],
["4100001400004100001400004100",3]
],
"Classic set 2!":
[
["4000001000001000004000001440",1],
["60000026000062200",1],
["3300055350",1],
["1200001212",2],
["363636",3],
["3000332000224000441000115000556000663000332000224000441600116600",1],
["600002600062200",2],
["5000005000001000001500005100",2],
["2200004400004200",2],
["13000031000013110",2]
]
}


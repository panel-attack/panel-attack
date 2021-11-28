Custom Puzzles

This guide will teach you how to make custom puzzle files for Panel Attack

Puzzle files should be named something like WhateverName.txt and placed into your puzzles folder.
ie. %appdata%\Panel Attack\puzzles
Each puzzle file can contain as many puzzle sets as you like. Each set within a file can contain any number of 
individual puzzles.

The contents of each puzzle file should be formatted something like this:

{
  "Version": 2,
  "Puzzle Sets": [
    [
      "Set Name": "Name of Puzzle Set",
      "Puzzles": [
        [
          "Puzzle Type": "chain",
          "Do Countdown": true,
          "Moves": 0,
          "Stack": 
            "040000
             111440",
        ],
        [
          "Puzzle Type": "moves",
          "Do Countdown": false,
          "Moves": 2,
          "Stack": 
            "999799
             994999
             999499
             994999
             997999
             997999",
        ],
      ]
    ],
  ]
}

Version should be 2 for now

"Puzzle Sets" contains a list of all the puzzle sets

"Set Name" is the name of the set
"Puzzles" is the list of all the puzzles

"Puzzle Type" should be one of the following
    "moves" all panels need to be cleared in the set number of moves
    "chain" all panels need to be cleared onces the first chain ends, and there must be a chain

"Do Countdown" whether to do the countdown at the beginning

"Moves" the number of moves, can be zero to not have a limit

"Stack" the starting arangement of the panels, see below

Note: carriage returns and spaces in your file are very helpful for readability,
 but are not necessary.
 
Be sure to use the correct delimiters in the right places, i.e: 
curly braces {} to start and end the file,
square brackets [] around individual puzzles and around puzzle sets,
quotes "" around set names and panel maps
commas between elements

About the numbers mapping out each puzzle now:

Panel Attack reads the numbers that represent what each panel's color should be from right to left,
filling the play field with panels starting at the bottom right corner, from right to left, bottom to top.

This allows us to lay out our text representation of the puzzle how it would look in the game, like this:

001200
002100
002100

Carriage returns are allowed in the middle of the panel maps for each individual puzzle.

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

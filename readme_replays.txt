Replay Files

"in_buf" and "I" represent P1's and P2's inputs, respectively. Every character represents a frame.

Inputs are mapped to binary values.
0 - (do nothing)
1 - Right
2 - Left
4 - Down
8 - Up
16 - Swap
32 - Raise Stack

There are 64 legal case-sensitive characters that can be put in a Replay, which are:

ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890+/

Using math, you can figure out what inputs go to each character by adding them together. These characters follow an index order, so consider them 0-63. 

For example, let's say that a player is inputting both down and right at the same time. Right is equal to 1, and Down is equal to 4. Therefore, we would add them both together (1 + 4 = 5) to reach the letter "F". (Remember that since we are dealing with indexes, we start counting at 0).

Common actions:

A = Do nothing
B = Move Right
C = Move Left
E = Move Down
I = Move Up
Q = Swap
g = Raise Stack

"P" and "O" represent P1's and P2's stacks, respectively. Every character represents a block, starting from row 7, column 1. They are always given in batches of 120, for a total of 20 rows with 6 columns.

0 = Air
1/a/A = Red
2/b/B = Green
3/c/C = Cyan
4/d/D = Yellow
5/e/E = Purple
6/f/F = Blue
7/g/G = Orange
8/h/H = Metal
9/i/I = Debug

"Q" and "R" represent P1's and P2's garbage panels, respectively. They are always given in batches of 120. Every character represents a panel, but they are used by garbage blocks to decide what panels to turn into when they are broken.

For example, if a garbage block that is 4 blocks wide is broken, the blocks will turn into the first 4 characters. Let's say that the starting characters are "4312". When the garbage block converts into panels, the first block will turn yellow (4), the second into cyan (3), the third into red (1), and fourth into green (2).


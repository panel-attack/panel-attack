This document describes the interface for computer players and the mechanism through which they interact with the game.

# Mechanism

The computer player interacts with the game as an alternative form of an "input device". If a match has a computer player, the computer player runs as part of the `Match:run()` routine and queues up an input for the computer player's stack.

The class `ComputerPlayer` in `computerPlayer.lua` acts as en entry point and enables the usage of different implementations of a computer player by defining a pseudo-interface that implementations need to fulfill in order to work.

In this way, the computer player is completely separate from the rest of the game's logic, allowing for easy integration of multiple different implementations of computer players. New computer player implementation should get added in their folder under `computerPlayers`.

In order to allow the CPU to make reasonable decision it is constructed with the stack table as an argument. This table is the reference to the real stack used by the engine and __must not be altered__ by the computer player in any way.

# Interface

## Identifier

Any implementation needs a unique name. This name is used by the computer player to instantiate the correct implementation.

## Constructor

In order to make reasonable decisions, knowledge about the stack is integral. Any implementation needs to accept a stack as an argument on creation.

## Configuration

One of the general goals for computer player implementations is configurability. A computer player implementation should be able to return a table of preset configurations via `getConfigs` among which the player can select and possibly finetune. Finally the selection of the user needs to get back to the computer player for which the setter `setConfig` needs to be implemented.

## GetInput

`getInput` is the integral function for any computer player implementation to do its work. It is mandatory that this function returns an input every time it is run. Inputs are encoded in a binary value to allow different inputs to occur at the same time.

| Input | Value |
|-------|-------|
| Idle  | 0 |
| Right | 1 |
| Left  | 2 |
| Down  | 4 |
| Up    | 8 |
| Swap  | 16 |
| Raise | 32 |

To the combined binary value, 1 needs to be added. This value is then converted into a single character value via the `base64encode` array, e.g. for swap + down, `16 + 4 + 1 = 21` -> `base64encode[21]`.
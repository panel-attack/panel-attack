# Endaris CPU

This Cpu is for now nicknamed after the user spearheading its development. In this document the ideas and processes the CPU uses are being explained along with the code that put them into action.

## Core Loop

One general issue for any CPU is concurrency. A CPU should run in the background, it should not affect the game's mainloop and it should not cause frame drops of any kind. Lua doesn't support true concurrency and instead only provides coroutines to switch processes running on a single thread. Therefore, it has to be possible for the CPU to interrupt its processing if it takes too long, pass the ball back to the main thread and only resume processing later. 

The core loop of the CPU is defined in the `think` function and resumed every time the game prompts for a new input via the `getInput` interface. The `getInput` method additionally records the current time before it resumes `think`.
Inside the `think` function, individual calculation steps should be separated by the function `yieldIfTooLong` to ensure that the processing does not take up too much time. With this staggered approach it can be assured that `think` yields in a timely manner - under the assumption that the individual calculation steps are small and granular enough to ensure that they aren't individually taking long.





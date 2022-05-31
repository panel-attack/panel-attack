Adding/modding Attack Files: step by step instructions (Windows example):
1. Press the Windows key then type "%appdata%" without quotes and hit enter.
2. Look in the folder located in: %appdata%\Panel Attack\training\ for a reference of where your files should go and how they should be named. Folders starting with "__" will be ignored upon loading.
   
An attack file looks something like this:
{
  "name": "Attack File Example",
  "mergeComboMetalQueue": false,
  "delayBeforeStart": 150,
  "delayBeforeRepeat": 91,
  "attackPatterns": [
    {
      "width": 6,
      "height": 1,
      "startTime": 540
    },
    {
      "chain": [300, 360, 420, 480, 540],
      "chainEndTime": 613
    }
  ]
}

- "name": The display name of the attack file. Defaults to the name of the file if unused.
- "mergeComboMetalQueue": Makes the game disregard combo/metal garbage priority. Allows you to send shock garbage before combo garbage, for instance. Defaults to false if unused.
- "delayBeforeStart": The initial amount of frames (always assume 60fps) to wait from the beginning of the game before sending the attack pattern.
- "delayBeforeRepeat": The amount of frames to wait in between repeating the attack pattern again after it has sent all the garbage in the "attackPatterns" table.
- "attackPatterns": This holds an array of all the garbage that is to be sent. You can put as much garbage data in here as you want. Each table represents one piece of garbage.

For Combo Garbage:
- "startTime": The amount of frames to wait after the attack pattern has been started before sending the garbage. This is relative to the beginning of the attack pattern.
- "width": The width of the garbage block, ranging from 1-6.
- "height": The height of the garbage block, defaults to 1. You CAN create chain-size blocks by changing this value to numbers greater than 1, and those blocks will be treated like combo garbage.
This can allow you to send multiple chain-size blocks to the garbage queue, which is normally impossible during standard gameplay.
- "metal": This determines whether or not the garbage is metal. Defaults to false if unused.
See the "ComboExample.json" file for reference.

There are two ways to program chain blocks, the first way being:
- "startTime": The amount of frames to wait after the attack pattern has been started before sending the garbage. This is relative to the beginning of the attack pattern.
- "height": How tall the garbage block is.
- "chain": How many frames it takes for each "stage" of the chain block to grow. For example, a chain block where height = 5 and chain = 60 would take 300 frames to fully grow to its max size.
- "chainEndDelta": The amount of frames to wait after the chain has fully grown in order to commit it to the garbage queue. This value is relative to the amount of time it takes for the garbage to grow,
so a chain garbage block that takes 300 frames to grow to max size where chainEndDelta = 50 takes a total 350 frames to be committed.
See the "ChainMultiplyExample.json" file for reference.

The second method:
- "chain": An array of numbers that represent the frame relative to the beginning of the attack pattern to grow the chain size. The lowest number is considered the "startTime" of the chain.
- "chainEndTime": The amount of frames to wait after the chain has fully grown in order to commit it to the garbage queue. This is relative to the beginning of the attack pattern instead of the chain itself.
See the "ChainTableExample.json" file for reference.
General note to keep in mind for all garbage: Your "delayBeforeRepeat" plus the largest "startTime" you have needs to equal at least 91 in order for your garbage to send, or else it will queue indefinitely. 

# Garbage Queue

The way garbage is delivered in this game is quite non-intuitive so this document tries to shed some light on the formal process.  

## General process 

Generally garbage delivery is divided into 3 phase:  
1. Staging (the confusing part)
2. Delivery
3. Delay

### Staging

The staging process is implemented in engine.telegraph.  
A telegraph is owned by the sender of garbage but also has a reference to the target.  
Upon achieving a chain or combo during the check for matches, a stack will push a new piece of garbage to its telegraph which then manages the staging process on its own.  

#### In detail

The staging area is the area in which garbage, specifically chain garbage, may still get modified and in which garbage orders and delays itself according to some rules.  

The cardinal rules are the following:  
1. When a piece of garbage enters staging, it is scheduled to stay inside of staging for a minimum of 90 frames.
2. Combo garbage cannot leave the staging phase while chain garbage remains in it.
3. Metal garbage cannot leave the staging phase while combo garbage remains in it.

The other rules differ depending on chain or combo garbage.  
For chain garbage:  
1. Chain garbage will stay in staging while the corresponding chain is still on-going.  
2. The scheduled stay for a chain starts with the time of its last chain link.

For combo garbage:  
1. Combo garbage cannot leave the staging phase while smaller combo garbage remains in it.  
2. Combo garbage entering the staging phase extends the stay of all combo garbage of the same size to the new garbage's scheduled stay.

### Delivery

On every frame, the owning stack asks its telegraph whether there is any garbage ready for delivery.  
If so, the garbage is released from the telegraph/staging phase.  
At this point, the actual time the garbage is scheduled to drop at the earliest is determined as the time the garbage left staging + a constant delay of 60 frames.  
The now scheduled garbage is saved in a table on the garbage target.  
The receiving stack checks this table every frame to see if any garbage inside that table is scheduled to drop.  
If so, it gets added to the stack's own garbage queue which is equivalent to entering the final Delay phase.

### Delay

Once garbage entered the Delay phase, the stack checks on every frame whether the highest priority piece of garbage should drop or not.  
Only one piece of garbage may be dropped per frame.  

Priority rules:  
1. Chain garbage drops before combo garbage.  
2. Chain garbage drops in order by height from small to big.  
3. Combo garbage drops before metal garbage.  
4. Combo garbage drops in order by width from small to big.  

Whether this piece of garbage will drop depends on three conditions:  

1. If it originates from a chain and has a height of more than 1, it will get dropped.  
2. If there haven't been active panels on the last and the current frame, the garbage will get dropped.  
3. If the stack has panels in its highest row or another piece of garbage is still falling, no garbage may drop, regardless of the other conditions.  

Upon dropping, the garbage enters its target stack in the form of panels and is removed from the stack's queue.
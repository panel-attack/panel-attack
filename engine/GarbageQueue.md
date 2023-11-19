# Garbage Queue

The way garbage is delivered in this game is quite non-intuitive so this document tries to shed some light on the formal process.  

## General process 

Generally garbage delivery is divided into 3 phase:  
1. Staging (the confusing part)
2. Delivery
3. Delay

### Staging
 
Upon achieving a chain or combo during the check for matches, a stack will push a new piece of garbage to its staging area. The staging process always runs fully on the sender's side.

#### In detail

The staging area is the area in which garbage, specifically chain garbage, may still get modified and in which garbage orders and delays itself according to some rules.  

The cardinal rules are the following:  
1. When a piece of garbage enters staging, it is scheduled to stay inside of staging for a minimum of 90 frames.
2. Combo garbage cannot leave the staging phase while chain garbage remains in it.
3. Metal garbage cannot leave the staging phase while combo garbage remains in it.

The other rules differ depending on chain or combo garbage.  

##### Chain garbage

1. Chain garbage will stay in staging while the corresponding chain is still on-going.  
2. The scheduled stay for a chain starts with the time of its last chain link.

##### Combo garbage 

1. Combo garbage cannot leave the staging phase while smaller combo garbage remains in it.  
2. Combo garbage entering the staging phase extends the stay of all combo garbage of the same size to the new garbage's scheduled stay.

### Delivery

On every frame, the sending stack checks whether there is any garbage ready for delivery in the staging area.  
If so, the garbage is released from the staging phase and enters delivery which is a static 60 frame delay before the garbage can be dropped on its target.  
After the delay has passed, the garbage is added to the receiver's own garbage queue which is equivalent to entering the final Delay phase.

### Delay

Once garbage entered the Delay phase, the stack checks on every frame whether the highest priority piece of garbage should drop or not.  
Only one piece of garbage may be dropped per frame.  

#### Priority rules 

1. Chain garbage drops before combo garbage.  
2. Chain garbage drops in order of creation.  
3. Combo garbage drops before metal garbage.  
4. Combo garbage drops in order by width from small to big.  

#### Requirements for dropping

If the stack has panels in its highest row or another piece of garbage is still falling, no garbage may drop at all.  
If this is not the case, garbage will drop if it fulfills either of the following conditions: 

1. If it originates from a chain and has a height of more than 1  
2. If there haven't been active panels on the last and the current frame  

Upon dropping, the garbage enters its target stack in the form of panels and is removed from the receiver's queue.
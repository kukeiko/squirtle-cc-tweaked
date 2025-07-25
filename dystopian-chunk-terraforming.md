- issue "terraform chunk" task
- will first issue a "creat chunk storage" task
  - that task is in charge of setting up a small storage system completely contained within the target chunk
  - that storage is used by another turtle to store its harvested items in, and also to receive required items like fuel
  - we either create a storage that will be big enough and does not need expanding, or we add logic that a storage can be expanded
    - building it big enough from the get-go is much simpler
- once the chunk storage is created, we can have another turtle work on the task "terraform chunk"
  - we can give that turtle a silk touch pickaxe (using the data-pack that allows enchanted tools)
  - the turtle should have 1x disk drive and a few shulkers in its inventory
  - or we add the complicated process of smelting cobblestone to stone, and craft cobbled deepslate to the "clean" variant
- it could assume that the storage is built above the highest block of the chunk, meaning that it just digs everything below the storage
- it'll utilize TurtleApi.digArea() which can fill shulkers already when getting full
  - digArea() needs adaptation to exit early if all shulkers are full
  - it is possible to make it resumable: once digArea() returns because all shulkers are full, switch to the next resumable main() (i.e. add two separate main methods: "dig" and "return-from-dig")
  - once at home, run non-simulatable homework main() that'll just dump everything and fuel up
    - I don't think I have logic yet anywhere that doesn't use I/O chests. need dump() logic that will keep disk drive and empty out shulker boxes
    - [todo] ❌ I'm thinking of making storage interpret every barrel as a dump - could make the dumping logic easier because we don't have to check if dump chest is empty excluding the "Dump" nametag
  - return to digging
  - ❌ we need to break out of this loop once bedrock has been hit. the new Resumable class doesn't support that yet. there are several ways to do it:
    - we could use 1x resumable class instance for the whole task
    - we could use multiple resumable class instances and select based on some other saved state
      - right now this makes more sense to me. all we would need is for Resumable to support breaking out of the loop. we can save the state which resumable to use within the task entity.
- after everything has been dug out, do two things:
  - issue a task to clear out the storage from materials not used to rebuild the chunk
  - rebuild the chunk from bottom to top, starting with deepslate, then stone, then dirt

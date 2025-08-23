local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local TaskService = require "lib.systems.task.task-service"
local StorageService = require "lib.systems.storage.storage-service"
local ItemApi = require "lib.apis.item-api"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local TurtleInventoryService = require "lib.systems.storage.turtle-inventory-service"
local buildChunkStorage = require "lib.systems.builders.build-chunk-storage"

---@param task BuildChunkStorageTask
return function(task)
    local taskService = Rpc.nearest(TaskService)
    local storageService = Rpc.nearest(StorageService)

    -- [todo] ❌ assert that turtle is connected to turtle hub
    -- [todo] ❌ clean out any unneeded items
    -- [todo] ❌ issue task to provide basic items (disk drive, shulkers, ...)
    -- [todo] ❌ issue task to provide required items (chest, computer, network cables, ...)

    local results = TurtleApi.simulate(function()
        buildChunkStorage()
    end)

    local requiredItems = TurtleApi.getOpenStock(results.placed, true)
    local requiredCharcoal = ItemApi.getRequiredRefuelCount(ItemApi.charcoal, TurtleApi.missingFuel())

    local inventoryServer = Rpc.server(TurtleInventoryService, "wired")
    local inventory = inventoryServer.getWiredName()
    local failed = false

    EventLoop.run(function()
        inventoryServer.open()
    end, function()
        storageService.mount({inventory})
        storageService.refresh({inventory})

        if requiredCharcoal > 0 then
            -- [todo] ❌ add option that it should only return if everything got transferred
            print("[issuing] charcoal", requiredCharcoal)
            local provideCharcoal = taskService.provideItems({
                issuedBy = os.getComputerLabel(),
                partOfTaskId = task.id,
                craftMissing = false,
                items = {[ItemApi.charcoal] = requiredCharcoal},
                to = {inventory}
            })

            if provideCharcoal.status == "failed" then
                print("[error] providing charcoal failed")
                taskService.failTask(task.id)
                failed = true
                return
            end

            TurtleApi.refuelTo(TurtleApi.getFiniteFuelLimit())
        end

        print("[issuing] shulkers...")
        local provideShulkers = taskService.provideItems({
            issuedBy = os.getComputerLabel(),
            partOfTaskId = task.id,
            craftMissing = false,
            items = {[ItemApi.shulkerBox] = requiredItems[ItemApi.shulkerBox]},
            to = {inventory},
            label = "provide-shulkers"
        })

        if provideShulkers.status == "failed" then
            print("[error] providing shulkers failed")
            taskService.failTask(task.id)
            failed = true
            return
        end

        requiredItems[ItemApi.shulkerBox] = nil

        -- [todo] ❌ for dev only
        requiredItems = {[ItemApi.birchLog] = 30 * 64}

        EventLoop.waitForAny(function()
            print("[requiring] items...")
            os.sleep(1)
            TurtleApi.requireItems(requiredItems, true)
        end, function()
            while true do
                storageService.refresh({inventory})
                os.sleep(3)
            end
        end, function()
            print("[issuing] items...")
            local provideItems = taskService.provideItems({
                issuedBy = os.getComputerLabel(),
                partOfTaskId = task.id,
                craftMissing = true,
                items = requiredItems,
                to = {inventory},
                -- [todo] ❌ it took me a while to figure out that I have to use labels to not reuse the
                -- previous provideItems() task
                label = "provide-materials"
            })

            if provideItems.status == "failed" then
                print("[error] providing items failed")
                taskService.failTask(task.id)
                failed = true
                return
            end

            while true do
                os.sleep(10000)
            end
        end)

        inventoryServer.close()

    end)

    term.clear()
    term.setCursorPos(1, 1)
    print("end task")

    if failed then
        return
    end

    taskService.finishTask(task.id)
end

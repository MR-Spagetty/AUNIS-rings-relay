local moreTable = require("moreTable")


local route = {
avalableMethods = {"BFS"},
BFS = function (node, goal, KnownRings)
    local visited = {}
    local queue = {}
    local path = {}

    table.insert(queue, node)
    table.insert(visited, node)
    while #queue > 0 do
        local working = {queue[1]}
        local near = moreTable.keys(KnownRings[working[1]].NEAR)
        if #near > 0 then
            for i, neighbour in ipairs(near) do
                if not moreTable.contains(visited, neighbour) then
                    visited[neighbour] = working
                    table.insert(queue, neighbour)
                end
            end
        else
            print("ERROR data for", working, "Missing")
        end
        table.remove(queue, 1)
        if moreTable.contains(visited, goal) then
            queue = {}
        end
    end
    local atStart = false
    local reversePath = {}
    table.insert(reversePath, goal)
    while not atStart do
        table.insert(reversePath, visited[reversePath[#reversePath]][1])
        if reversePath[#reversePath] == node then
            atStart = true
        end
        os.sleep()
    end
    for i = #reversePath, 1, -1 do
        table.insert(path, reversePath[i])
    end
    return path
end

}

return route
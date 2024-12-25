local Database = require("database")

local function main()
    local db = Database.new()
    db:run_gui()
end

main()

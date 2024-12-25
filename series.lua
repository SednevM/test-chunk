local Series = {}
Series.__index = Series

function Series.new(name, id)
    local self = setmetatable({}, Series)
    self.name = name
    self.id = id
    self.chunks = {}
    self.current_chunk_size = 0
    self.CHUNK_LIMIT = 10
    self.MAX_CHUNKS = 5
    self.chunk_counter = 0
    return self
end

function Series:append(time, value)
    if #self.chunks == 0 or self.current_chunk_size >= self.CHUNK_LIMIT then
        self.chunk_counter = self.chunk_counter + 1
        local new_chunk_id = self.id .. "_" .. self.chunk_counter
        local chunk_filename = "chunk-" .. new_chunk_id .. ".csv"

        if #self.chunks >= self.MAX_CHUNKS then
            table.remove(self.chunks, 1) -- Удаляем старый чанк
        end

        print("[VMEM] Создание нового чанка " .. chunk_filename)
        table.insert(self.chunks, chunk_filename)
        self.current_chunk_size = 0

        local file = io.open(chunk_filename, "w")
        file:write("time,value\n")
        file:write(string.format("%f,%f\n", time, value))
        file:close()
    else
        print("[VMEM] Добавление данных в существующий чанк " .. self.chunks[#self.chunks])
        local file = io.open(self.chunks[#self.chunks], "a")
        file:write(string.format("%f,%f\n", time, value))
        file:close()
    end
    self.current_chunk_size = self.current_chunk_size + 1
end

function Series:save_metadata()
    local filename = "series-" .. self.id .. ".csv"
    local file = io.open(filename, "w")
    file:write("start,end,id\n")
    for _, chunk in ipairs(self.chunks) do
        local start, end_ = self:get_chunk_bounds(chunk)
        local chunk_id = chunk:gsub("chunk%-", ""):gsub("%.csv", "")
        file:write(string.format("%f,%f,\"%s\"\n", start, end_, chunk_id))
    end
    file:close()
end

function Series:get_chunk_bounds(chunk_file)
    local start = math.huge
    local end_ = -math.huge
    for line in io.lines(chunk_file) do
        local time = tonumber(line:match("^(%S+),"))
        if time then
            start = math.min(start, time)
            end_ = math.max(end_, time)
        end
    end
    return start, end_
end

return Series

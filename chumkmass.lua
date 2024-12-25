local Chunk = {}
Chunk.loaded_chunks = {} -- Статическая таблица для хранения загруженных чанков

-- Конструктор
function Chunk.new(name)
    local self = {
        name = name,
        arr = {},
        tmin = 0,
        tmax = 0
    }
    setmetatable(self, { __index = Chunk })
    return self
end

-- Загрузка чанка из файла
function Chunk.load(name)
    -- Проверяем, загружен ли уже чанк
    if Chunk.loaded_chunks[name] then
        print("[VMEM] Использование кэшированного чанка " .. name)
        return Chunk.loaded_chunks[name]
    end

    print("[VMEM] Загрузка чанка " .. name .. " в оперативную память")
    local c = Chunk.new(name)

    local file = io.open(name, "r")
    if not file then
        error("[Ошибка] Не удалось открыть файл " .. name)
    end

    for line in file:lines() do
        if not line:find("time,value") then
            local ts, val = line:match("([^,]+),([^,]+)")
            ts = tonumber(ts)
            val = tonumber(val)

            if c.tmin == 0 or ts < c.tmin then
                c.tmin = ts
            end
            if c.tmax == 0 or ts > c.tmax then
                c.tmax = ts
            end

            table.insert(c.arr, { ts = ts, val = val })
        end
    end

    file:close()
    Chunk.loaded_chunks[name] = c
    return c
end

-- Выгрузка всех чанков из памяти
function Chunk.unload_all()
    print("[VMEM] Выгрузка всех чанков из памяти")
    Chunk.loaded_chunks = {}
end

-- Выгрузка конкретного чанка из памяти
function Chunk.unload(name)
    if Chunk.loaded_chunks[name] then
        print("[VMEM] Выгрузка чанка " .. name .. " из памяти")
        Chunk.loaded_chunks[name] = nil
    end
end

-- Сохранение чанка в файл
function Chunk:save(name)
    print("[VMEM] Сохранение чанка " .. name .. " на диск")
    local file = io.open(name, "w")
    if not file then
        error("[Ошибка] Не удалось создать файл " .. name)
    end

    file:write("time,value\n")
    for _, r in ipairs(self.arr) do
        file:write(string.format("%f,%f\n", r.ts, r.val))
    end

    file:close()
end

return Chunk

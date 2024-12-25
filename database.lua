local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local Series = require("series")

local Database = {}
Database.__index = Database

function Database.new()
    local self = setmetatable({}, Database)
    self.series = {}
    self.database_file = "database.csv"
    self:load_database()
    return self
end

function Database:add(name, id)
    if self.series[name] then
        return self.series[name]
    end
    local new_series = Series.new(name, id)
    self.series[name] = new_series
    self:save_database()
    return new_series
end

function Database:load_database()
    local file = io.open(self.database_file, "r")
    if not file then
        print("[VMEM] База данных не найдена, создается новая.")
        return
    end

    print("[VMEM] Загрузка метаданных базы данных.")
    for line in file:lines() do
        if not line:find("name,id") then
            local name, id = line:match("\"(.-)\",\"(.-)\"")
            if name and id then
                print("[VMEM] Инициализация серии " .. name)
                local series = Series.new(name, id)
                local series_file = "series-" .. id .. ".csv"
                if io.open(series_file, "r") then
                    for chunk_line in io.lines(series_file) do
                        local _, _, chunk_id = chunk_line:match("^(.-),(.-),\"(.-)\"")
                        if chunk_id then
                            table.insert(series.chunks, "chunk-" .. chunk_id .. ".csv")
                        end
                    end
                end
                self.series[name] = series
            end
        end
    end
    file:close()
end

function Database:save_database()
    local file = io.open(self.database_file, "w")
    file:write("name,id\n")
    for name, series in pairs(self.series) do
        file:write(string.format("\"%s\",\"%s\"\n", name, series.id))
    end
    file:close()
end

function Database:query_series(name, t_start, t_end)
    local series = self.series[name]
    if not series then
        print("[Ошибка] Серия " .. name .. " не найдена.")
        return {}
    end
    return series:query(t_start, t_end)
end

function Database:create_point(name, time, value)
    local series = self.series[name]
    if not series then
        print("[Ошибка] Серия " .. name .. " не найдена. Создание новой.")
        series = self:add(name, "series_" .. tostring(#self.series + 1))
    end
    series:append(time, value)
    series:save_metadata()
end

function Database:run_gui()
    local window = Gtk.Window {
        title = "Time Series Viewer",
        default_width = 800,
        default_height = 600,
        on_destroy = Gtk.main_quit
    }

    -- Элементы интерфейса
    local series_label = Gtk.Label { label = "Выберите серию:" }
    local series_combo = Gtk.ComboBoxText { expand = true }
    local t_start_entry = Gtk.Entry { placeholder_text = "t start" }
    local t_end_entry = Gtk.Entry { placeholder_text = "t end" }
    local update_button = Gtk.Button { label = "Обновить график" }

    local new_series_label = Gtk.Label { label = "Создать новую серию:" }
    local new_name_entry = Gtk.Entry { placeholder_text = "Имя новой серии" }
    local new_time_entry = Gtk.Entry { placeholder_text = "Время" }
    local new_value_entry = Gtk.Entry { placeholder_text = "Значение" }
    local create_button = Gtk.Button { label = "Создать" }

    local results_view = Gtk.TextView {
        editable = false,
        wrap_mode = "WORD",
        expand = true
    }

    -- Обновление списка серий
    local function populate_series_list()
        series_combo:remove_all()
        for name, _ in pairs(self.series) do
            series_combo:append_text(name)
        end
        series_combo:active(0)
    end

    populate_series_list()

    -- Обработчики событий
    function update_button:on_clicked()
        local series_name = series_combo:get_active_text()
        local t_start = tonumber(t_start_entry.text)
        local t_end = tonumber(t_end_entry.text)

        if not series_name or series_name == "" then
            print("Ошибка: Выберите серию.")
            return
        end
        if not t_start or not t_end or t_start >= t_end then
            print("Ошибка: Введите корректный временной интервал.")
            return
        end

        local data = self:query_series(series_name, t_start, t_end)
        local buffer = results_view:get_buffer()
        if #data == 0 then
            buffer:set_text("Нет данных в указанном интервале.")
        else
            local results = {}
            for _, point in ipairs(data) do
                table.insert(results, string.format("t: %.2f, value: %.2f", point.ts, point.val))
            end
            buffer:set_text(table.concat(results, "\n"))
        end
    end

    function create_button:on_clicked()
        local name = new_name_entry.text
        local time = tonumber(new_time_entry.text)
        local value = tonumber(new_value_entry.text)

        if not name or name == "" then
            print("Ошибка: Введите имя новой серии.")
            return
        end
        if not time or not value then
            print("Ошибка: Введите корректные значения времени и значения.")
            return
        end

        self:create_point(name, time, value)
        populate_series_list()
        print("Точка добавлена.")
    end

    -- Компоновка интерфейса
    local grid = Gtk.Grid {
        row_spacing = 10,
        column_spacing = 10,
        margin = 10
    }

    grid:attach(series_label, 0, 0, 1, 1)
    grid:attach(series_combo, 1, 0, 2, 1)
    grid:attach(t_start_entry, 0, 1, 1, 1)
    grid:attach(t_end_entry, 1, 1, 1, 1)
    grid:attach(update_button, 2, 1, 1, 1)

    grid:attach(new_series_label, 0, 2, 1, 1)
    grid:attach(new_name_entry, 1, 2, 1, 1)
    grid:attach(new_time_entry, 2, 2, 1, 1)
    grid:attach(new_value_entry, 3, 2, 1, 1)
    grid:attach(create_button, 4, 2, 1, 1)

    grid:attach(results_view, 0, 3, 5, 1)

    window:add(grid)
    window:show_all()
    Gtk.main()
end

return Database

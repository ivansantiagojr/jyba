local popup = require("plenary.popup")
local api = vim.api
local M = {}

local win_info = nil
local data = { projects = {} }

local function read_config_file(json_config_file_path)
    local file = io.open(json_config_file_path, 'r')
    local existing_data = {}
    if file then
        local content = file:read('*all')
        file:close()

        existing_data = vim.fn.json_decode(content)
        return existing_data
    end

    return existing_data
end

function M.run_cmd_on_save()
    local project_name = vim.fn.getcwd()
    local file_path = vim.fn.stdpath('data') .. '/jyba.json'

    local existing_data = read_config_file(file_path)

    if existing_data.projects and existing_data.projects[project_name] then
        local saved_commands = existing_data.projects[project_name].run_on_save
        for _, command in pairs(saved_commands) do
            vim.fn.jobstart(command, {
                on_exit = function(_, code, _)
                    if code == 0 then
                        vim.cmd('e!')
                    end
                end,
            })
        end
    end
end

api.nvim_create_autocmd("BufWritePost", {
    group = api.nvim_create_augroup("Jyba", { clear = true }),
    callback = function()
        M.run_cmd_on_save()
    end,
}
)

function M.create_window()
    if win_info then return end

    local width = 60
    local height = 10
    local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

    local bufnr = vim.api.nvim_create_buf(false, false)

    local win_id, win = popup.create(bufnr, {
        title = "Jyba",
        highlight = "JybaWindow",
        line = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        minwidth = width,
        minheight = height,
        borderchars = borderchars,
    })

    vim.wo[win_id].number = true

    win_info = {
        bufnr = bufnr,
        win_id = win_id,
    }

    local project_name = os.getenv('PWD')
    local file_path = vim.fn.stdpath('data') .. '/jyba.json'

    local existing_data = read_config_file(file_path)

    if existing_data.projects and existing_data.projects[project_name] then
        local saved_commands = existing_data.projects[project_name].run_on_save
        local commands = {}

        -- Add commands to new window
        for i, command in pairs(saved_commands) do
            commands[i] = command
        end
        api.nvim_buf_set_lines(bufnr, 0, -1, false, commands)
    end
end

function M.write_to_json(lines)
    local project_name = os.getenv('PWD')
    local file_path = vim.fn.stdpath('data') .. '/jyba.json'

    local file = io.open(file_path, 'r')
    data = read_config_file(file_path)

    -- Append the new command to the existing ones
    if data.projects then
        if data.projects[project_name] then
            data.projects[project_name].run_on_save = lines
        else
            data.projects[project_name] = { run_on_save = lines }
        end
    else
        data.projects = { [project_name] = { run_on_save = lines } }
    end

    local json_str = vim.fn.json_encode(data)

    file = io.open(file_path, 'w')
    if file then
        file:write(json_str)
        file:close()
    else
        print('Failed to open file')
    end
end

function M.destroy_window()
    if win_info then
        local opts = { force = true }
        api.nvim_buf_delete(win_info.bufnr, opts)
        win_info = nil
    end
end

function M.toggle_window()
    if win_info then
        local bufnr = win_info.bufnr
        local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        M.write_to_json(lines)
        M.destroy_window()
    else
        M.create_window()
    end
end

return M

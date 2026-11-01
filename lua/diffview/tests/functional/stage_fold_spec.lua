local config = require("diffview.config")
local helpers = require("diffview.tests.helpers")
local lib = require("diffview.lib")

local api = vim.api

describe("file panel staging folds", function()
  local repo, cwd, view, original_config

  before_each(function()
    original_config = vim.deepcopy(config.get_config())
    config.setup({ use_icons = false, auto_close_on_empty = false })
    cwd = vim.fn.getcwd()
    repo = helpers.init_repo()
    local lines = helpers.body("body", 100)
    helpers.write(repo, "file.txt", lines)
    helpers.commit(repo, "initial")
    lines[50] = "changed"
    helpers.write(repo, "file.txt", lines)
    vim.cmd("cd " .. vim.fn.fnameescape(repo))
  end)

  after_each(function()
    helpers.close_view(view)
    view = nil
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    helpers.cleanup_repo(repo)
    config.setup(original_config)
  end)

  it("keeps the cursor fold closed when staging and unstaging with the panel action", function()
    view = lib.diffview_open({})
    assert.is_not_nil(view)
    view:open()

    local function wait_for_kind(kind)
      assert.is_true(vim.wait(10000, function()
        local pending = view:set_file_in_flight()
        return view.initialized
          and view.cur_entry
          and view.cur_entry.kind == kind
          and view.cur_entry.opened
          and view.cur_layout:is_files_loaded()
          and (not pending or pending:is_done())
      end), "diff did not finish opening " .. kind .. " entry")
    end

    wait_for_kind("working")
    for _, kind in ipairs({ "staged", "working" }) do
      local main = view.cur_layout:get_main_win().id
      api.nvim_win_call(main, function()
        api.nvim_win_set_cursor(main, { 10, 0 })
        vim.cmd("normal! zM")
        assert.is_true(vim.fn.foldclosed(10) ~= -1)
      end)
      view.panel:highlight_cur_file()
      api.nvim_set_current_win(view.panel.winid)
      api.nvim_win_call(main, function()
        assert.is_true(vim.fn.foldclosed(api.nvim_win_get_cursor(main)[1]) ~= -1, "fold before staging")
      end)

      -- This is the action bound to `s` in the file panel.
      view.emitter:emit("toggle_stage_entry")
      wait_for_kind(kind)

      main = view.cur_layout:get_main_win().id
      api.nvim_win_call(main, function()
        assert.is_true(vim.fn.foldclosed(api.nvim_win_get_cursor(main)[1]) ~= -1)
      end)
      assert.is_true(view.panel:is_focused())
    end
  end)
end)

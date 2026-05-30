local augroup  = vim.api.nvim_create_augroup
local autocmd  = vim.api.nvim_create_autocmd

-- Highlight yank
autocmd("TextYankPost", {
  group    = augroup("hl-yank", { clear = true }),
  callback = function() vim.highlight.on_yank() end,
})

-- Auto-resize splits on window resize
autocmd("VimResized", {
  group   = augroup("resize-splits", { clear = true }),
  command = "tabdo wincmd =",
})

-- Terminal: no line numbers
autocmd("TermOpen", {
  group    = augroup("term-opts", { clear = true }),
  callback = function()
    vim.opt_local.number         = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn     = "no"
    vim.cmd("startinsert")
  end,
})

-- Close some filetypes with just <q>
autocmd("FileType", {
  group   = augroup("close-with-q", { clear = true }),
  pattern = { "help", "man", "qf", "notify", "checkhealth", "startuptime", "lspinfo", "oil" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Restore cursor position
autocmd("BufReadPost", {
  group    = augroup("restore-cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-create parent directories when saving
autocmd("BufWritePre", {
  group    = augroup("auto-create-dir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+://") then return end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Filetype overrides
vim.filetype.add({
  pattern = {
    [".*/templates/.*%.ya?ml"] = "helm",
    ["%.env%..*"]              = "sh",
    ["Makefile.*"]             = "make",
  },
  filename = {
    [".envrc"] = "sh",
  },
})

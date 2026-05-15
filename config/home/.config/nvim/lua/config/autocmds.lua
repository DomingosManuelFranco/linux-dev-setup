local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

autocmd("TextYankPost", {
  group = augroup("devsetup-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

autocmd("VimResized", {
  group = augroup("devsetup-resize-splits", { clear = true }),
  command = "tabdo wincmd =",
})

autocmd("TermOpen", {
  group = augroup("devsetup-terminal-ui", { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
  end,
})

vim.filetype.add({
  pattern = {
    [".*/templates/.*%.ya?ml"] = "helm",
  },
})

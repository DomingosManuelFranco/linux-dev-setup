local map = vim.keymap.set

-- ── Better defaults ────────────────────────────────────────────────────────
map("n", "<Esc>",    "<cmd>nohlsearch<cr>",  { desc = "Clear search highlight" })
map("i", "jk",       "<Esc>",               { desc = "Exit insert mode" })
map("n", "x",        '"_x',                 { desc = "Delete without yank" })

-- ── File / Session ──────────────────────────────────────────────────────────
map("n", "<leader>w",  "<cmd>w<cr>",          { desc = "Save buffer" })
map("n", "<leader>W",  "<cmd>wa<cr>",         { desc = "Save all buffers" })
map("n", "<leader>q",  "<cmd>q<cr>",          { desc = "Quit window" })
map("n", "<leader>Q",  "<cmd>qa!<cr>",        { desc = "Quit all (force)" })

-- ── Buffers ──────────────────────────────────────────────────────────────────
map("n", "<leader>bd", "<cmd>bdelete<cr>",           { desc = "Delete buffer" })
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<cr>",        { desc = "Only current buffer" })
map("n", "<S-h>",      "<cmd>bprevious<cr>",         { desc = "Prev buffer" })
map("n", "<S-l>",      "<cmd>bnext<cr>",             { desc = "Next buffer" })

-- ── Windows ───────────────────────────────────────────────────────────────────
map("n", "<leader>sv", "<cmd>vsplit<cr>",    { desc = "Split vertical" })
map("n", "<leader>sh", "<cmd>split<cr>",    { desc = "Split horizontal" })
map("n", "<leader>se", "<C-w>=",            { desc = "Equal split sizes" })
map("n", "<leader>sc", "<cmd>close<cr>",    { desc = "Close split" })
-- Navigate (overridden by vim-tmux-navigator in tmux.lua)
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
-- Resize
map("n", "<C-Up>",    "<cmd>resize +2<cr>",           { desc = "Increase height" })
map("n", "<C-Down>",  "<cmd>resize -2<cr>",           { desc = "Decrease height" })
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>",  { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>",  { desc = "Increase width" })

-- ── Tabs ───────────────────────────────────────────────────────────────────────
map("n", "<leader><tab>n", "<cmd>tabnew<cr>",     { desc = "New tab" })
map("n", "<leader><tab>c", "<cmd>tabclose<cr>",   { desc = "Close tab" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>",    { desc = "Next tab" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>",{ desc = "Prev tab" })

-- ── Movement ────────────────────────────────────────────────────────────────
-- Keep cursor centred when scrolling
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up" })
map("n", "n",     "nzzzv",   { desc = "Next search result" })
map("n", "N",     "Nzzzv",   { desc = "Prev search result" })

-- ── Indenting ────────────────────────────────────────────────────────────────
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- ── Move lines ───────────────────────────────────────────────────────────────
map("n", "<A-j>", "<cmd>m .+1<cr>==",        { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==",        { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv",       { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv",       { desc = "Move selection up" })

-- ── Terminal ─────────────────────────────────────────────────────────────────
map("n", "<leader>tt", function()
  vim.cmd("split | terminal")
  vim.cmd("resize 12")
end, { desc = "Terminal (horizontal split)" })

map("n", "<leader>tv", function()
  vim.cmd("vsplit | terminal")
end, { desc = "Terminal (vertical split)" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- ── Git ───────────────────────────────────────────────────────────────────────
map("n", "<leader>gg", function()
  vim.cmd("tabnew | terminal lazygit")
end, { desc = "Lazygit" })

-- ── Diagnostics ──────────────────────────────────────────────────────────────
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })

local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Mouse & clipboard
opt.mouse = "a"
opt.clipboard = "unnamedplus"

-- Appearance
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.wrap = false
opt.linebreak = true
opt.showmode = false
opt.laststatus = 3       -- global statusline
opt.cmdheight = 1
opt.pumheight = 10       -- max completion items
opt.fillchars = {
  foldopen  = "v",
  foldclose = ">",
  foldsep   = " ",
  diff      = "-",
  eob       = " ",
}

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Search
opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

-- Performance
opt.updatetime  = 200
opt.timeoutlen  = 300
opt.redrawtime  = 1500

-- Scrolling
opt.scrolloff     = 8
opt.sidescrolloff = 8

-- Editing
opt.expandtab   = true
opt.shiftwidth  = 2
opt.tabstop     = 2
opt.softtabstop = 2
opt.smartindent = true
opt.confirm     = true
opt.undofile    = true
opt.undolevels  = 10000
opt.autowrite   = true

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }

-- Folding (use treesitter when available)
opt.foldmethod = "expr"
opt.foldexpr   = "nvim_treesitter#foldexpr()"
opt.foldenable = false   -- open all folds by default

-- Spell
opt.spelllang = { "en_us" }

-- Misc
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg    = "rg --vimgrep"
opt.formatoptions = "jcroqlnt"
opt.conceallevel = 0
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

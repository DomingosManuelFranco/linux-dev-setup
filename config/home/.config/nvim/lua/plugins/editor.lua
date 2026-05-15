return {
  -- ── Treesitter ───────────────────────────────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash", "c", "css", "dockerfile", "fish",
          "git_config", "gitcommit", "gitignore",
          "go", "gomod", "gosum",
          "html", "javascript", "jsdoc",
          "json", "jsonc", "lua", "luadoc",
          "markdown", "markdown_inline",
          "nginx", "python", "query", "regex",
          "rust", "sql", "terraform", "toml",
          "tsx", "typescript", "vim", "vimdoc",
          "xml", "yaml",
        },
        auto_install = true,
        highlight    = { enable = true, additional_vim_regex_highlighting = false },
        indent       = { enable = true },
        incremental_selection = {
          enable  = true,
          keymaps = {
            init_selection    = "<C-space>",
            node_incremental  = "<C-space>",
            scope_incremental = false,
            node_decremental  = "<bs>",
          },
        },
        textobjects = {
          select = {
            enable    = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
              ["aa"] = "@parameter.outer",
              ["ia"] = "@parameter.inner",
            },
          },
          move = {
            enable              = true,
            set_jumps           = true,
            goto_next_start     = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
            goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
          },
        },
      })
    end,
  },

  -- ── Fuzzy finder: fzf-lua ────────────────────────────────────────────────
  {
    "ibhagwan/fzf-lua",
    cmd          = "FzfLua",
    dependencies = "nvim-tree/nvim-web-devicons",
    keys = {
      { "<leader>ff",  function() require("fzf-lua").files()           end, desc = "Find files" },
      { "<leader>fg",  function() require("fzf-lua").live_grep()       end, desc = "Live grep" },
      { "<leader>fb",  function() require("fzf-lua").buffers()         end, desc = "Buffers" },
      { "<leader>fr",  function() require("fzf-lua").oldfiles()        end, desc = "Recent files" },
      { "<leader>fh",  function() require("fzf-lua").help_tags()       end, desc = "Help tags" },
      { "<leader>fk",  function() require("fzf-lua").keymaps()         end, desc = "Keymaps" },
      { "<leader>fs",  function() require("fzf-lua").lsp_document_symbols() end, desc = "Document symbols" },
      { "<leader>fS",  function() require("fzf-lua").lsp_workspace_symbols() end, desc = "Workspace symbols" },
      { "<leader>fc",  function() require("fzf-lua").files({ cwd = vim.fn.stdpath("config") }) end, desc = "Config files" },
      { "<leader>f/",  function() require("fzf-lua").blines()          end, desc = "Buffer lines" },
      { "<leader>/",   function() require("fzf-lua").grep_curbuf()     end, desc = "Search buffer" },
      { "<leader>:",   function() require("fzf-lua").command_history()  end, desc = "Command history" },
      { "gr",          function() require("fzf-lua").lsp_references()  end, desc = "LSP references" },
    },
    opts = {
      "telescope",
      winopts = {
        backdrop = 95,
        border   = "rounded",
        height   = 0.90,
        width    = 0.88,
        preview  = {
          border   = "rounded",
          layout   = "vertical",
          vertical = "up:65%",
        },
      },
      files = {
        cwd_prompt = false,
        fd_opts    = "--color=never --type f --hidden --follow --exclude .git --exclude node_modules",
      },
      grep = {
        rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob '!.git'",
      },
      fzf_opts = { ["--layout"] = "reverse" },
    },
  },

  -- ── File explorer: oil.nvim ──────────────────────────────────────────────
  {
    "stevearc/oil.nvim",
    cmd          = "Oil",
    dependencies = "nvim-tree/nvim-web-devicons",
    keys = {
      { "-",         "<cmd>Oil<cr>",        desc = "Open parent directory" },
      { "<leader>e", "<cmd>Oil<cr>",        desc = "Explorer (Oil)" },
      { "<leader>E", "<cmd>Oil .<cr>",      desc = "Explorer root (Oil)" },
    },
    opts = {
      default_file_explorer = true,
      columns               = { "icon", "permissions", "size", "mtime" },
      view_options          = { show_hidden = true },
      win_options           = { signcolumn = "yes:2" },
      float = {
        padding    = 2,
        max_width  = 90,
        max_height = 0,
        border     = "rounded",
      },
      keymaps = {
        ["g?"]    = "actions.show_help",
        ["<CR>"]  = "actions.select",
        ["<C-v>"] = "actions.select_vsplit",
        ["<C-s>"] = "actions.select_split",
        ["<C-t>"] = "actions.select_tab",
        ["-"]     = "actions.parent",
        ["_"]     = "actions.open_cwd",
        ["`"]     = "actions.cd",
        ["~"]     = "actions.tcd",
        ["gs"]    = "actions.change_sort",
        ["gx"]    = "actions.open_external",
        ["g."]    = "actions.toggle_hidden",
      },
    },
  },

  -- ── Git: gitsigns ────────────────────────────────────────────────────────
  {
    "lewis6991/gitsigns.nvim",
    event        = { "BufReadPre", "BufNewFile" },
    dependencies = "nvim-lua/plenary.nvim",
    opts = {
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
        untracked    = { text = "▎" },
      },
      current_line_blame = true,
      current_line_blame_opts = { delay = 300 },
      on_attach = function(buffer)
        local gs  = package.loaded.gitsigns
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end
        map("n", "]h", gs.next_hunk,                 "Next hunk")
        map("n", "[h", gs.prev_hunk,                 "Prev hunk")
        map("n", "<leader>hs", gs.stage_hunk,        "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk,        "Reset hunk")
        map("n", "<leader>hS", gs.stage_buffer,      "Stage buffer")
        map("n", "<leader>hu", gs.undo_stage_hunk,   "Undo stage hunk")
        map("n", "<leader>hp", gs.preview_hunk,      "Preview hunk")
        map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>hd", gs.diffthis,          "Diff this")
        map("n", "<leader>hD", function() gs.diffthis("~") end, "Diff this ~")
        map({ "o","x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
      end,
    },
  },

  -- ── Git: lazygit (already mapped via terminal in keymaps.lua)
  -- Better diff viewer
  {
    "sindrets/diffview.nvim",
    cmd  = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    opts = {},
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>",           desc = "Diff view" },
      { "<leader>gD", "<cmd>DiffviewFileHistory %<cr>",  desc = "File history" },
      { "<leader>gx", "<cmd>DiffviewClose<cr>",          desc = "Close diff view" },
    },
  },

  -- ── Editing helpers ──────────────────────────────────────────────────────
  { "numToStr/Comment.nvim",   event = "VeryLazy", opts = {} },
  { "kylechui/nvim-surround",  event = "VeryLazy", opts = {} },
  { "windwp/nvim-autopairs",   event = "InsertEnter",
    opts = { check_ts = true, ts_config = {} } },

  -- ── Flash: fast navigation ────────────────────────────────────────────────
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts  = {},
    keys  = {
      { "s",     mode = { "n","x","o" }, function() require("flash").jump()        end, desc = "Flash" },
      { "S",     mode = { "n","x","o" }, function() require("flash").treesitter()  end, desc = "Flash Treesitter" },
      { "r",     mode = "o",             function() require("flash").remote()       end, desc = "Remote Flash" },
      { "R",     mode = { "o","x" },     function() require("flash").treesitter_search() end, desc = "Flash TS search" },
      { "<c-s>", mode = "c",             function() require("flash").toggle()       end, desc = "Toggle Flash search" },
    },
  },

  -- ── Mini.pairs / splitjoin / etc ─────────────────────────────────────────
  {
    "echasnovski/mini.splitjoin",
    version = false,
    keys    = {
      { "gS", desc = "Split/join" },
    },
    opts = { mappings = { toggle = "gS" } },
  },

  -- ── Session management ────────────────────────────────────────────────────
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts  = { options = vim.opt.sessionoptions:get() },
    keys  = {
      { "<leader>qs", function() require("persistence").load()                end, desc = "Restore session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop()                end, desc = "Don't save session" },
    },
  },

  -- ── Multi-cursor ──────────────────────────────────────────────────────────
  {
    "mg979/vim-visual-multi",
    event = "VeryLazy",
  },

  -- ── Helm ─────────────────────────────────────────────────────────────────
  { "towolf/vim-helm", ft = "helm" },

  -- ── Markdown preview ─────────────────────────────────────────────────────
  {
    "iamcco/markdown-preview.nvim",
    cmd    = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft     = { "markdown" },
    build  = function() vim.fn["mkdp#util#install"]() end,
    keys   = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown preview" },
    },
  },

  -- ── Render markdown in buffer ─────────────────────────────────────────────
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft           = { "markdown", "norg", "rmd", "org" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      heading  = { enabled = true },
      checkbox = { enabled = true },
      code     = { sign = false, width = "block", right_pad = 1 },
    },
  },
}

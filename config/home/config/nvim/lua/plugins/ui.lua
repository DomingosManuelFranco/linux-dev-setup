return {
  -- ── Colorscheme: Catppuccin ──────────────────────────────────────────────
  {
    "catppuccin/nvim",
    name     = "catppuccin",
    lazy     = false,
    priority = 1000,
    opts = {
      flavour              = "mocha",
      background           = { light = "latte", dark = "mocha" },
      transparent_background = true,
      show_end_of_buffer   = false,
      term_colors          = true,
      dim_inactive = {
        enabled    = true,
        shade      = "dark",
        percentage = 0.15,
      },
      integrations = {
        blink_cmp       = true,
        cmp             = true,
        gitsigns        = true,
        indent_blankline = { enabled = true },
        lsp_trouble     = true,
        mason           = true,
        mini            = { enabled = true },
        native_lsp = {
          enabled           = true,
          virtual_text = {
            errors      = { "italic" },
            hints       = { "italic" },
            warnings    = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors      = { "underline" },
            hints       = { "underline" },
            warnings    = { "underline" },
            information = { "underline" },
          },
        },
        treesitter       = true,
        which_key        = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- ── Icons ────────────────────────────────────────────────────────────────
  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "nvim-lua/plenary.nvim",       lazy = true },

  -- ── Bufferline ───────────────────────────────────────────────────────────
  {
    "akinsho/bufferline.nvim",
    event        = "VeryLazy",
    dependencies = "nvim-tree/nvim-web-devicons",
    keys = {
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
      { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Toggle pin" },
      { "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<cr>", desc = "Close unpinned" },
    },
    opts = {
      options = {
        mode             = "buffers",
        separator_style  = "slant",
        show_buffer_close_icons = true,
        show_close_icon  = false,
        color_icons      = true,
        always_show_bufferline = false,
        diagnostics      = "nvim_lsp",
        diagnostics_indicator = function(_, _, diag)
          local icons = { error = " ", warning = " ", info = " " }
          local ret   = (diag.error and icons.error .. diag.error .. " " or "")
                      .. (diag.warning and icons.warning .. diag.warning or "")
          return vim.trim(ret)
        end,
        offsets = {
          { filetype = "neo-tree", text = "File Explorer", highlight = "Directory", text_align = "left" },
        },
      },
    },
    config = function(_, opts)
      require("bufferline").setup(opts)
    end,
  },

  -- ── Statusline: lualine ──────────────────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    event        = "VeryLazy",
    dependencies = "nvim-tree/nvim-web-devicons",
    opts = function()
      local lazy_status = require("lazy.status")

      local function tmux_status()
        local session = vim.fn.system("tmux display-message -p '#S' 2>/dev/null"):gsub("\n", "")
        if session ~= "" then return "  " .. session end
        return ""
      end

      return {
        options = {
          theme                = "catppuccin",
          globalstatus         = true,
          disabled_filetypes   = { statusline = { "dashboard", "alpha", "starter" } },
          component_separators = { left = "", right = "" },
          section_separators   = { left = "", right = "" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = {
            "branch",
            { "diff", symbols = { added = " ", modified = " ", removed = " " } },
          },
          lualine_c = {
            { "filename", path = 1, symbols = { modified = "  ", readonly = "", unnamed = "" } },
          },
          lualine_x = {
            {
              lazy_status.updates,
              cond  = lazy_status.has_updates,
              color = { fg = "#f38ba8" },
            },
            { "diagnostics", symbols = { error = " ", warn = " ", info = " ", hint = "󰝶 " } },
            "encoding",
            "fileformat",
            "filetype",
          },
          lualine_y = { "progress" },
          lualine_z = { "location", { tmux_status } },
        },
        extensions = { "lazy", "mason", "oil", "trouble" },
      }
    end,
  },

  -- ── Dashboard: alpha ─────────────────────────────────────────────────────
  {
    "goolord/alpha-nvim",
    event        = "VimEnter",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      local alpha    = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        "                                                     ",
        "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
        "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
        "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
        "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
        "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
        "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
        "                                                     ",
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file",       "<cmd>FzfLua files<cr>"),
        dashboard.button("n", "  New file",        "<cmd>enew<cr>"),
        dashboard.button("r", "  Recent files",   "<cmd>FzfLua oldfiles<cr>"),
        dashboard.button("g", "  Live grep",      "<cmd>FzfLua live_grep<cr>"),
        dashboard.button("s", "  Sessions",       "<cmd>SessionRestore<cr>"),
        dashboard.button("l", "󰒲  Lazy",           "<cmd>Lazy<cr>"),
        dashboard.button("q", "  Quit",           "<cmd>qa<cr>"),
      }

      dashboard.section.footer.val = "The best editor is the one you use."

      dashboard.opts.opts.noautocmd = true
      alpha.setup(dashboard.opts)

      vim.api.nvim_create_autocmd("User", {
        pattern  = "LazyVimStarted",
        callback = function()
          local stats = require("lazy").stats()
          local ms    = (math.floor(stats.startuptime * 100 + 0.5) / 100)
          dashboard.section.footer.val =
            "⚡ Loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms"
          pcall(vim.cmd.AlphaRedraw)
        end,
      })
    end,
  },

  -- ── Indent guides ─────────────────────────────────────────────────────────
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main  = "ibl",
    opts  = {
      indent = { char = "│", tab_char = "│" },
      scope  = { enabled = false },
      exclude = {
        filetypes = {
          "help", "alpha", "dashboard", "lazy", "mason",
          "notify", "toggleterm", "lazyterm",
        },
      },
    },
  },

  -- ── Active indent scope highlight ────────────────────────────────────────
  {
    "echasnovski/mini.indentscope",
    event   = { "BufReadPost", "BufNewFile" },
    version = false,
    init    = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "help", "alpha", "dashboard", "lazy", "mason", "notify" },
        callback = function() vim.b.miniindentscope_disable = true end,
      })
    end,
    opts = {
      symbol  = "│",
      options = { try_as_border = true },
    },
  },

  -- ── Notify ───────────────────────────────────────────────────────────────
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    opts  = {
      timeout          = 3000,
      background_colour = "#000000",
      max_height = function() return math.floor(vim.o.lines * 0.75) end,
      max_width  = function() return math.floor(vim.o.columns * 0.75) end,
      on_open    = function(win) vim.api.nvim_win_set_config(win, { zindex = 100 }) end,
    },
    config = function(_, opts)
      require("notify").setup(opts)
      vim.notify = require("notify")
    end,
  },

  -- ── Which-key ────────────────────────────────────────────────────────────
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts  = {
      preset = "modern",
      spec = {
        { "<leader>b",     group = "Buffers" },
        { "<leader>c",     group = "Code" },
        { "<leader>f",     group = "Find" },
        { "<leader>g",     group = "Git" },
        { "<leader>h",     group = "Git Hunks" },
        { "<leader>s",     group = "Split" },
        { "<leader>t",     group = "Terminal" },
        { "<leader>x",     group = "Diagnostics" },
        { "<leader><tab>", group = "Tabs" },
      },
    },
  },

  -- ── Trouble ──────────────────────────────────────────────────────────────
  {
    "folke/trouble.nvim",
    cmd  = "Trouble",
    opts = { use_diagnostic_signs = true },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",                       desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",          desc = "Buffer Diagnostics" },
      { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>",               desc = "Symbols (Trouble)" },
      { "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",desc = "LSP (Trouble)" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>",                            desc = "Quickfix (Trouble)" },
    },
  },

  -- ── Todo-comments ────────────────────────────────────────────────────────
  {
    "folke/todo-comments.nvim",
    event        = "VeryLazy",
    dependencies = "nvim-lua/plenary.nvim",
    opts         = {},
    keys = {
      { "]t",        function() require("todo-comments").jump_next() end, desc = "Next todo" },
      { "[t",        function() require("todo-comments").jump_prev() end, desc = "Prev todo" },
      { "<leader>ft", "<cmd>TodoTrouble<cr>",                             desc = "Todos (Trouble)" },
    },
  },

}

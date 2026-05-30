return {
  -- ── Tmux navigator (C-h/j/k/l across panes) ─────────────────────────────
  {
    "christoomey/vim-tmux-navigator",
    lazy  = false,
    keys  = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Pane left" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Pane down" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Pane up" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Pane right" },
    },
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
      vim.g.tmux_navigator_save_on_switch = 2
      vim.g.tmux_navigator_disable_when_zoomed = 1
    end,
  },

  -- ── Tmux resizer ──────────────────────────────────────────────────────────
  {
    "RyanMillerC/better-vim-tmux-resizer",
    event = "VeryLazy",
    init  = function()
      vim.g.tmux_resizer_no_mappings = 1
    end,
    keys = {
      { "<M-h>", "<cmd>TmuxResizeLeft<cr>",  desc = "Resize pane left" },
      { "<M-j>", "<cmd>TmuxResizeDown<cr>",  desc = "Resize pane down" },
      { "<M-k>", "<cmd>TmuxResizeUp<cr>",    desc = "Resize pane up" },
      { "<M-l>", "<cmd>TmuxResizeRight<cr>", desc = "Resize pane right" },
    },
  },
}

return {
  -- ── Completion: blink.cmp ─────────────────────────────────────────────────
  {
    "saghen/blink.cmp",
    event        = "InsertEnter",
    version      = "*",
    opts = {
      appearance = {
        nerd_font_variant = "mono",
        use_nvim_cmp_as_default = false,
      },
      completion = {
        accept     = { auto_brackets = { enabled = true } },
        documentation = {
          auto_show        = true,
          auto_show_delay_ms = 200,
          window           = { border = "rounded" },
        },
        ghost_text = { enabled = true },
        menu = {
          border = "rounded",
          draw   = {
            treesitter = { "lsp" },
            columns    = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
          },
        },
      },
      keymap = {
        preset     = "enter",
        ["<C-space>"]  = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"]      = { "hide" },
        ["<Tab>"]      = { "select_next", "fallback" },
        ["<S-Tab>"]    = { "select_prev", "fallback" },
      },
      signature = {
        enabled = true,
        window  = { border = "rounded" },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
    },
  },

  -- ── Lua dev ───────────────────────────────────────────────────────────────
  {
    "folke/lazydev.nvim",
    ft   = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },

  -- ── Formatting: conform ───────────────────────────────────────────────────
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd   = { "ConformInfo" },
    keys  = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        desc = "Format buffer",
      },
    },
    opts = {
      notify_on_error = true,
      format_on_save  = function(bufnr)
        local slow_ft = { terraform = true, ["terraform-vars"] = true }
        return {
          timeout_ms = slow_ft[vim.bo[bufnr].filetype] and 1500 or 800,
          lsp_format = "fallback",
        }
      end,
      formatters_by_ft = {
        lua              = { "stylua" },
        sh               = { "shfmt" },
        bash             = { "shfmt" },
        zsh              = { "shfmt" },
        fish             = { "fish_indent" },
        javascript       = { "prettierd", "prettier", stop_after_first = true },
        typescript       = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact  = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact  = { "prettierd", "prettier", stop_after_first = true },
        vue              = { "prettierd", "prettier", stop_after_first = true },
        css              = { "prettierd", "prettier", stop_after_first = true },
        html             = { "prettierd", "prettier", stop_after_first = true },
        json             = { "prettierd", "prettier", stop_after_first = true },
        jsonc            = { "prettierd", "prettier", stop_after_first = true },
        yaml             = { "yamlfmt" },
        markdown         = { "prettierd", "prettier", stop_after_first = true },
        python           = { "ruff_format" },
        go               = { "goimports", "gofmt" },
        rust             = { "rustfmt" },
        terraform        = { "terraform_fmt" },
        ["terraform-vars"] = { "terraform_fmt" },
        nginx            = { "nginxfmt" },
        sql              = { "sql_formatter" },
      },
    },
  },

  -- ── Linting: nvim-lint ────────────────────────────────────────────────────
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        bash             = { "shellcheck" },
        sh               = { "shellcheck" },
        zsh              = { "shellcheck" },
        dockerfile       = { "hadolint" },
        python           = { "ruff" },
        javascript       = { "eslint_d" },
        typescript       = { "eslint_d" },
        javascriptreact  = { "eslint_d" },
        typescriptreact  = { "eslint_d" },
        terraform        = { "tflint" },
        ["terraform-vars"] = { "tflint" },
        yaml             = { "yamllint" },
        markdown         = { "markdownlint" },
      }

      local group = vim.api.nvim_create_augroup("nvim-lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group    = group,
        callback = function() lint.try_lint() end,
      })
    end,
  },

  -- ── LSP ───────────────────────────────────────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    event        = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "saghen/blink.cmp",
      "folke/lazydev.nvim",
      "b0o/SchemaStore.nvim",
      { "mason-org/mason.nvim", opts = { ui = { border = "rounded" } } },
      { "williamboman/mason-lspconfig.nvim" },
    },
    config = function()
      -- Diagnostics UI
      vim.diagnostic.config({
        severity_sort = true,
        underline     = true,
        update_in_insert = false,
        float = {
          border  = "rounded",
          source  = "always",
        },
        virtual_text = {
          spacing = 4,
          source  = "if_many",
          prefix  = "●",
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.HINT]  = " ",
            [vim.diagnostic.severity.INFO]  = " ",
          },
        },
      })

      -- Capabilities (blink.cmp)
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- On-attach keymaps
      vim.api.nvim_create_autocmd("LspAttach", {
        group    = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end

          map("gd",          function() require("fzf-lua").lsp_definitions()     end, "Goto definition")
          map("gD",          vim.lsp.buf.declaration,                              "Goto declaration")
          map("gr",          function() require("fzf-lua").lsp_references()       end, "Goto references")
          map("gI",          function() require("fzf-lua").lsp_implementations()  end, "Goto implementation")
          map("gy",          function() require("fzf-lua").lsp_typedefs()         end, "Goto type definition")
          map("K",           vim.lsp.buf.hover,                                    "Hover")
          map("<C-k>",       vim.lsp.buf.signature_help,                           "Signature help")
          map("<leader>ca",  vim.lsp.buf.code_action,                              "Code action")
          map("<leader>cr",  vim.lsp.buf.rename,                                   "Rename symbol")

          -- Highlight symbol under cursor
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.supports_method("textDocument/documentHighlight") then
            local hlgroup = vim.api.nvim_create_augroup("lsp-highlight-" .. event.buf, { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer   = event.buf,
              group    = hlgroup,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer   = event.buf,
              group    = hlgroup,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })

      -- Servers
      local schemastore = require("schemastore")
      local servers = {
        -- Web
        ts_ls             = {},
        cssls             = {},
        html              = {},
        emmet_ls          = {
          filetypes = { "html", "css", "scss", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
        },
        volar             = {},   -- Vue
        tailwindcss       = {},

        -- DevOps / Infra
        ansiblels         = {},
        bashls            = {},
        docker_compose_language_service = {},
        dockerls          = {},
        helm_ls           = {},
        nginx_language_server = {},
        terraformls       = {},

        -- Data / Config
        jsonls = {
          settings = {
            json = { schemas = schemastore.json.schemas(), validate = { enable = true } },
          },
        },
        yamlls = {
          settings = {
            yaml = {
              keyOrdering = false,
              schemaStore = { enable = false, url = "" },
              schemas      = schemastore.yaml.schemas(),
            },
          },
        },
        taplo = {},   -- TOML

        -- Languages
        gopls = {
          settings = {
            gopls = {
              analyses    = { unusedparams = true },
              staticcheck = true,
              gofumpt     = true,
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              completion = { callSnippet = "Replace" },
              diagnostics = { disable = { "missing-fields" } },
              workspace   = { checkThirdParty = false },
            },
          },
        },
        marksman  = {},
        pyright   = {
          settings = {
            python = {
              analysis = { typeCheckingMode = "standard" },
            },
          },
        },
        ruff      = {},
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              checkOnSave = { command = "clippy" },
            },
          },
        },
      }

      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed  = vim.tbl_keys(servers),
        automatic_installation = true,
      })

      for server, config in pairs(servers) do
        config.capabilities = vim.tbl_deep_extend("force", {}, capabilities, config.capabilities or {})
        vim.lsp.config(server, config)
        vim.lsp.enable(server)
      end
    end,
  },

  -- ── Mason tool installer ──────────────────────────────────────────────────
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event        = "VeryLazy",
    dependencies = "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- Formatters
        "prettierd", "prettier", "stylua", "shfmt",
        "goimports", "gofumpt", "ruff-lsp",
        "yamlfmt", "sql-formatter",
        -- Linters
        "shellcheck", "hadolint", "eslint_d",
        "tflint", "yamllint", "markdownlint",
        -- DAP (debug)
        "delve",
      },
    },
  },
}

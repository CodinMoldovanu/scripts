#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Kali Linux terminal/dev rice
#
# Installs/configures:
#   - Neovim
#   - Lazy.nvim
#   - Telescope
#   - Treesitter
#   - LSP + Mason
#   - nvim-cmp
#   - Catppuccin
#   - Lualine
#   - Neo-tree
#   - Gitsigns
#   - Autopairs
#   - Which-key
#   - tmux
#   - fzf
#   - ripgrep
#   - fd
#   - bat
#   - eza/exa where available
#   - btop
#   - zoxide
#   - useful ZSH config
#
# Existing configs are backed up.
# ============================================================

# ---------------------------
# Colours
# ---------------------------

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

info() {
    echo -e "${BLUE}${BOLD}==>${RESET} $*"
}

success() {
    echo -e "${GREEN}${BOLD}==>${RESET} $*"
}

warn() {
    echo -e "${YELLOW}${BOLD}==>${RESET} $*"
}

# ---------------------------
# Don't run as root
# ---------------------------

if [[ "${EUID}" -eq 0 ]]; then
    echo "Don't run this as root."
    echo "Run it as your normal Kali user; sudo will be used when needed."
    exit 1
fi

# ---------------------------
# Backup
# ---------------------------

BACKUP_DIR="$HOME/.rice-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

backup() {
    local target="$1"

    if [[ -e "$target" || -L "$target" ]]; then
        warn "Backing up $target"
        cp -a "$target" "$BACKUP_DIR/"
    fi
}

info "Backups will go to:"
echo "    $BACKUP_DIR"

# ---------------------------
# Packages
# ---------------------------

info "Updating apt metadata..."
sudo apt update

PACKAGES=(
    neovim
    git
    curl
    wget
    unzip
    build-essential
    gcc
    make
    python3
    python3-pip
    python3-venv
    nodejs
    npm
    ripgrep
    fzf
    tmux
    btop
    zoxide
    jq
    tree
    shellcheck
    xclip
    wl-clipboard
)

info "Installing base packages..."
sudo apt install -y "${PACKAGES[@]}"

# Debian/Kali calls these packages slightly differently depending
# on release/package availability.

if apt-cache show fd-find >/dev/null 2>&1; then
    sudo apt install -y fd-find
fi

if apt-cache show bat >/dev/null 2>&1; then
    sudo apt install -y bat
fi

if apt-cache show eza >/dev/null 2>&1; then
    sudo apt install -y eza
elif apt-cache show exa >/dev/null 2>&1; then
    sudo apt install -y exa
fi

# ---------------------------
# ~/.local/bin compatibility
# ---------------------------

mkdir -p "$HOME/.local/bin"

# Debian calls fd "fdfind".
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# Debian sometimes calls bat "batcat".
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

# ---------------------------
# ZSH
# ---------------------------

info "Configuring ZSH..."

backup "$HOME/.zshrc"

mkdir -p "$HOME/.config/zsh"

# Install zsh plugins into ~/.local/share
ZSH_PLUGIN_DIR="$HOME/.local/share/zsh-plugins"
mkdir -p "$ZSH_PLUGIN_DIR"

clone_or_update() {
    local repo="$1"
    local dest="$2"

    if [[ -d "$dest/.git" ]]; then
        git -C "$dest" pull --ff-only || true
    else
        git clone --depth=1 "$repo" "$dest"
    fi
}

clone_or_update \
    https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_PLUGIN_DIR/zsh-autosuggestions"

clone_or_update \
    https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting"

cat > "$HOME/.zshrc" <<'EOF'
# ============================================================
# Kali ZSH rice
# ============================================================

export PATH="$HOME/.local/bin:$PATH"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS

# Completion
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ------------------------------------------------------------
# Colours / prompt
# ------------------------------------------------------------

autoload -U colors && colors

setopt PROMPT_SUBST

_git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
    echo " %F{magenta}git:(%F{red}${branch}%F{magenta})%f"
}

PROMPT='%F{cyan}%n%f@%F{blue}%m%f %F{green}%~%f$(_git_branch)
%F{yellow}❯%f '

# ------------------------------------------------------------
# Aliases
# ------------------------------------------------------------

alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias grep='grep --color=auto'
alias mkdir='mkdir -pv'

alias v='nvim'
alias vim='nvim'
alias vi='nvim'

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --decorate --graph --all'
alias gd='git diff'
alias gb='git branch'

alias ports='ss -tulpn'
alias myip='curl -s https://ifconfig.me'

# Better ls if available
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -lah --icons=auto --group-directories-first --git'
    alias la='eza -a --icons=auto'
    alias tree='eza --tree --icons=auto'
elif command -v exa >/dev/null 2>&1; then
    alias ls='exa --group-directories-first'
    alias ll='exa -lah --group-directories-first --git'
    alias la='exa -a'
else
    alias ll='ls -lah'
    alias la='ls -A'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
fi

# ------------------------------------------------------------
# fzf
# ------------------------------------------------------------

if [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

if [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]; then
    source /usr/share/doc/fzf/examples/completion.zsh
fi

export FZF_DEFAULT_OPTS='
    --height 40%
    --layout=reverse
    --border
    --info=inline
'

# ------------------------------------------------------------
# zoxide
# ------------------------------------------------------------

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# ------------------------------------------------------------
# Plugins
# ------------------------------------------------------------

source "$HOME/.local/share/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Syntax highlighting should be sourced last.
source "$HOME/.local/share/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
EOF

# ---------------------------
# tmux
# ---------------------------

info "Configuring tmux..."

backup "$HOME/.tmux.conf"

cat > "$HOME/.tmux.conf" <<'EOF'
# True colour
set -g default-terminal "tmux-256color"
set-option -sa terminal-overrides ",xterm*:Tc"

# Mouse
set -g mouse on

# Start windows/panes at 1
set -g base-index 1
setw -g pane-base-index 1
set-option -g renumber-windows on

# Vi keys
setw -g mode-keys vi

# Faster escape
set -sg escape-time 10

# History
set -g history-limit 100000

# Reload
bind r source-file ~/.tmux.conf \; display-message "tmux config reloaded"

# Easier pane splitting
unbind '"'
unbind %

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Navigation
bind -r h select-pane -L
bind -r j select-pane -D
bind -r k select-pane -U
bind -r l select-pane -R

# Resize
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Status
set -g status-position bottom
set -g status-left-length 40
set -g status-right-length 80

set -g status-left " #[bold]#S "
set -g status-right " %Y-%m-%d %H:%M "

setw -g window-status-current-format " #[bold]#I:#W "
setw -g window-status-format " #I:#W "
EOF

# ---------------------------
# Neovim
# ---------------------------

info "Configuring Neovim..."

backup "$HOME/.config/nvim"

rm -rf "$HOME/.config/nvim"
mkdir -p "$HOME/.config/nvim/lua/config"

# ---------------------------
# init.lua
# ---------------------------

cat > "$HOME/.config/nvim/init.lua" <<'EOF'
require("config.options")
require("config.keymaps")
require("config.lazy")
EOF

# ---------------------------
# options.lua
# ---------------------------

cat > "$HOME/.config/nvim/lua/config/options.lua" <<'EOF'
local opt = vim.opt

opt.number = true
opt.relativenumber = true

opt.mouse = "a"

opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true

opt.wrap = false

opt.ignorecase = true
opt.smartcase = true

opt.termguicolors = true

opt.cursorline = true
opt.signcolumn = "yes"

opt.splitbelow = true
opt.splitright = true

opt.scrolloff = 8
opt.sidescrolloff = 8

opt.updatetime = 250
opt.timeoutlen = 400

opt.undofile = true

opt.clipboard = "unnamedplus"

opt.completeopt = {
    "menu",
    "menuone",
    "noselect",
}

vim.g.mapleader = " "
vim.g.maplocalleader = " "
EOF

# ---------------------------
# keymaps.lua
# ---------------------------

cat > "$HOME/.config/nvim/lua/config/keymaps.lua" <<'EOF'
local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

map("n", "<leader>e", "<cmd>Neotree toggle<cr>", {
    desc = "File explorer"
})

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", {
    desc = "Find files"
})

map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", {
    desc = "Live grep"
})

map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", {
    desc = "Buffers"
})

map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", {
    desc = "Help"
})

map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

map("n", "<Esc>", "<cmd>nohlsearch<cr>")
EOF

# ---------------------------
# lazy.lua
# ---------------------------

cat > "$HOME/.config/nvim/lua/config/lazy.lua" <<'EOF'
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({

    -- ========================================================
    -- Theme
    -- ========================================================

    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        config = function()
            require("catppuccin").setup({
                flavour = "mocha",
                transparent_background = true,
                integrations = {
                    treesitter = true,
                    telescope = true,
                    native_lsp = {
                        enabled = true,
                    },
                },
            })

            vim.cmd.colorscheme("catppuccin")
        end,
    },

    -- ========================================================
    -- Statusline
    -- ========================================================

    {
        "nvim-lualine/lualine.nvim",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            require("lualine").setup({
                options = {
                    theme = "catppuccin",
                    globalstatus = true,
                },
            })
        end,
    },

    -- ========================================================
    -- File explorer
    -- ========================================================

    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        config = function()
            require("neo-tree").setup({
                close_if_last_window = true,

                filesystem = {
                    follow_current_file = {
                        enabled = true,
                    },

                    filtered_items = {
                        hide_dotfiles = false,
                        hide_gitignored = false,
                    },
                },
            })
        end,
    },

    -- ========================================================
    -- Telescope
    -- ========================================================

    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        config = function()
            require("telescope").setup({
                defaults = {
                    layout_strategy = "horizontal",

                    layout_config = {
                        prompt_position = "top",
                    },

                    sorting_strategy = "ascending",
                },
            })
        end,
    },

    -- ========================================================
    -- Treesitter
    -- ========================================================

    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",

        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "bash",
                    "lua",
                    "vim",
                    "vimdoc",
                    "python",
                    "javascript",
                    "typescript",
                    "json",
                    "yaml",
                    "html",
                    "css",
                    "ruby",
                    "dockerfile",
                    "markdown",
                },

                highlight = {
                    enable = true,
                },

                indent = {
                    enable = true,
                },
            })
        end,
    },

    -- ========================================================
    -- Git signs
    -- ========================================================

    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require("gitsigns").setup()
        end,
    },

    -- ========================================================
    -- Autopairs
    -- ========================================================

    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",

        config = function()
            require("nvim-autopairs").setup({})
        end,
    },

    -- ========================================================
    -- Which Key
    -- ========================================================

    {
        "folke/which-key.nvim",
        event = "VeryLazy",

        config = function()
            require("which-key").setup()
        end,
    },

    -- ========================================================
    -- Mason
    -- ========================================================

    {
        "williamboman/mason.nvim",

        config = function()
            require("mason").setup()
        end,
    },

    {
        "williamboman/mason-lspconfig.nvim",

        dependencies = {
            "williamboman/mason.nvim",
            "neovim/nvim-lspconfig",
        },
    },

    -- ========================================================
    -- LSP
    -- ========================================================

    {
        "neovim/nvim-lspconfig",

        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
        },

        config = function()

            local capabilities =
                require("cmp_nvim_lsp").default_capabilities()

            local servers = {
                lua_ls = {},
                pyright = {},
                bashls = {},
            }

            for server, config in pairs(servers) do
                config.capabilities = capabilities

                vim.lsp.config(server, config)
                vim.lsp.enable(server)
            end

            vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
                desc = "Go to definition",
            })

            vim.keymap.set("n", "K", vim.lsp.buf.hover, {
                desc = "Hover documentation",
            })

            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {
                desc = "Rename",
            })

            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {
                desc = "Code action",
            })

            vim.keymap.set(
                "n",
                "<leader>d",
                vim.diagnostic.open_float,
                {
                    desc = "Diagnostics",
                }
            )
        end,
    },

    -- ========================================================
    -- Completion
    -- ========================================================

    {
        "hrsh7th/nvim-cmp",

        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
        },

        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")

            cmp.setup({

                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },

                mapping = cmp.mapping.preset.insert({

                    ["<C-Space>"] =
                        cmp.mapping.complete(),

                    ["<CR>"] =
                        cmp.mapping.confirm({
                            select = true,
                        }),

                    ["<Tab>"] =
                        cmp.mapping(function(fallback)

                            if cmp.visible() then
                                cmp.select_next_item()

                            elseif luasnip.expand_or_jumpable() then
                                luasnip.expand_or_jump()

                            else
                                fallback()
                            end

                        end, { "i", "s" }),

                    ["<S-Tab>"] =
                        cmp.mapping(function(fallback)

                            if cmp.visible() then
                                cmp.select_prev_item()

                            elseif luasnip.jumpable(-1) then
                                luasnip.jump(-1)

                            else
                                fallback()
                            end

                        end, { "i", "s" }),

                }),

                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = "path" },
                }, {
                    { name = "buffer" },
                }),
            })
        end,
    },

})
EOF

# ---------------------------
# Neovim health convenience
# ---------------------------

mkdir -p "$HOME/.config/nvim/after"

# ---------------------------
# Git config
# ---------------------------

info "Setting some sane Git defaults..."

git config --global init.defaultBranch main
git config --global core.editor nvim
git config --global pull.rebase false

# ---------------------------
# Done
# ---------------------------

echo
success "Kali rice installed."
echo
echo "Backup:"
echo "  $BACKUP_DIR"
echo
echo "Restart your terminal, then:"
echo
echo "  nvim"
echo
echo "Lazy.nvim will download the plugins on first launch."
echo
echo "Useful Neovim bindings:"
echo
echo "  SPACE e       file explorer"
echo "  SPACE f f     find files"
echo "  SPACE f g     grep project"
echo "  SPACE f b     buffers"
echo "  gd            go to definition"
echo "  K             LSP hover"
echo "  SPACE r n     rename symbol"
echo "  SPACE c a     code action"
echo
echo "Useful shell stuff:"
echo
echo "  z <dir>       zoxide smart cd"
echo "  CTRL-R        fuzzy history search"
echo "  v             neovim"
echo "  ll            pretty detailed listing"
echo "  gs            git status"
echo
echo "You may want a Nerd Font for proper Neovim/eza icons:"
echo "  JetBrainsMono Nerd Font"
echo "  FiraCode Nerd Font"
echo "  Hack Nerd Font"
echo

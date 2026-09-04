#!/usr/bin/env bash

set -euo pipefail

# ============================================================
#
#   KALI DEV RICE
#
#   Installs and configures:
#
#   - Neovim + full dev setup
#   - Lazy.nvim
#   - Catppuccin
#   - Telescope
#   - Treesitter
#   - LSP / Mason
#   - Completion
#   - Neo-tree
#   - Git signs
#   - Which-key
#   - Autopairs
#   - tmux
#   - fzf
#   - ripgrep
#   - fd
#   - bat
#   - eza
#   - btop
#   - zoxide
#   - ZSH plugins/config
#   - Kali wallpaper
#   - Google Drive mount point
#   - Google Drive Desktop shortcut
#   - systemd rclone automount service
#
# ============================================================

# ------------------------------------------------------------
# Colours
# ------------------------------------------------------------

BOLD="\033[1m"
DIM="\033[2m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"

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

error() {
    echo -e "${RED}${BOLD}==>${RESET} $*"
}


# ------------------------------------------------------------
# Sanity checks
# ------------------------------------------------------------

if [[ "$EUID" -eq 0 ]]; then
    error "Do not run this script as root."
    echo
    echo "Run it as your normal Kali user:"
    echo
    echo "    ./rice-kali.sh"
    echo
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is missing."
    exit 1
fi


# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

BACKUP_DIR="$HOME/.rice-backup-$TIMESTAMP"

mkdir -p "$BACKUP_DIR"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share"


# Detect actual Desktop folder.

if command -v xdg-user-dir >/dev/null 2>&1; then
    DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
fi

DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"

mkdir -p "$DESKTOP_DIR"


# ------------------------------------------------------------
# Backup helper
# ------------------------------------------------------------

backup() {

    local target="$1"

    if [[ -e "$target" || -L "$target" ]]; then

        local name
        name="$(basename "$target")"

        warn "Backing up $target"

        cp -a "$target" "$BACKUP_DIR/${name}.bak" 2>/dev/null || true

    fi
}


echo
echo -e "${MAGENTA}${BOLD}"
echo "  ██╗  ██╗ █████╗ ██╗     ██╗"
echo "  ██║ ██╔╝██╔══██╗██║     ██║"
echo "  █████╔╝ ███████║██║     ██║"
echo "  ██╔═██╗ ██╔══██║██║     ██║"
echo "  ██║  ██╗██║  ██║███████╗██║"
echo "  ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝"
echo
echo "              DEV RICE"
echo -e "${RESET}"

echo
info "Backup directory: $BACKUP_DIR"
echo


# ============================================================
# APT
# ============================================================

info "Updating package metadata..."

sudo apt update


BASE_PACKAGES=(

    neovim

    git
    curl
    wget

    unzip
    zip

    build-essential
    gcc
    g++
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

    rclone
    fuse3

    xdg-user-dirs
)


info "Installing base packages..."

sudo apt install -y "${BASE_PACKAGES[@]}"


# ------------------------------------------------------------
# Optional package names differ between Debian versions
# ------------------------------------------------------------

install_if_available() {

    local package="$1"

    if apt-cache show "$package" >/dev/null 2>&1; then

        info "Installing $package..."
        sudo apt install -y "$package"

    fi
}


install_if_available fd-find
install_if_available bat


if apt-cache show eza >/dev/null 2>&1; then

    sudo apt install -y eza

elif apt-cache show exa >/dev/null 2>&1; then

    sudo apt install -y exa

fi


# ============================================================
# Debian command aliases
# ============================================================

info "Adding Debian compatibility aliases..."


if command -v fdfind >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi


if command -v batcat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi


# ============================================================
# ZSH PLUGINS
# ============================================================

info "Installing ZSH plugins..."

ZSH_PLUGIN_DIR="$HOME/.local/share/zsh-plugins"

mkdir -p "$ZSH_PLUGIN_DIR"


clone_or_update() {

    local repo="$1"
    local destination="$2"

    if [[ -d "$destination/.git" ]]; then

        git -C "$destination" pull --ff-only || true

    else

        git clone --depth=1 "$repo" "$destination"

    fi
}


clone_or_update \
    "https://github.com/zsh-users/zsh-autosuggestions.git" \
    "$ZSH_PLUGIN_DIR/zsh-autosuggestions"


clone_or_update \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting"


# ============================================================
# ZSH CONFIG
# ============================================================

info "Configuring ZSH..."

backup "$HOME/.zshrc"


cat > "$HOME/.zshrc" <<'EOF'

# ============================================================
# Kali development ZSH config
# ============================================================

export PATH="$HOME/.local/bin:$PATH"


# ------------------------------------------------------------
# History
# ------------------------------------------------------------

HISTFILE="$HOME/.zsh_history"

HISTSIZE=100000
SAVEHIST=100000

setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY


# ------------------------------------------------------------
# General shell behaviour
# ------------------------------------------------------------

setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt PROMPT_SUBST


# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------

autoload -Uz compinit

compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'


# ------------------------------------------------------------
# Colours
# ------------------------------------------------------------

autoload -U colors
colors


# ------------------------------------------------------------
# Git prompt
# ------------------------------------------------------------

_git_branch() {

    local branch

    branch="$(git symbolic-ref --short HEAD 2>/dev/null)" || return

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
alias vi='nvim'
alias vim='nvim'

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --decorate --graph --all'
alias gd='git diff'
alias gb='git branch'

alias ports='ss -tulpn'

alias myip='curl -s https://ifconfig.me && echo'

alias reload='source ~/.zshrc'


# ------------------------------------------------------------
# Better LS
# ------------------------------------------------------------

if command -v eza >/dev/null 2>&1; then

    alias ls='eza --icons=auto --group-directories-first'

    alias ll='eza \
        -lah \
        --icons=auto \
        --group-directories-first \
        --git'

    alias la='eza -a --icons=auto'

    alias tree='eza --tree --icons=auto'

elif command -v exa >/dev/null 2>&1; then

    alias ls='exa --group-directories-first'

    alias ll='exa \
        -lah \
        --group-directories-first \
        --git'

    alias la='exa -a'

else

    alias ll='ls -lah'
    alias la='ls -A'

fi


# ------------------------------------------------------------
# BAT
# ------------------------------------------------------------

if command -v bat >/dev/null 2>&1; then

    alias cat='bat --paging=never'

    export BAT_THEME="ansi"

fi


# ------------------------------------------------------------
# FZF
# ------------------------------------------------------------

export FZF_DEFAULT_OPTS="
    --height=40%
    --layout=reverse
    --border
    --info=inline
"


if [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then

    source /usr/share/doc/fzf/examples/key-bindings.zsh

fi


if [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]; then

    source /usr/share/doc/fzf/examples/completion.zsh

fi


# ------------------------------------------------------------
# Zoxide
# ------------------------------------------------------------

if command -v zoxide >/dev/null 2>&1; then

    eval "$(zoxide init zsh)"

fi


# ------------------------------------------------------------
# Plugins
# ------------------------------------------------------------

if [[ -f "$HOME/.local/share/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then

    source "$HOME/.local/share/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

fi


# Syntax highlighting MUST be loaded last.

if [[ -f "$HOME/.local/share/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then

    source "$HOME/.local/share/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

fi

EOF


# ============================================================
# TMUX
# ============================================================

info "Configuring tmux..."

backup "$HOME/.tmux.conf"


cat > "$HOME/.tmux.conf" <<'EOF'

# ============================================================
# tmux
# ============================================================

set -g default-terminal "tmux-256color"

set-option -sa terminal-overrides ",xterm*:Tc"


# Mouse support

set -g mouse on


# Number windows from 1

set -g base-index 1

setw -g pane-base-index 1

set-option -g renumber-windows on


# Vi bindings

setw -g mode-keys vi


# Responsiveness

set -sg escape-time 10


# Scrollback

set -g history-limit 100000


# Reload

bind r source-file ~/.tmux.conf \; \
    display-message "tmux config reloaded"


# ------------------------------------------------------------
# Splits
# ------------------------------------------------------------

unbind '"'
unbind %

bind | split-window -h -c "#{pane_current_path}"

bind - split-window -v -c "#{pane_current_path}"


# ------------------------------------------------------------
# Pane movement
# ------------------------------------------------------------

bind -r h select-pane -L
bind -r j select-pane -D
bind -r k select-pane -U
bind -r l select-pane -R


# ------------------------------------------------------------
# Resize
# ------------------------------------------------------------

bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5


# ------------------------------------------------------------
# Status bar
# ------------------------------------------------------------

set -g status-position bottom

set -g status-left-length 50
set -g status-right-length 100

set -g status-left " #[bold]#S "

set -g status-right " #[fg=colour245]%Y-%m-%d #[bold]%H:%M "

setw -g window-status-current-format \
    " #[bold]#I:#W "

setw -g window-status-format \
    " #I:#W "

EOF


# ============================================================
# NEOVIM
# ============================================================

info "Configuring Neovim..."

backup "$HOME/.config/nvim"

rm -rf "$HOME/.config/nvim"

mkdir -p "$HOME/.config/nvim/lua/config"


# ------------------------------------------------------------
# init.lua
# ------------------------------------------------------------

cat > "$HOME/.config/nvim/init.lua" <<'EOF'

require("config.options")

require("config.keymaps")

require("config.lazy")

EOF


# ------------------------------------------------------------
# options.lua
# ------------------------------------------------------------

cat > "$HOME/.config/nvim/lua/config/options.lua" <<'EOF'

local opt = vim.opt


-- UI

opt.number = true

opt.relativenumber = true

opt.cursorline = true

opt.signcolumn = "yes"

opt.termguicolors = true

opt.scrolloff = 8

opt.sidescrolloff = 8


-- Editing

opt.expandtab = true

opt.shiftwidth = 4

opt.tabstop = 4

opt.softtabstop = 4

opt.smartindent = true


-- Search

opt.ignorecase = true

opt.smartcase = true


-- Windows

opt.splitbelow = true

opt.splitright = true


-- Behaviour

opt.mouse = "a"

opt.wrap = false

opt.undofile = true

opt.updatetime = 250

opt.timeoutlen = 400


-- Clipboard

opt.clipboard = "unnamedplus"


-- Completion

opt.completeopt = {
    "menu",
    "menuone",
    "noselect",
}


vim.g.mapleader = " "

vim.g.maplocalleader = " "

EOF


# ------------------------------------------------------------
# keymaps.lua
# ------------------------------------------------------------

cat > "$HOME/.config/nvim/lua/config/keymaps.lua" <<'EOF'

local map = vim.keymap.set


map(
    "n",
    "<leader>w",
    "<cmd>w<cr>",
    { desc = "Save" }
)


map(
    "n",
    "<leader>q",
    "<cmd>q<cr>",
    { desc = "Quit" }
)


map(
    "n",
    "<leader>e",
    "<cmd>Neotree toggle<cr>",
    { desc = "File explorer" }
)


map(
    "n",
    "<leader>ff",
    "<cmd>Telescope find_files<cr>",
    { desc = "Find files" }
)


map(
    "n",
    "<leader>fg",
    "<cmd>Telescope live_grep<cr>",
    { desc = "Live grep" }
)


map(
    "n",
    "<leader>fb",
    "<cmd>Telescope buffers<cr>",
    { desc = "Buffers" }
)


map(
    "n",
    "<leader>fh",
    "<cmd>Telescope help_tags<cr>",
    { desc = "Help" }
)


map("n", "<C-h>", "<C-w>h")

map("n", "<C-j>", "<C-w>j")

map("n", "<C-k>", "<C-w>k")

map("n", "<C-l>", "<C-w>l")


map(
    "v",
    "J",
    ":m '>+1<CR>gv=gv"
)


map(
    "v",
    "K",
    ":m '<-2<CR>gv=gv"
)


map(
    "n",
    "<Esc>",
    "<cmd>nohlsearch<cr>"
)

EOF


# ------------------------------------------------------------
# lazy.lua
# ------------------------------------------------------------

cat > "$HOME/.config/nvim/lua/config/lazy.lua" <<'EOF'

local lazypath =
    vim.fn.stdpath("data") ..
    "/lazy/lazy.nvim"


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
    -- Icons
    -- ========================================================

    {

        "nvim-tree/nvim-web-devicons",

        lazy = true,

    },


    -- ========================================================
    -- Status line
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

                    component_separators = {

                        left = "│",

                        right = "│",

                    },

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

                    layout_strategy =
                        "horizontal",

                    layout_config = {

                        prompt_position =
                            "top",

                    },

                    sorting_strategy =
                        "ascending",

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

            require(
                "nvim-treesitter.configs"
            ).setup({

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

                    "markdown_inline",

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
    -- Git
    -- ========================================================

    {

        "lewis6991/gitsigns.nvim",

        config = function()

            require(
                "gitsigns"
            ).setup()

        end,

    },


    -- ========================================================
    -- Autopairs
    -- ========================================================

    {

        "windwp/nvim-autopairs",

        event = "InsertEnter",

        config = function()

            require(
                "nvim-autopairs"
            ).setup({})

        end,

    },


    -- ========================================================
    -- Which-key
    -- ========================================================

    {

        "folke/which-key.nvim",

        event = "VeryLazy",

        config = function()

            require(
                "which-key"
            ).setup({})

        end,

    },


    -- ========================================================
    -- Mason
    -- ========================================================

    {

        "williamboman/mason.nvim",

        config = function()

            require(
                "mason"
            ).setup()

        end,

    },


    {

        "williamboman/mason-lspconfig.nvim",

        dependencies = {

            "williamboman/mason.nvim",

            "neovim/nvim-lspconfig",

        },

        config = function()

            require(
                "mason-lspconfig"
            ).setup({

                ensure_installed = {

                    "lua_ls",

                    "pyright",

                    "bashls",

                },

                automatic_installation =
                    true,

            })

        end,

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
                require(
                    "cmp_nvim_lsp"
                ).default_capabilities()


            local lspconfig =
                require("lspconfig")


            local servers = {

                "lua_ls",

                "pyright",

                "bashls",

            }


            for _, server in ipairs(servers) do

                if lspconfig[server] then

                    lspconfig[server].setup({

                        capabilities =
                            capabilities,

                    })

                end

            end


            vim.keymap.set(

                "n",

                "gd",

                vim.lsp.buf.definition,

                {
                    desc =
                        "Go to definition",
                }

            )


            vim.keymap.set(

                "n",

                "K",

                vim.lsp.buf.hover,

                {
                    desc =
                        "Hover documentation",
                }

            )


            vim.keymap.set(

                "n",

                "<leader>rn",

                vim.lsp.buf.rename,

                {
                    desc =
                        "Rename",
                }

            )


            vim.keymap.set(

                "n",

                "<leader>ca",

                vim.lsp.buf.code_action,

                {
                    desc =
                        "Code action",
                }

            )


            vim.keymap.set(

                "n",

                "<leader>d",

                vim.diagnostic.open_float,

                {
                    desc =
                        "Diagnostics",
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

            local cmp =
                require("cmp")

            local luasnip =
                require("luasnip")


            cmp.setup({

                snippet = {

                    expand =
                        function(args)

                            luasnip.lsp_expand(
                                args.body
                            )

                        end,

                },


                mapping =
                    cmp.mapping.preset.insert({

                        ["<C-Space>"] =
                            cmp.mapping.complete(),


                        ["<CR>"] =
                            cmp.mapping.confirm({

                                select = true,

                            }),


                        ["<Tab>"] =
                            cmp.mapping(

                                function(fallback)

                                    if
                                        cmp.visible()
                                    then

                                        cmp.select_next_item()

                                    elseif
                                        luasnip.expand_or_jumpable()
                                    then

                                        luasnip.expand_or_jump()

                                    else

                                        fallback()

                                    end

                                end,

                                {
                                    "i",
                                    "s",
                                }

                            ),


                        ["<S-Tab>"] =
                            cmp.mapping(

                                function(fallback)

                                    if
                                        cmp.visible()
                                    then

                                        cmp.select_prev_item()

                                    elseif
                                        luasnip.jumpable(-1)
                                    then

                                        luasnip.jump(-1)

                                    else

                                        fallback()

                                    end

                                end,

                                {
                                    "i",
                                    "s",
                                }

                            ),

                    }),


                sources =
                    cmp.config.sources({

                        {
                            name =
                                "nvim_lsp",
                        },

                        {
                            name =
                                "luasnip",
                        },

                        {
                            name =
                                "path",
                        },

                    }, {

                        {
                            name =
                                "buffer",
                        },

                    }),

            })

        end,

    },

})

EOF


# ============================================================
# GIT DEFAULTS
# ============================================================

info "Setting Git defaults..."

git config --global init.defaultBranch main

git config --global core.editor nvim

git config --global pull.rebase false

git config --global color.ui auto


# ============================================================
# WALLPAPER
# ============================================================

info "Looking for a good Kali wallpaper..."


find_wallpaper() {

    local candidates=""

    candidates="$(
        find \
            /usr/share/backgrounds \
            /usr/share/wallpapers \
            -type f \
            \( \
                -iname '*.png' \
                -o -iname '*.jpg' \
                -o -iname '*.jpeg' \
                -o -iname '*.webp' \
            \) \
            2>/dev/null || true
    )"


    # Preference:
    #
    # Kali
    # purple
    # dark
    # dragon
    #

    local result


    result="$(
        echo "$candidates" |
        grep -Ei \
            'kali.*(dark|purple)|purple.*kali|dark.*kali' |
        head -n1
    )"


    if [[ -z "$result" ]]; then

        result="$(
            echo "$candidates" |
            grep -Ei \
                'kali|dragon|purple|dark' |
            head -n1
        )"

    fi


    if [[ -z "$result" ]]; then

        result="$(
            echo "$candidates" |
            head -n1
        )"

    fi


    echo "$result"
}


WALLPAPER="$(find_wallpaper)"


if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then

    success "Selected wallpaper:"
    echo "    $WALLPAPER"


    # --------------------------------------------------------
    # XFCE
    # --------------------------------------------------------

    if command -v xfconf-query >/dev/null 2>&1; then

        info "Configuring XFCE wallpaper..."

        while IFS= read -r prop; do

            [[ -z "$prop" ]] && continue

            xfconf-query \
                -c xfce4-desktop \
                -p "$prop" \
                -s "$WALLPAPER" \
                2>/dev/null || true

        done < <(

            xfconf-query \
                -c xfce4-desktop \
                -l \
                2>/dev/null |
            grep '/last-image$' || true

        )


        while IFS= read -r prop; do

            [[ -z "$prop" ]] && continue

            xfconf-query \
                -c xfce4-desktop \
                -p "$prop" \
                -s 5 \
                2>/dev/null || true

        done < <(

            xfconf-query \
                -c xfce4-desktop \
                -l \
                2>/dev/null |
            grep '/image-style$' || true

        )


    # --------------------------------------------------------
    # GNOME
    # --------------------------------------------------------

    elif command -v gsettings >/dev/null 2>&1; then

        info "Configuring GNOME wallpaper..."

        gsettings set \
            org.gnome.desktop.background \
            picture-uri \
            "file://$WALLPAPER" \
            2>/dev/null || true


        gsettings set \
            org.gnome.desktop.background \
            picture-uri-dark \
            "file://$WALLPAPER" \
            2>/dev/null || true


        gsettings set \
            org.gnome.desktop.background \
            picture-options \
            'zoom' \
            2>/dev/null || true


    # --------------------------------------------------------
    # KDE
    # --------------------------------------------------------

    elif command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then

        info "Configuring KDE wallpaper..."

        plasma-apply-wallpaperimage \
            "$WALLPAPER" \
            2>/dev/null || true

    else

        warn "Couldn't identify the desktop environment."

    fi

else

    warn "No installed wallpaper was found."

fi


# ============================================================
# GOOGLE DRIVE
# ============================================================

info "Preparing Google Drive..."


GOOGLE_DRIVE_DIR="$HOME/Google Drive"

GOOGLE_CONFIG_DIR="$HOME/.config/google-drive"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"


mkdir -p "$GOOGLE_DRIVE_DIR"

mkdir -p "$GOOGLE_CONFIG_DIR"

mkdir -p "$SYSTEMD_USER_DIR"


# ------------------------------------------------------------
# Desktop shortcut
# ------------------------------------------------------------

GOOGLE_DESKTOP_LINK="$DESKTOP_DIR/Google Drive"


if [[ -L "$GOOGLE_DESKTOP_LINK" ]]; then

    CURRENT_TARGET="$(
        readlink "$GOOGLE_DESKTOP_LINK" || true
    )"

    if [[ "$CURRENT_TARGET" != "$GOOGLE_DRIVE_DIR" ]]; then

        rm -f "$GOOGLE_DESKTOP_LINK"

    fi

elif [[ -e "$GOOGLE_DESKTOP_LINK" ]]; then

    warn "\"$GOOGLE_DESKTOP_LINK\" already exists."

    warn "Leaving it untouched."

fi


if [[ ! -e "$GOOGLE_DESKTOP_LINK" && ! -L "$GOOGLE_DESKTOP_LINK" ]]; then

    ln -s \
        "$GOOGLE_DRIVE_DIR" \
        "$GOOGLE_DESKTOP_LINK"

fi


success "Google Drive Desktop shortcut:"
echo "    $GOOGLE_DESKTOP_LINK"


# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------

cat > "$GOOGLE_CONFIG_DIR/environment" <<EOF
# ============================================================
# Google Drive mount configuration
# ============================================================

RCLONE_REMOTE=gdrive:

RCLONE_MOUNTPOINT=$HOME/Google Drive

RCLONE_CACHE_DIR=$HOME/.cache/rclone-google-drive

EOF


# ------------------------------------------------------------
# Mount helper
# ------------------------------------------------------------

cat > "$HOME/.local/bin/mount-google-drive" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail


CONFIG="$HOME/.config/google-drive/environment"


if [[ -f "$CONFIG" ]]; then

    set -a

    # shellcheck disable=SC1090
    source "$CONFIG"

    set +a

fi


RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive:}"

RCLONE_MOUNTPOINT="${RCLONE_MOUNTPOINT:-$HOME/Google Drive}"

RCLONE_CACHE_DIR="${RCLONE_CACHE_DIR:-$HOME/.cache/rclone-google-drive}"


mkdir -p "$RCLONE_MOUNTPOINT"

mkdir -p "$RCLONE_CACHE_DIR"


if mountpoint -q "$RCLONE_MOUNTPOINT"; then

    echo "Google Drive is already mounted."

    exit 0

fi


REMOTE_NAME="${RCLONE_REMOTE%:}"


if ! rclone listremotes |
    grep -Fxq "${REMOTE_NAME}:"; then

    echo
    echo "Google Drive has not been configured yet."
    echo
    echo "Expected rclone remote:"
    echo
    echo "    ${REMOTE_NAME}:"
    echo
    echo "Run:"
    echo
    echo "    rclone config"
    echo

    exit 1

fi


exec rclone mount \
    "$RCLONE_REMOTE" \
    "$RCLONE_MOUNTPOINT" \
    --vfs-cache-mode full \
    --cache-dir "$RCLONE_CACHE_DIR" \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --dir-cache-time 12h \
    --poll-interval 1m \
    --buffer-size 32M \
    --umask 022

EOF


chmod +x "$HOME/.local/bin/mount-google-drive"


# ------------------------------------------------------------
# Unmount helper
# ------------------------------------------------------------

cat > "$HOME/.local/bin/unmount-google-drive" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

MOUNTPOINT="$HOME/Google Drive"


if ! mountpoint -q "$MOUNTPOINT"; then

    echo "Google Drive is not mounted."

    exit 0

fi


if command -v fusermount3 >/dev/null 2>&1; then

    fusermount3 -u "$MOUNTPOINT"

else

    fusermount -u "$MOUNTPOINT"

fi

EOF


chmod +x "$HOME/.local/bin/unmount-google-drive"


# ------------------------------------------------------------
# systemd service
# ------------------------------------------------------------

cat > "$SYSTEMD_USER_DIR/google-drive.service" <<'EOF'

[Unit]

Description=Google Drive via rclone

Documentation=https://rclone.org/drive/

After=network-online.target

Wants=network-online.target


[Service]

Type=notify

ExecStart=%h/.local/bin/mount-google-drive

ExecStop=%h/.local/bin/unmount-google-drive

Restart=on-failure

RestartSec=10


[Install]

WantedBy=default.target

EOF


systemctl --user daemon-reload 2>/dev/null || true


# ============================================================
# EXTRA SHELL ALIASES FOR GOOGLE DRIVE
# ============================================================

cat >> "$HOME/.zshrc" <<'EOF'


# ============================================================
# Google Drive
# ============================================================

alias gdrive='cd "$HOME/Google Drive"'

alias mountdrive='systemctl --user start google-drive.service'

alias unmountdrive='systemctl --user stop google-drive.service'

alias drivelog='journalctl --user -u google-drive.service -f'

EOF


# ============================================================
# PRIME NEOVIM
# ============================================================

info "Bootstrapping Neovim plugins..."


# This causes Lazy.nvim to install plugins now rather than making
# the first interactive nvim launch do everything.

nvim \
    --headless \
    "+Lazy! sync" \
    +qa \
    2>/dev/null || true


# ============================================================
# FINAL INTERACTIVE SETUP
# ============================================================

echo
echo
success "Main rice installation complete."

echo
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
echo -e "${BOLD}Google Drive${RESET}"
echo

echo "A Google Drive folder now exists at:"
echo
echo "    $GOOGLE_DRIVE_DIR"
echo
echo "and appears on the desktop at:"
echo
echo "    $GOOGLE_DESKTOP_LINK"
echo


# ------------------------------------------------------------
# Configure rclone now?
# ------------------------------------------------------------

read -r -p \
    "Configure Google Drive with rclone now? [y/N] " \
    CONFIGURE_DRIVE


if [[ "$CONFIGURE_DRIVE" =~ ^[Yy]$ ]]; then

    echo
    info "Starting rclone configuration..."
    echo
    echo "Create a remote named:"
    echo
    echo -e "    ${BOLD}gdrive${RESET}"
    echo
    echo "Choose Google Drive when prompted."
    echo

    rclone config


    echo
    read -r -p \
        "Enable automatic Google Drive mounting at login? [Y/n] " \
        ENABLE_DRIVE


    if [[ ! "$ENABLE_DRIVE" =~ ^[Nn]$ ]]; then

        systemctl --user enable google-drive.service

        systemctl --user restart google-drive.service || true


        sleep 2


        if mountpoint -q "$GOOGLE_DRIVE_DIR"; then

            success "Google Drive is mounted."

        else

            warn "Google Drive isn't mounted yet."

            echo
            echo "Check:"
            echo
            echo "    systemctl --user status google-drive"
            echo
            echo "or:"
            echo
            echo "    journalctl --user -u google-drive"
            echo

        fi

    fi

fi


# ============================================================
# OPTIONAL FINAL ACTIONS
# ============================================================

echo
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
echo -e "${BOLD}Optional extras${RESET}"
echo


read -r -p \
    "Launch Neovim once now to verify the setup? [y/N] " \
    TEST_NVIM


if [[ "$TEST_NVIM" =~ ^[Yy]$ ]]; then

    nvim

fi


echo
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

success "Everything is installed."

echo

echo -e "${BOLD}Backup:${RESET}"
echo "    $BACKUP_DIR"

echo

echo -e "${BOLD}Google Drive:${RESET}"
echo "    ~/Google Drive"
echo

echo -e "${BOLD}Desktop shortcut:${RESET}"
echo "    $GOOGLE_DESKTOP_LINK"

echo

echo -e "${BOLD}Useful shell commands:${RESET}"

echo
echo "    v"
echo "        Neovim"

echo
echo "    ll"
echo "        Pretty directory listing"

echo
echo "    z <folder>"
echo "        Smart directory navigation"

echo
echo "    gdrive"
echo "        cd into Google Drive"

echo
echo "    mountdrive"
echo "        Mount Google Drive"

echo
echo "    unmountdrive"
echo "        Unmount Google Drive"

echo
echo "    drivelog"
echo "        Follow Google Drive mount logs"

echo
echo "    btop"
echo "        System monitor"

echo
echo "    tmux"
echo "        Terminal multiplexer"


echo

echo -e "${BOLD}Neovim:${RESET}"

echo
echo "    SPACE e"
echo "        File browser"

echo
echo "    SPACE f f"
echo "        Find files"

echo
echo "    SPACE f g"
echo "        Search file contents"

echo
echo "    SPACE f b"
echo "        Open buffers"

echo
echo "    gd"
echo "        Go to definition"

echo
echo "    K"
echo "        Documentation"

echo
echo "    SPACE r n"
echo "        Rename symbol"

echo
echo "    SPACE c a"
echo "        Code action"

echo

warn "Restart your terminal/session so all shell and desktop changes are picked up."

echo
echo -e "${GREEN}${BOLD}Done. Enjoy Kali.${RESET}"
echo

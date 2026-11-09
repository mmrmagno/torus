export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
[[ -r ${XDG_STATE_HOME:-$HOME/.local/state}/torus/theme/fzf.zsh ]] && source "${XDG_STATE_HOME:-$HOME/.local/state}/torus/theme/fzf.zsh"
(( $+commands[starship] )) && eval "$(starship init zsh)"
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -r ${XDG_STATE_HOME:-$HOME/.local/state}/torus/theme/zsh-colors.zsh ]] && source "${XDG_STATE_HOME:-$HOME/.local/state}/torus/theme/zsh-colors.zsh"
[[ -r ${XDG_STATE_HOME:-$HOME/.local/state}/torus/fastfetch/config.jsonc ]] && alias fastfetch="fastfetch --config ${XDG_STATE_HOME:-$HOME/.local/state}/torus/fastfetch/config.jsonc"
torus_fetch_stop() { pkill -f "torus-fetch --animate $$ " 2> /dev/null; }
torus_fetch_clear() { torus_fetch_stop; zle .clear-screen; }
zle -N clear-screen torus_fetch_clear
autoload -Uz add-zsh-hook && add-zsh-hook zshexit torus_fetch_stop

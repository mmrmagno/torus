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
_torus() {
  if (( CURRENT == 2 )); then
    compadd accent flavour setup doctor ipc safe unsafe
  elif [[ ${words[2]} == ipc && CURRENT == 3 ]]; then
    compadd -- ${(f)"$(torus-ipc --names 2> /dev/null)"}
  elif [[ ${words[2]} == doctor ]]; then
    compadd -- --fix --snapshot
  elif [[ ${words[2]} == accent ]]; then
    compadd rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender
  elif [[ ${words[2]} == flavour ]]; then
    compadd mocha macchiato frappe latte
  fi
}
torus_compdef() { (( $+functions[compdef] )) && compdef _torus torus && add-zsh-hook -d precmd torus_compdef; }
add-zsh-hook precmd torus_compdef

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
torus_ci_pre() { [[ $1 == (git|g)\ push* ]] && torus_ci_pushed=1 || torus_ci_pushed=; }
torus_ci_post() { local rc=$?; [[ -n $torus_ci_pushed && $rc == 0 ]] && (( $+commands[torus-ci] )) && { torus-ci "$PWD" > /dev/null 2>&1 &! }; torus_ci_pushed=; return $rc; }
add-zsh-hook preexec torus_ci_pre
precmd_functions=(torus_ci_post ${precmd_functions:#torus_ci_post})
torus_err_pre() { torus_err_cmd=$1; }
torus_err_post() { local rc=$?; [[ $rc != 0 && $rc != 130 && -n $torus_err_cmd ]] && print -r -- "exit $rc in ${PWD/#$HOME/~}: $torus_err_cmd" >| ${XDG_RUNTIME_DIR:-/tmp}/torus-last-error; torus_err_cmd=; return $rc; }
add-zsh-hook preexec torus_err_pre
precmd_functions=(torus_err_post ${precmd_functions:#torus_err_post})

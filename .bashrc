
    ######                  #
    ##   ##                 #
    ##   ##  ####    ###### # ###   # ####   #####
    ######       #  #       ##   #  ##    # #     #
    ##   ##  ####    #####  #     # #       #
##  ##   ## #   ##        # #     # #       #     #
##  ######   ###  # ######  #     # #        #####


shopt -s autocd # Automatically does a cd when you type a directory
shopt -s checkwinsize # resize window automatically after each command

#################
#### HISTORY ####
#################

export HISTFILESIZE=20000
export HISTSIZE=10000
shopt -s histappend
HISTCONTROL=ignoredups
export HISTIGNORE="&:ls:[bf]g:clear:exit:.."

##########################
#### ENVIRONMENT VARS ####
##########################

# for some reason this doesnt seem to be set by default...
export XDG_CONFIG_HOME="$HOME/.config"
export DOTFILE_DIR="$HOME/dotfiles"

# set nvim as the default editor
export EDITOR="nvim-qt --nvim /usr/local/bin/nvim"
export MANPAGER="nvim +Man!"

export LUA_CPATH+=";$HOME/dev/luastuffs/ltreesitter/?.so;$HOME/dev/parsers/?.so"
if ! [[ "$SHELL" =~ /nix/store.* ]]; then
	export PATH+=":./:$HOME/Applications:$HOME/bin:/usr/local/bin"
fi

# xterm-kitty doesn't work over ssh
export TERM=xterm-256color

#################
#### ALIASES ####
#################

for f in $DOTFILE_DIR/bash_aliases/*; do
	source $f
done

####################
#### PS1 STUFFS ####
####################

# offload getting ps1 to lua script
SET_DEFAULT_PS1=0
export MY_PS1=$PS1
function ps1swap {
	SET_DEFAULT_PS1=$((1-$SET_DEFAULT_PS1))
}
function update_ps1 {
	if (( $SET_DEFAULT_PS1 == 1 )); then
		PS1=$MY_PS1
		return 0
	fi

	# using utf8 needs a utf8 lib, which luajit doesn't come with
	PS1=$(/nix/store/qp7s8wsq919p03alrchf5i9lpa2h3fn2-lua-5.4.2/bin/lua $DOTFILE_DIR/ps1Getter.lua 2> /tmp/ps1ErrLog.log)
	if [ "$PS1" = "" ]; then
		PS1=$MY_PS1
	fi
}
update_ps1
PROMPT_COMMAND=update_ps1

# if [[ -z $TMUX ]]; then
	# exec tmux
# fi

# This is silly
# if [[ -z $NVIM_STARTED ]]; then
# 	export NVIM_STARTED=1
# 	exec nvim "+term" "+startinsert"
# else
# 	alias nvim="echo no;# "
# fi

# TODO: fix this?
export QT_QPA_PLATFORM_PLUGIN_PATH=/nix/store/jwxyc4755zpaacssxy23y3s0bf3d6pk8-qtbase-5.15.2-bin/lib/qt-5.15.2/plugins/platforms

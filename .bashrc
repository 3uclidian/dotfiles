
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
export EDITOR=nvim
export MANPAGER="nvim +Man!"

# Additions to PATH
function lua-path-prepend-dir {
	export LUA_PATH="$1/?.lua;$1/?/init.lua;$LUA_PATH"
}
function lua-path-append-dir {
	export LUA_PATH="$LUA_PATH;$1/?.lua;$1/?/init.lua"
}
function lua-cpath-prepend-dir {
	export LUA_CPATH="$1/?.so;$LUA_CPATH"
}
function lua-cpath-append-dir {
	export LUA_CPATH="$LUA_CPATH;$1/?.so"
}
lua-path-prepend-dir "$HOME/dev/teal-language-server/build"
lua-cpath-prepend-dir "$HOME/dev/ltreesitter"
lua-path-prepend-dir "$HOME/dev/ltresitter"
lua-path-prepend-dir "$HOME/dev/new-tl-cli/build"
lua-path-prepend-dir "$HOME/dev/tl"
lua-path-prepend-dir "."
lua-cpath-prepend-dir "."
lua-path-append-dir "$HOME/dev/new-tl-cli"
export LUA_CPATH+=";$HOME/dev/luastuffs/ltreesitter/?.so;$HOME/dev/parsers/?.so"
export PATH="./:./lua_modules/bin:$PATH:/usr/local/openresty/bin:$HOME/ngrok:$HOME/Applications:$HOME/bin:$HOME/dev/new-tl-cli/bin"

# xterm-kitty doesn't work over ssh
# export TERM=xterm-256color

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
DEFAULT_PS1=$PS1
function ps1swap {
	SET_DEFAULT_PS1=$((1-$SET_DEFAULT_PS1))
}
function update_ps1 {
	if (( $SET_DEFAULT_PS1 == 1 )); then
		PS1=$DEFAULT_PS1
		return 0
	fi
	# using utf8 needs a utf8 lib, which luajit doesn't come with
	PS1=$(/nix/store/qp7s8wsq919p03alrchf5i9lpa2h3fn2-lua-5.4.2/bin/lua $DOTFILE_DIR/ps1Getter.lua 2> /tmp/ps1ErrLog.log)
	if [ "$PS1" = "" ]; then
		PS1=$DEFAULT_PS1
	fi
}
update_ps1
PROMPT_COMMAND=update_ps1

# This is silly
# if [[ -z $NVIM_STARTED ]]; then
# 	export NVIM_STARTED=1
# 	exec nvim "+term" "+startinsert"
# else
# 	alias nvim="echo no;# "
# fi


    ######                  #
    ##   ##                 #
    ##   ##  ####    ###### # ###   # ####   #####
    ######       #  #       ##   #  ##    # #     #
    ##   ##  ####    #####  #     # #       #
##  ##   ## #   ##        # #     # #       #     #
##  ######   ###  # ######  #     # #        #####  


# vi mode: allows vi style commands within bash
set -o vi

shopt -s autocd		# Automatically does a cd when you type a directory
shopt -s checkwinsize 	# resize window automatically after each command

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

# set neovim as the default editor
export EDITOR=nvim

# Additions to PATH
source /etc/profile
export PATH="$PATH:~/bin"
eval $(luarocks path --bin)


#################
#### ALIASES ####
#################

# default options
alias ls="ls -hN --file-type --color=auto --group-directories-first"
alias la="ls -AhN --file-type --color=auto --group-directories-first"
alias ll="ls -AhNl --file-type --color=auto --group-directories-first"
alias grep="grep --color=auto"

# always ask before emerging and do it quietly
alias emerge="sudo emerge --ask --quiet"
alias emergev="sudo emerge --ask"
alias emergef="sudo emerge --ask --fetchonly --quiet"
alias etc-update="sudo etc-update"

# power stuffs 
alias sdn="sudo shutdown -h now"
alias rb="sudo reboot"

# actual "aliases"
alias v="nvim"

# config file editing and reloading
alias ebrc="$EDITOR ~/.bashrc && source ~/.bashrc"
alias exr="$EDITOR ~/.Xresources && xrdb ~/.Xresources"
alias evrc="$EDITOR ~/.vimrc"
alias eps1="$EDITOR ~/.config/ps1Getter.lua"


##########################
####    PS1 STUFFS    ####
##########################

# offload getting ps1 to lua script
DEFAULT_PS1=$PS1
function update_ps1 { 
	PS1=$(luajit $HOME/.config/ps1Getter.lua 2> /dev/null)
	if [ "$PS1" = "" ]; then
		PS1=$DEFAULT_PS1
	fi
}
update_ps1
PROMPT_COMMAND=update_ps1


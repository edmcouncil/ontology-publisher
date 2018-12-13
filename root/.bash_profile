#
# This is the /root/bash_profile for the user "root" in the Docker container.
#
# colors
export PS1='\w\[\033[0;32m\]$( git branch 2> /dev/null | cut -f2 -d\* -s | sed "s/^ / [/" | sed "s/$/]/" )\[\033[0m\] \$ '

# Tell grep to highlight matches
alias grep=grep --color=auto

# Tell ls to be colourful
export CLICOLOR=1
export LSCOLORS=Exfxcxdxbxegedabagacad

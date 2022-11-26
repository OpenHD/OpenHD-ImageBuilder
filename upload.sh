#!/bin/bash -e

LINK=$1
USERNAME=$2
PASSWORD=$3
PORT=$4

# print a simple line across the entire width of the terminal like '------------'
line (){
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

echo ""
n=" ██████╗ ██████╗ ███████╗███╗   ██╗   ██╗  ██╗██████╗     ██╗███╗   ███╗ █████╗  ██████╗ ███████╗   ██╗   ██╗██████╗ ██╗      ██████╗  █████╗ ██████╗ ███████╗██████╗  " && echo "${n::${COLUMNS:-$(tput cols)}}" # some magic to cut the end on smaller terminals
n="██╔═══██╗██╔══██╗██╔════╝████╗  ██║   ██║  ██║██╔══██╗    ██║████╗ ████║██╔══██╗██╔════╝ ██╔════╝   ██║   ██║██╔══██╗██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗" && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██████╔╝█████╗  ██╔██╗ ██║   ███████║██║  ██║    ██║██╔████╔██║███████║██║  ███╗█████╗     ██║   ██║██████╔╝██║     ██║   ██║███████║██║  ██║█████╗  ██████╔╝" && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║   ██╔══██║██║  ██║    ██║██║╚██╔╝██║██╔══██║██║   ██║██╔══╝     ██║   ██║██╔═══╝ ██║     ██║   ██║██╔══██║██║  ██║██╔══╝  ██╔══██╗" && echo "${n::${COLUMNS:-$(tput cols)}}"
n="╚██████╔╝██║     ███████╗██║ ╚████║██╗██║  ██║██████╔╝    ██║██║ ╚═╝ ██║██║  ██║╚██████╔╝███████╗   ╚██████╔╝██║     ███████╗╚██████╔╝██║  ██║██████╔╝███████╗██║  ██║" && echo "${n::${COLUMNS:-$(tput cols)}}"
n=" ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═════╝     ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝    ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝" && echo "${n::${COLUMNS:-$(tput cols)}}"
echo ""
line
echo ""

#generated via http://patorjk.com/software/taag/#p=display&h=1&v=1&f=ANSI%20Shadow&t=UPLOADER
mv *zip
for f in ./*.zip; do
    if  grep -q "upload" "$f" ; then
        echo 'this is a release' ; 
        sshpass -p ${PASSWORD} scp -P ${PORT} *.zip ${USERNAME}@${LINK}:/opt/
    else
        echo 'this is garbage' ; 
    fi
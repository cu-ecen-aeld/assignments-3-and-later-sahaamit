
set -e
set -u

if test "$#" -ne 2 ; then
    echo "Invalid number of parameters"
    exit 1
fi


path=$(dirname "$1")

mkdir -p "${path}"

#echo $2 >> $1
./writer "$2" "$1"




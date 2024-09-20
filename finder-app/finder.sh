
set -e
set -u

if test "$#" -ne 2 ; then
    echo "Invalid number of parameters"
    exit 1
fi

test -d "$1"
if test "$?" -ne 0 ; then 
    echo "Invalid path"
    exit 1
fi

X=$(grep -r "$2" "$1" 2>/dev/null  | cut -d: -f1 | sort -u | wc -l)
Y=$(grep -r "$2" "$1" 2>/dev/null  | wc -l)

echo "The number of files are ${X} and the number of matching lines are ${Y}"

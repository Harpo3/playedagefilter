#!/bin/bash
set -e
print_help(){
cat << 'EOF'

A musicbase utility to generate filtered output based on last played values
Usage: playedagefilter.sh [option] FILE POPMCOL TIMECOL

options:
-d specify delimiter (default: ^)
-h display this help file
-n exclude output file header where input file contains header
-o specify output file and path (default: $HOME/.timefiltered.dsv)
-t use epoch time as numerical date-value type when epoch is type used in FILE (default is sql)

Specify input database FILE of rated tracks, POPMCOL (FILE column number containing POPM values),
and TIMECOL (FILE column number with last played dates expressed as numerical sql or epoch 
time-values)

Filters rated-tracks FILE, based on last-played-date, and outputs results to a database file of 
not-recently-played tracks, which can then be used by other tools for playlist creation. 
Recently played tracks, ineligible for playlist inclusion, are filtered out using different 
thresholds. Thresholds are set based on repeat frequency needed for a given rating (POPM 
range) group. For example, five star tracks (POPM 230-255) might be repeated every 50 days,
while four star tracks only every 180. So, five star tracks played within the last 50 days
would be filtered out, and so on for other groups. 

Revise group variables for days in the script as needed to make output more or less restrictive.

Defaults:
Rating group last played age (in days):
group1=50 #(popularimeter 230-255)
group2=180 #(popularimeter 192-229)
group3=305 #(popularimeter 166-191)
group4=910 #(popularimeter 136-165)
group5=1460 #(popularimeter 64-135)

The five popularimeter (POPM) high and low ranges may also be modified in the script, if needed.

EOF
}
# Rating group last played age (in days):
group1=50 #(popularimeter 230-255)
group2=180 #(popularimeter 192-229)
group3=305 #(popularimeter 166-191)
group4=910 #(popularimeter 136-165)
group5=1500 #(popularimeter 64-135)
# POPM low ranges
group1low=230 #(popularimeter 230-255)
group2low=192 #(popularimeter 192-229)
group3low=166 #(popularimeter 166-191)
group4low=136 #(popularimeter 136-165)
group5low=64 #(popularimeter 64-135)
# POPM high ranges
group1high=255 #(popularimeter 230-255)
group2high=229 #(popularimeter 192-229)
group3high=191 #(popularimeter 166-191)
group4high=165 #(popularimeter 136-165)
group5high=135 #(popularimeter 64-135)
#
# Default time value of LastPlayedDate field is numerical SQL time but user may specify "epoch"
timeformat="sql"
mydelimiter="^"
excludeheader="no"
outputfile=$"$HOME/.timefiltered.dsv"
# 
# Use getops to set any user-assigned options
while getopts ":d:hno:t" opt; do
  case $opt in
    d)
      mydelimiter=$OPTARG 
      ;;
    h) 
      print_help
      exit 0;;
    n)
      excludeheader="yes" 
      ;;
    o)      
      outputfile=$OPTARG
      ;;
    t)      
      timeformat="epoch"
      ;;
    \?)
      printf 'Invalid option: -%s\n' "$OPTARG"
      exit 1
      ;;
    :)
      printf 'Option requires an argument: %s\n' "$OPTARG"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

## Verify user provided required, valid path and time argument
if [[ -z "$1" ]] || [[ -z "$2" ]] ||  [[ -z "$3" ]]
then
    printf  '\n%s\n' "****Missing positional argument(s)******"
    print_help
    exit 1
fi

currepochtime="$(date +%s)"
currsqldec="$(printf "%.6f \n" "$(echo "$currepochtime/86400 + 25569"| bc -l)")"
currsqltime="$(echo ${currsqldec%.*})"
myrated=$1
# epoch threshold values
group1epochth=$(( currepochtime - (group1 * 86400) ))
group2epochth=$(( currepochtime - (group2 * 86400) ))
group3epochth=$(( currepochtime - (group3 * 86400) ))
group4epochth=$(( currepochtime - (group4 * 86400) ))
group5epochth=$(( currepochtime - (group5 * 86400) ))
# sql threshold values
group1sqlth=$(( currsqltime - group1 ))
group2sqlth=$(( currsqltime - group2 ))
group3sqlth=$(( currsqltime - group3 ))
group4sqlth=$(( currsqltime - group4 ))
group5sqlth=$(( currsqltime - group5 ))

# positional variables
popmcolnum="\$""$2"
timecol="\$""$3"
cat /dev/null > "$outputfile"
if [[ $excludeheader == "no" ]] 
then
awk -F "$mydelimiter" '{if (NR==1) { print }}' "$myrated" > "$outputfile"
fi
if [[ $timeformat == "sql" ]] 
then
    {
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group1low"" && ""$popmcolnum"" <= ""$group1high"" && ""$timecol"" <= ""$group1sqlth"") { print } }" "$myrated"
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group2low"" && ""$popmcolnum"" <= ""$group2high"" && ""$timecol"" <= ""$group2sqlth"") { print } }" "$myrated"
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group3low"" && ""$popmcolnum"" <= ""$group3high"" && ""$timecol"" <= ""$group3sqlth"") { print } }" "$myrated"
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group4low"" && ""$popmcolnum"" <= ""$group4high"" && ""$timecol"" <= ""$group4sqlth"") { print } }" "$myrated"
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group5low"" && ""$popmcolnum"" <= ""$group5high"" && ""$timecol"" <= ""$group5sqlth"") { print } }" "$myrated"
    } >> "$outputfile"
fi
if [[ $timeformat == "epoch" ]] 
then
{
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group1low"" && ""$popmcolnum"" <= ""$group1high"" && ""$timecol"" <= ""$group1epochth"") { print } }" "$myrated"
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group2low"" && ""$popmcolnum"" <= ""$group2high"" && ""$timecol"" <= ""$group2epochth"") { print } }" "$myrated"
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group3low"" && ""$popmcolnum"" <= ""$group3high"" && ""$timecol"" <= ""$group3epochth"") { print } }" "$myrated"
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group4low"" && ""$popmcolnum"" <= ""$group4high"" && ""$timecol"" <= ""$group4epochth"") { print } }" "$myrated"
    awk -F "$mydelimiter" "{ if (""$popmcolnum"" >= ""$group5low"" && ""$popmcolnum"" <= ""$group5high"" && ""$timecol"" <= ""$group5epochth"") { print } }" "$myrated"
    } >> "$outputfile"
fi

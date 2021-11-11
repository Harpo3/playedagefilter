#!/bin/bash
set -e
print_help(){
cat << 'EOF'

A musicbase utility to generate filtered output based on last played values
Usage: playedagefilter.sh [option] FILE POPMCOL TIMECOL

options:
-d specify delimiter (default: ^)
-g specify lastplayed group age thresholds (6 ordered group values, in days, separated by commas)
-h display this help file
-n exclude output file header where input file contains header
-o specify output file and path (default: $HOME/.timefiltered.dsv)
-t use epoch time as numerical date-value type when epoch is type used in FILE (default is sql)

Specify input database FILE of rated tracks, POPMCOL (FILE column number containing POPM values),
and TIMECOL (FILE column number with last played dates expressed as numerical sql or epoch 
time-values)

Uses awk to filter rated-tracks FILE, based on last-played-date, and outputs results to a database file of 
not-recently-played tracks, which can then be used by other tools for playlist creation. Used
when POPM and last-played data are included in the input database.
Recently played tracks, ineligible for playlist inclusion, are filtered out using different 
thresholds. 

Sets five rating groups based on popularimeter (POPM) values, and rating values used by 
Kid3, Windows Media Player, and Winamp:

Group        Rating Stars    POPM      POPM Range Assumed
1            One             1         1-32
2            Two             64        33-96 
3            Three           128       97-160
4            Four            196       161-228
5            Five            255       229-255


Thresholds are set based on repeat frequency needed for a given rating (POPM 
range) group. For example, five star tracks (POPM 239-255) might be repeated every 50 days,
while four star tracks only every 180. So, five star tracks played within the last 50 days
would be filtered out, and so on for other groups. 

Revise group age thresholds for days as needed to make output more or less restrictive; use
comma-separated values, higher age thresholds for lower rated tracks, and vice versa; 
use the '-g' option flag, such as: -g 1525,1430,920,315,190,40 

Default ages by rating group:
last played age threshold (in days):
group1=1460 #(popularimeter 1-32)
group2=910 #(popularimeter 33-96)
group3=305 #(popularimeter 97-160)
group4=180 #(popularimeter 161-228)
group5=50 #(popularimeter 229-255)

The five popularimeter (POPM) high and low ranges may be modified in the script, if needed.

EOF
}
# Rating group last played age (in days):
group1=1460 #(popularimeter 1-32) One Star
group2=910 #(popularimeter 33-96) Two Stars
group3=305 #(popularimeter 97-160) Three Stars
group4=180 #(popularimeter 161-228) Four Stars
group5=50 #(popularimeter 229-255) Five Stars
# POPM low ranges
group1low=1 #(popularimeter 1-32)
group2low=33 #(popularimeter 33-96)
group3low=97 #(popularimeter 97-160)
group4low=161 #(popularimeter 161-228)
group5low=229 #(popularimeter 110-135)
# POPM high ranges
group1high=32 #(popularimeter 1-32)
group2high=96 #(popularimeter 33-96)
group3high=160 #(popularimeter 97-160)
group4high=228 #(popularimeter 161-228)
group5high=255 #(popularimeter 229-255)
#
# Default time value of LastPlayedDate field is numerical SQL time but user may specify "epoch"
timeformat="sql"
mydelimiter="^"
excludeheader="no"
outputfile=$"$HOME/.timefiltered.dsv"
# 
# Use getops to set any user-assigned options
while getopts ":d:g:hno:t" opt; do
  case $opt in
    d)
      mydelimiter=$OPTARG 
      ;;
    g )
      set -f # disable glob
      IFS=',' # split on commas
      array=($OPTARG)
      group1=${array[0]} #(popularimeter 1-32) One Star
      group2=${array[1]} #(popularimeter 33-96) Two Stars
      group3=${array[2]} #(popularimeter 97-160) Three Stars
      group4=${array[3]} #(popularimeter 161-228) Four Stars
      group5=${array[4]} #(popularimeter 229-255) Five Stars  
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

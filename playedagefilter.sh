#!/bin/bash
set -e
print_help(){
cat << 'EOF'

A musicbase utility that filters output based on last played date values; ensures recently played 
tracks are filtered out as ineligible for playlist use.
Usage: playedagefilter.sh [option]

options:
-d specify delimiter (default: ^)
-g specify lastplayed age group thresholds (5 ordered group values, lowest rating age in days
   to highest, and separated by commas, default: 360,180,90,60,30)
-h display this help file
-i specify input file and path (default: $HOME/.popmfiltered.dsv)
-l specify library database containing headers (default: $HOME/.musiclib.dsv)
-n exclude output file header where input file contains header
-o specify output file and path (default: $HOME/.ratingandtime.dsv)
-t use epoch time as numerical date-value type (default is sql)
-u specify POPM low ranges (5 ordered group values, from lowest to highest rated, separated by commas)
   (default: 1,33,97,161,229); used to override defaults and configuration file settings 
-v specify POPM high ranges (5 ordered group values, from lowest to highest rated, separated by commas)
   (default: 32,96,160,228,255); used to override defaults and configuration file settings

Uses awk to filter input file based on last-played-date, and output the results as a database file of
not-recently-played tracks. Used when popularimeter (POPM) and last-played data are included in the 
input file. The purpose is to ensure recently played tracks are filtered out as ineligible for 
playlist use. Output is filtered using thresholds set for each of five POPM rating groups. 

User can specify the input music database (default rated tracks: $HOME/.popmfiltered.dsv). Default values 
can be overridden with option flags shown. Option flags override configuration file settings, if any.

Five utility rating groups are set as defaults, based on a range of POPM values, which 
are aligned with the star rating/POPM values used by Kid3, Windows Media Player, and Winamp:

Group        Rating Stars    POPM      POPM Range Assumed
1            One             1         1-32
2            Two             64        33-96 
3            Three           128       97-160
4            Four            196       161-228
5            Five            255       229-255

Threshold defaults shown below may be modified based on repeat frequency preferred for a given rating 
(POPM range) group. For example, five star tracks (POPM 229-255) might be repeated every 50 days,
while four star tracks only every 180. So, five star tracks played within the last 50 days would be 
filtered out, four star tracks played within the last 180 days, and so on for the other groups. 

Revise group age thresholds (option flag -g) for days as needed to make output more or less restrictive; using
comma-separated values, set higher age thresholds for lower rated tracks, and lower age ones
for higher rated tracks you want to repeat more frequently; example: -g 1525,1430,920,315,190,40 

Default values for lastplayed group age thresholds (in days) by rating group, lowest rated to 
highest, are:
group1=360 #(popularimeter 1-32)
group2=180 #(popularimeter 33-96)
group3=90 #(popularimeter 97-160)
group4=60 #(popularimeter 161-228)
group5=30 #(popularimeter 229-255)

Revise POPM ranges as needed to make output fit the POPM rating scheme for your library.
This can be done with a configuration file or by adding -u and -v option flags to override defaults
and/or configuration file settings (see below).

Custom POPM rating group ranges (and POPM min and max) can be applied globally by creating a local
file $HOME/.musicbase.conf and using this format example (do not add anything else):

group1low=1
group2low=33 
group3low=97 
group4low=161
group5low=229
group1high=32
group2high=96
group3high=160
group4high=228
group5high=255
popmmin=1
popmmax=255

EOF
}
# default variable values that can be stored in config file
# POPM low ranges
group1low=1 #(popularimeter 1-32)
group2low=33 #(popularimeter 33-96)
group3low=97 #(popularimeter 97-160)
group4low=161 #(popularimeter 161-228)
group5low=229 #(popularimeter 229-255)
# POPM high ranges
group1high=32 #(popularimeter 1-32)
group2high=96 #(popularimeter 33-96)
group3high=160 #(popularimeter 97-160)
group4high=228 #(popularimeter 161-228)
group5high=255 #(popularimeter 229-255)
popmmin=1
popmmax=255
popmcolnum=""
timecolnum=""
configfile=$"$HOME/.musicbase.conf"
# If configuration file exists, secure file & override default POPM rating group ranges
if [[ -f "$configfile" ]]
then
    # run security checks on config file and remove any potential malicious code
    # remove any character in file not specific to letters, numbers and equal sign used
    sed -i 's/[^a,c,e,g,h,i,l,m,n,o,p,r,s,t,u,w,x,=,0-9]//g' $configfile
    sed -i -e '/^[^agpt]/d' $configfile # remove all lines with a first letter not a,g,p, or t    
    sed -i -r '/^.{,8}$/d' $configfile # remove all lines that are not 9-17 characters long
    sed -i '/^.\{17\}./d' $configfile   
    sed -i '/=[0-9]/!d' $configfile # remove all lines w/ no equal sign followed by a number 
    . $configfile # override default POPM min and max values using config variable values
fi
# Rating group last played age (in days):
group1=360 # One Star
group2=180 # Two Stars
group3=90 #  Three Stars
group4=60 #  Four Stars
group5=30 #  Five Stars
# Default time value of LastPlayedDate field is numerical SQL time but user may specify "epoch"
timeformat="sql"
mydelimiter="^"
excludeheader="no"
myrated="$HOME/.popmfiltered.dsv"
myrated2="$HOME/.popmfiltered2.dsv"
outputfile=$"$HOME/.ratingandtime.dsv"
musicdb=$"$HOME/.musiclib.dsv"
# Use getops to set any user-assigned options
while getopts ":d:g:hi:l:no:tu:v:" opt; do
  case $opt in
    d)
      mydelimiter=$OPTARG ;;
    g ) 
        set -f # disable glob
        IFS=',' # split on commas
        array1=($OPTARG)
        group1=${array1[0]} #(popularimeter 1-32) One Star
        group2=${array1[1]} #(popularimeter 33-96) Two Stars
        group3=${array1[2]} #(popularimeter 97-160) Three Stars
        group4=${array1[3]} #(popularimeter 161-228) Four Stars
        group5=${array1[4]} #(popularimeter 229-255) Five Stars      
        ;;
    h) 
      print_help
      exit 0;;
    i)      
      myrated=$OPTARG ;;
    l)      
      musicdb=$OPTARG ;;  
    n)
      excludeheader="yes" ;;
    o)      
      outputfile=$OPTARG ;;
    t)      
      timeformat="epoch" ;;
    u) 
      set -f # disable glob
      IFS=',' # split on commas
      array2=($OPTARG)
      group1low=${array2[0]} #(popularimeter 1-32) One Star
      group2low=${array2[1]} #(popularimeter 33-96) Two Stars
      group3low=${array2[2]} #(popularimeter 97-160) Three Stars
      group4low=${array2[3]} #(popularimeter 161-228) Four Stars
      group5low=${array2[4]} #(popularimeter 229-255) Five Stars      
      ;;
    v)
      set -f # disable glob
      IFS=',' # split on commas
      array3=($OPTARG)
      group1high=${array3[0]} #(popularimeter 1-32) One Star
      group2high=${array3[1]} #(popularimeter 33-96) Two Stars
      group3high=${array3[2]} #(popularimeter 97-160) Three Stars
      group4high=${array3[3]} #(popularimeter 161-228) Four Stars
      group5high=${array3[4]} #(popularimeter 229-255) Five Stars      
      ;;
    \?)
      printf 'Invalid option: -%s\n' "$OPTARG"
      exit 1 ;;
    :)
      printf 'Option requires an argument: %s\n' "$OPTARG"
      exit 1  ;;
  esac
done
shift $((OPTIND-1))
#Look up column number for Rating and LastTimePlayed from musicbase db if not stored in config file
if [ -n "$musicdb" ] && [[ $popmcolnum == "" ]] && [[ $timecolnum == "" ]]
then
    popmcolnum=$(echo $(head -1 $musicdb | tr '^' '\n' | cat -n | grep "Rating") | sed -r 's/^([^.]+).*$/\1/; s/^[^0-9]*([0-9]+).*$/\1/')
    timecolnum=$(echo $(head -1 $musicdb | tr '^' '\n' | cat -n | grep "LastTimePlayed") | sed -r 's/^([^.]+).*$/\1/; s/^[^0-9]*([0-9]+).*$/\1/')
fi
popmcolnum2="\$""$popmcolnum"
timecolnum2="\$""$timecolnum"
currepochtime="$(date +%s)"
currsqldec="$(printf "%.6f \n" "$(echo "$currepochtime/86400 + 25569"| bc -l)")"
currsqltime="$(echo ${currsqldec%.*})"
convertfromsql=0
if [[ $timeformat == "sql" ]] 
then
    # sql threshold values
    group1sqlth=$(( currsqltime - group1 ))
    group2sqlth=$(( currsqltime - group2 ))
    group3sqlth=$(( currsqltime - group3 ))
    group4sqlth=$(( currsqltime - group4 ))
    group5sqlth=$(( currsqltime - group5 ))
fi
if [[ $timeformat == "epoch" ]] 
then
    # epoch threshold values
    group1epochth=$(( currepochtime - (group1 * 86400) ))
    group2epochth=$(( currepochtime - (group2 * 86400) ))
    group3epochth=$(( currepochtime - (group3 * 86400) ))
    group4epochth=$(( currepochtime - (group4 * 86400) ))
    group5epochth=$(( currepochtime - (group5 * 86400) ))
    # check source file to determine if sql or epoch is used
    datetest="$(cat $myrated | sed -n '2p')"
    linetxtdate=$(printf '%s\n' "$(echo "$datetest" | cut -f "$timecolnum" -d "^")")
    if [[ "$linetxtdate" == *"."* ]]; then
    convertfromsql=1
    fi
fi
cat /dev/null > "$outputfile"
if [[ $excludeheader == "no" ]] 
then
    awk -F "$mydelimiter" '{if (NR==1) { print }}' "$myrated" > "$outputfile"
fi
if [[ $timeformat == "sql" ]] 
then
    {
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group1low" -v gh="$group1high" -v tcol="$timecolnum" -v sq="$group1sqlth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= sq)) { print }}' "$myrated"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group2low" -v gh="$group2high" -v tcol="$timecolnum" -v sq="$group2sqlth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= sq)) { print }}' "$myrated"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group3low" -v gh="$group3high" -v tcol="$timecolnum" -v sq="$group3sqlth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= sq)) { print }}' "$myrated"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group4low" -v gh="$group4high" -v tcol="$timecolnum" -v sq="$group4sqlth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= sq)) { print }}' "$myrated"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group5low" -v gh="$group5high" -v tcol="$timecolnum" -v sq="$group5sqlth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= sq)) { print }}' "$myrated"
    } >> "$outputfile"
fi
if [[ $timeformat == "epoch" ]] && [[ $convertfromsql == 0 ]]
then
    {
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group1low" -v gh="$group1high" -v tcol="$timecolnum" -v ep="$group1epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group2low" -v gh="$group2high" -v tcol="$timecolnum" -v ep="$group2epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group3low" -v gh="$group3high" -v tcol="$timecolnum" -v ep="$group3epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group4low" -v gh="$group4high" -v tcol="$timecolnum" -v ep="$group4epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group5low" -v gh="$group5high" -v tcol="$timecolnum" -v ep="$group5epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated"
    } >> "$outputfile"
fi
if [[ $timeformat == "epoch" ]] && [[ $convertfromsql == 1 ]]
then
    echo "This will take time for conversion from sql to epoch time"
    cat /dev/null > "$myrated2"
    while read -r line 
    do 
        # epoch is selected and the source file is sql, requiring conversion to epoch        
        valuereplace=$(echo "$line" | cut -f $timecolnum -d "^")
        epochval="$(printf "%.0f \n" "$(echo "($valuereplace-25569)*86400" | bc -l)")"
        #echo "$line"
        #echo "valuereplace $valuereplace epochval $epochval" 
        echo $line > .tmp.txt
        sed "s,$valuereplace,$epochval,g" .tmp.txt >> "$myrated2"
    done < <(tail -n +2 "$myrated")
fi
if [[ $timeformat == "epoch" ]] && [[ $convertfromsql == 1 ]]
then
    {
    # epoch is selected and the source file was converted to epoch    
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group1low" -v gh="$group1high" -v tcol="$timecolnum" -v ep="$group1epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated2"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group2low" -v gh="$group2high" -v tcol="$timecolnum" -v ep="$group2epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated2"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group3low" -v gh="$group3high" -v tcol="$timecolnum" -v ep="$group3epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated2"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group4low" -v gh="$group4high" -v tcol="$timecolnum" -v ep="$group4epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated2"
    awk -F "^" -v pcol="$popmcolnum" -v gl="$group5low" -v gh="$group5high" -v tcol="$timecolnum" -v ep="$group5epochth" '{ if (($pcol >= gl)&&($pcol <= gh)&&($tcol <= ep)) { print }}' "$myrated2"    
    } >> "$outputfile"
fi
rm -f "$myrated2"
rm -f .tmp.txt

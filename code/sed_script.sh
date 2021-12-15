FNAME=$1

if [[ -z $FNAME ]] ; then
  echo 'please enter filename of md5sums to convert to CSV format'
  exit 1
fi

OUTFILENAME=$(echo "$FNAME" | rev | cut -d. -f2- | rev)

sed 's/  /,/g' "$FNAME" > ${OUTFILENAME}.csv
sed -i '1i MD5SUM,FILENAME' ${OUTFILENAME}.csv

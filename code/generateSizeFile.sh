TSTRING=$(date +%H%M_%m%d)

ARR=($(ls . | grep 'fastq.gz$'))

OUTFILENAME=$(echo "fileSizes.${TSTRING}.csv")

echo "Size_in_GB,FileName" >> $OUTFILENAME

for i in "${ARR[@]}" ; do
  du -h -d1 $i | sed -r 's/([[:digit:]])G/\1/g' | sed 's/\t/,/g' >> ${OUTFILENAME}
done
echo "created output file named $OUTFILENAME"

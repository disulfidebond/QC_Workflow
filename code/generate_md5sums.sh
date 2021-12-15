for i in *.fastq.gz ; do
  md5sum ${i} > ${i}.md5
  echo "generated checksum for $i"
  sleep 1
done

cat *.md5 > generated_md5_checksums.txt
sed 's/  /,/g' generated_md5_checksums.txt > generated_md5_checksums.csv
sed -i '1i MD5SUM,FILENAME' generated_md5_checksums.csv

#!/bin/bash
#
# Collates two runs of a scan (of odd and even pages) into a single PDF file
# and OCR text of the content.
#
# TODO: maybe annotate the pdf itself with ocr text
# e.g. see http://blog.konradvoelkel.de/2010/01/linux-ocr-and-pdf-problem-solved/

out="$1"
if [ ! "$out" ]; then out=scan; fi

RES=150
TMP=/tmp/scan.$$
DBG=/dev/null

function on_exit() {
  rm -rf $TMP
}

trap on_exit EXIT

mkdir $TMP
DESTDIR=$(pwd)
PDFOUT="$DESTDIR/$out.pdf"
TXTOUT="$DESTDIR/$out.txt"
cd $TMP

echo "Scanning odd pages..."
scanimage -x 210 -y 297 --batch=odd%03d.tif --format=tiff --resolution $RES 2>$DBG
echo "Flip page stack over to scan even pages in reverse"
echo "Then press ENTER to continue"
read dummy
echo "Scanning even pages..."
scanimage -x 210 -y 297 --batch=evn%03d.tif --format=tiff --resolution $RES 2>$DBG
echo

ordered_pages=$(paste -d '\n' <(ls odd*.tif | sort) <(ls evn*.tif | sort -r))

echo "Creating $out.pdf ..."
convert -compress jpeg -quality 50 $ordered_pages "$PDFOUT"

echo -n "Creating OCR $out.txt ... page"
p=1
for page in $ordered_pages; do
  echo -n " $p"
  tesseract $page $page >$DBG 2>&1
  echo -e "\n======= OCR PAGE $p =======\n" >> scan.txt
  p=$(expr $p + 1)
  cat $page.txt >> scan.txt
done
mv scan.txt "$TXTOUT"

echo

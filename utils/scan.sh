#!/bin/bash
#
# Collates two runs of a scan (of odd and even pages) into a single PDF file
# and OCR text of the content.
#
# TODO: maybe annotate the pdf itself with ocr text
# e.g. see http://blog.konradvoelkel.de/2010/01/linux-ocr-and-pdf-problem-solved/

DBG=/dev/null
RES=150
MODE=2
QUALITY=50
SOURCE='brother4:net1;dev0'

function log() {
  echo $@ 1>&2
}

function usage() {
  (
    echo "usage: scan.sh [args] [file-prefix]"
    echo "       -m mode     2=double sided (default), 1=single sided, f=flatbed"
    echo "       -r res      resolution in DPI (default $RES)"
    echo "       -j quality  jpeg quality (default $QUALITY)"
    echo "       -s source   scan source (default $SOURCE)"
    echo "       -d file     send subcommand stderr streams to file"
  ) 1>&2
  exit 1
}

while true; do
  case "$1" in
    -m)
      shift
      case "$1" in
        1|2|f) MODE=$1; shift;;
        *) log "Unrecognized mode: '$1'"; exit 1;;
      esac
      ;;
    -r) shift; RES="$1"; shift;;
    -d) shift; DBG="$1"; shift;;
    -*) usage;;
    *) break;;
  esac
done

out="$1"
if [ ! "$out" ]; then out=scan; fi

TMP=/tmp/scan.$$
scana4="scanimage -d $SOURCE -x 210 -y 297 --format=tiff --resolution $RES"

function on_exit() {
  rm -rf $TMP
}

trap on_exit EXIT

mkdir $TMP
DESTDIR=$(pwd)
PDFOUT="$DESTDIR/$out.pdf"
TXTOUT="$DESTDIR/$out.txt"
cd $TMP

case $MODE in
1)
  echo "Scanning pages..."
  $scana4 --batch=p%03d.tif 2>$DBG
  ordered_pages=$(ls p*.tif | sort)
  ;;
2)
  echo "Scanning odd pages..."
  $scana4 --batch=odd%03d.tif 2>$DBG
  echo "Flip page stack over to scan even pages in reverse"
  echo "Then press ENTER to continue"
  read dummy
  echo "Scanning even pages..."
  $scana4 --batch=evn%03d.tif 2>$DBG
  echo
  ordered_pages=$(paste -d '\n' <(ls odd*.tif | sort) <(ls evn*.tif | sort -r))
  ;;
f)
  echo "Place first page on flatbed and press ENTER"
  p=1
  while read dummy; do
    f=p$p.tif
    ordered_pages="$ordered_pages $f"
    $scana4 --source FlatBed 2>$DBG > $f
    p=$(expr $p + 1)
    echo "Place next page on flatbed and press ENTER, or Ctrl+D to finish"
  done
  ;;
esac

echo "Creating $out.pdf ..."
convert -compress jpeg -quality $QUALITY $ordered_pages "$PDFOUT"

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

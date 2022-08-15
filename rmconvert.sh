#! /usr/bin/zsh
# ------------------------------------------------------------------------
# Converts reMarkable documents into annotated PDFs, with options to
# adjust the output.
# 
# (C) 2022 Sylvain Hallé <shalle@acm.org>
#
# Annotated PDFs in the reMarkable are stored as a set of files
# in a format specific to the tablet. It is possible to retrieve these
# raw files in a few ways:
#
# - By downloading them from the reMarkable cloud using rmapi:
#   https://github.com/juruen/rmapi
# - By connecting to the tablet directly through SFTP:
#   https://remarkablewiki.com/tech/ssh
#
# Usage: rmconvert.sh [options] <inputfile>
# 
# -c XXX  Set ink color to XXX (can be a hex color or a CSS color
#         name); default is blue
# -w X    Set document width to X points
# -h X    Set document height to X points
# -s X    Set stroke width to X points (default 0.87)
# -r      Color the margin of pages containing annotations
# -p      Make original text paler to highlight annotations
# -o file Output PDF to file (default is inputfile.pdf)
# 
# Requirements
#
# To convert the zip file to an annotated PDF:
# 
# - ImageMagick (package `imagemagick`)
# - PDFtk (package `pdftk`)
# - rsvg-convert (package `librsvg2-dev`)
# - unzip and sed (should already be present)
# - rM2svg (https://github.com/reHackable/maxio)
# ------------------------------------------------------------------------

# The location of the rM2svg executable. Modify if necessary to fit the path
RM2SVG=rM2svg

# The default width and height of the input document. It is expressed in
# points (72 pt = 1 inch).
DOC_W=""
DOC_H=""

# Whether margins of annotated pages should be highlighted with a colored
# rectangle
COLOR_MARGINS=false

# Whether to make the text paler to highlight the annotations
PALE_TEXT=false

# The ink color; an empty string means no change
INK_COLOR=""

# The stroke width; an empty string means no change
STROKE_WIDTH=""

# Function to clean up temp dir if script is aborted
TRAPINT() {
  print "Caught SIGINT, aborting."
  rm -rf $WORKDIR
  return $(( 128 + $1 ))
}

# Print script usage to the standard output
showhelp() {
  echo -e
  echo "Usage: rmconvert.sh [options] <inputfile>"
  echo -e
  echo "  -c XXX  Set ink color to XXX (can be a hex color or a CSS color name); default is blue"
  echo "  -w X    Set document width to X points"
  echo "  -h X    Set document height to X points"
  echo "  -s X    Set stroke width to X points (default 0.87)"
  echo "  -r      Color the margin of pages containing annotations"
  echo "  -p      Make original text paler to highlight annotations"
  echo "  -o file Output PDF to file (default is inputfile.pdf)"
}

# Greeting
echo "reMarkable output converter v1.0"
echo "(C) 2022 Sylvain Hallé <shalle@acm.org>"

# Parse command line arguments
toadd=""
input_file=""
OUTPUT_FILE=""
while [ "$#" -gt 0 ]
do
	case $1 in
	-r)     toadd="";
		    COLOR_MARGINS=true;;
	-p)     toadd="";
		    PALE_TEXT=true;;
	-w)     toadd="w";;
	-h)     toadd="h";;
	-c)     toadd="c";;
	-o)     toadd="o";;
	-s)     toadd="s";;
	--help) toadd="";
		    showhelp;
		    exit 0;;
	*) case $toadd in
		w) DOC_W=$1;
		   toadd="";;
		h) DOC_H=$1
		   toadd="";;
		c) INK_COLOR=$1;
		   toadd="";;
		o) OUTPUT_FILE=$1;
		   toadd="";;
		s) STROKE_WIDTH=$1;
		   toadd="";;
		*) input_file=$1
		esac
	esac
	shift;
done

# Get base name of archive (filename without path and extension)
if [ ! -f $input_file ]
then
	echo File not found: $input_file
	exit 1
fi
#if [[ -d $input_file ]]
#then
	# Input argument is a folder
#	$BASE=$input_file
#	full_pdf_document=$input_file/$input_file.pdf
	#TODO
#else
	# Input argument is an archive
	base_archive=${$(basename $input_file):r}
	echo Input archive: $base_archive.zip
	# Unzip archive to temp folder
	WORKDIR=$(mktemp -d)
	unzip -q $input_file -d $WORKDIR
	# Find ID of document
	full_pdf_document=$(ls $WORKDIR/*.pdf)
	pdf_document=$(basename $full_pdf_document)
	BASE=${pdf_document:r}

# Determine output filename
if [[ -z $OUTPUT_FILE ]]
then
	OUTPUT_FILE=$base_archive.pdf
fi

# Get page dimensions from PDF
dimstring=$(pdfinfo $full_pdf_document | grep 'Page size')
if [[ -z $DOC_W ]]
then
	DOC_W=${dimstring[(w)3]}
fi
if [[ -z $DOC_H ]]
then
	DOC_H=${dimstring[(w)5]}
fi

# Count pages in the PDF
numpages=$(pdftk $full_pdf_document dump_data | grep NumberOfPages | awk '{print $2}')

# Create a blank PDF page with the document's dimensions
convert xc:none -page {$DOC_W}x{$DOC_H} $WORKDIR/$BASE/blank.pdf

# Iterate through pages
for p in {0..$numpages}
do
	# If there exists an rm file for the current page...
	if [[ -f $WORKDIR/$BASE/$p.rm ]]
	then
		# Convert rm file to SVG using rM2svg
		$RM2SVG --height $DOC_H --width $DOC_W -c -i $WORKDIR/$BASE/$p.rm -o $WORKDIR/$BASE/pg-$p > /dev/null
		# Change opacity of lines in SVG from 0 to 1 to make them visible
		sed -i 's/opacity:0.0/opacity:1/g' $WORKDIR/$BASE/pg-$p
		# Append a rectangle in the page margin
		if $COLOR_MARGINS
		then
			sed -i "s/<\/svg>/<rect style=\"opacity:1;fill:blue;fill-opacity:1;stroke:none\" id=\"foorect\" width=\"10\" height=\"$DOC_H \" x=\"0\" y=\"0\" \/><\/svg>/g" $WORKDIR/$BASE/pg-$p
		fi
		# Overlay a translucent rectangle
		if $PALE_TEXT
		then
			sed -i "s/><polyline/><rect style=\"opacity:1;fill:white;fill-opacity:0.5;stroke:none\" id=\"overlay\" width=\"$DOC_W \" height=\"$DOC_H \" x=\"0\" y=\"0\" \/><polyline/" $WORKDIR/$BASE/pg-$p
		fi
		# Change ink color
		if [[ -n $INK_COLOR ]]
		then
			sed -i "s/blue/$INK_COLOR/g" $WORKDIR/$BASE/pg-$p
		fi
		# Change stroke width
		if [[ -n $STROKE_WIDTH ]]
		then
			sed -i "s/stroke-width:0.870/stroke-width:$STROKE_WIDTH/g" $WORKDIR/$BASE/pg-$p
		fi
		# Convert SVG to PDF with the current page number
		rsvg-convert -f pdf -o $WORKDIR/$BASE/pg-${(l(3)(0))p}.pdf $WORKDIR/$BASE/pg-$p
	else
		# Otherwise, create a copy of the blank PDF page and give it the
		# current page number
		cp $WORKDIR/$BASE/blank.pdf $WORKDIR/$BASE/pg-${(l(3)(0))p}.pdf
	fi
done

# Merge pages into a single PDF
pdftk $WORKDIR/$BASE/pg-*.pdf cat output $WORKDIR/$BASE/annotations.pdf

# Stamp original PDF with annotations
pdftk $full_pdf_document multistamp $WORKDIR/$BASE/annotations.pdf output $OUTPUT_FILE

# Remove temp folder
rm -rf $WORKDIR

echo "Output file:   $OUTPUT_FILE"
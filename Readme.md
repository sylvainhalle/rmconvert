rmConvert
=========

This repository contains a shell script that converts reMarkable documents into
annotated PDFs, with options to adjust the output.

Annotated PDFs in the reMarkable are stored as a set of files
in a format specific to the tablet. It is possible to retrieve these
raw files in a few ways:

- By downloading them from the reMarkable cloud using rmapi:
  https://github.com/juruen/rmapi
- By connecting to the tablet directly through SFTP:
  https://remarkablewiki.com/tech/ssh

Usage: rmconvert.sh [options] <inputfile>

`-c XXX`  Set ink color to XXX (can be a hex color or a CSS color name); default is blue
        	
`-w X`    Set document width to X points

`-h X`   Set document height to X points

`-s X`    Set stroke width to X points (default 0.87)

`-r`      Color the margin of pages containing annotations

`-p`      Make original text paler to highlight annotations

`-o` file Output PDF to file (default is inputfile.pdf)

Requirements
------------

To convert the zip file to an annotated PDF:

- ImageMagick (package `imagemagick`)
- PDFtk (package `pdftk`)
- rsvg-convert (package `librsvg2-dev`)
- unzip and sed (should already be present)
- rM2svg (https://github.com/reHackable/maxio)
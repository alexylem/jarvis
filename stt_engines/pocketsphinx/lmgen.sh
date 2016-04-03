#!/bin/bash
# Copyright (c) 2014-Present, Scott Cagno
# All rights reserved. [BSD License]

# ------------------------------------------
# THIS BASH SCRIPT UPLOADS A CORPUS FILE TO 
# THE CMU ONLINE LANGUAGE MODELING GENERATOR.
# IT WILL RETURN AND STAGE THE GENERATED 
# LANGUAGE MODEL AND DICTIONARY FILES IN THE
# SPECIFIED DIRECTORY (LANGDIR).
# ------------------------------------------

# COMMAND LINE ERROR HANDLING
if [[ $# -ne 1 ]]; then
    echo "usage: $0 <corpus>"
    exit
fi

# BINARY LANGUAGE MODEL CONVERTER (DEPENDENCY)
if [[ ! -x `which sphinx_lm_convert` ]]; then 
    echo "**warning: 'sphinx_lm_convert' is not installed."
    exit
fi

# DIRECTORY WHERE THE RETURNED LANGAUGE FILES WILL BE STAGED
LANGDIR="."

# LANGUAGE/VOCAB CORPUS FILE
CORPUS=$1

# SETUP URL 
URL="http://www.speech.cs.cmu.edu"

# MAKE HTTP POST REQUEST TO UPLOAD VOCAB.CORPUS FILE. (SAVE HTTP RESPONSE IN $RES VAR)
echo ":: uploading $CORPUS..."
RES=`curl -sL -H "Content-Type: multipart/form-data" -F "corpus=@$CORPUS" -F "formtype=simple" $URL/cgi-bin/tools/lmtool/run/` 

# ECHO THE CONTENTS OF THE SAVED HTTP RESPONSE, PARSE OUT THE UNIQUE REFERENCES URL. (SAVE IN $REF)
echo ":: getting unique download reference url..."
REF=`echo $RES | grep -oE 'title[^<>]*>[^<>]+' | cut -d'>' -f2 | sed -e "s/Index of//g" | tr -d ' '`

# ECHO THE CONTENTS OF THE SAVED HTTP RESPONSE, PARSE OUT THE UNIQUE SERIAL ID. (SAVE IN $SID)
echo ":: getting unique reference id..."
SID=`echo $RES | grep -oE 'b[^<>]*>[^<>]+' | cut -d'>' -f2 | awk '/[0-9]/ { print $0 }' | head -1`

# MAKE HTTP GET REQUEST TO DOWNLOADS THE GENERATED LANGUAGE FILES.
echo ":: downloading results [$URL$REF/TAR$SID.tgz]..." 
curl -sO $URL$REF/TAR$SID.tgz

# UNPACK AND CLEANUP TARBALL.
echo ":: unpacking..."
tar zxf TAR$SID.tgz
rm TAR$SID.tgz

# STAGE IMPORTANT FILES IN SPECIFIED $LANGDIR 
echo ":: staging..."
mv $SID.dic $LANGDIR/$CORPUS.dic
mv $SID.lm $LANGDIR/$CORPUS.lm

# CONVERT LM TO DMP (BINARY LM FORMAT)
echo ":: doing binary lm to dmp conversion..."
sphinx_lm_convert -i $CORPUS.lm -o $CORPUS.dmp > /dev/null 2>&1

# CLEAN UP THE REMAINING UNWANTED FILES.
echo ":: cleaning up..."
rm $SID.*

# FINISHED
echo ":: done."

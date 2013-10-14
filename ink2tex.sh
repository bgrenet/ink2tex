#! /bin/bash

usage="Usage: $(basename $0) [OPTIONS] [file1.svg|dir1] [file2.svg|dir2] [...]"

if [ $(which inkscape 2>/dev/null) ]; 
then 
    echo "Inkscape is required!"; 
    exit 1; 
fi

inkscape=inkscape

force=0
log=0
samedir=0
outdir=""
outpdf=0
outps=0
outeps=0
nosvgtex=0
black=0
verbose=0
debug=0
dpi=90
layers=0

helpmsg="$(basename $0): SVG to [PDF|PS|EPS]+LaTeX using Inkscape.

$usage

No argument is equivalent to option -h.
Several FILES and DIRECTORIES can be treated in the same time.
If a DIRECTORY is passed as argument, all the SVG files it contains are converted.

OPTIONS:
-h,--help               Print this message.
-f,--force              Re-generate all files, even when SVG file is not modified.
--log                   Write the names of the successfuly treated files in `basename $0 .sh`.log
--pdf,--ps,--eps        Choose PDF, PS or EPS output format. Several output formats possible.
                        Default is to output the three formats.
-d,--dpi=VALUE          Set the dpi resolution. Default is 90.
--nosvgtex              Do not replace [pdf|ps|eps]_tex files by a svg_tex file.
                        With this option, if the svg file has no text, no *_tex is produced.
-l,--layers=NUMBER      Multi-export NUMBER layers, named layer1 to layerNUMBER. File names are File-1.ext to File-NUMBER.ext.
-b,--black              Remove the \color commands in svg_tex. No effect with --nosvgtex.
-u,--unique-directory   All files are produced in the same directory, given by -o option. This is default.
-i,--in-place           Each file is produced where the SVG source is, in the subdirectory given by -o option. Incompatible with -u.
-o,--output=OUTDIR      All files are produced in directory OUTDIR. 
                        With -u, default is the current directory.
                        With -i, default is \"tex\".
-v,--verbose            Print extra informations.
--debug                 Print the command line used.
"

# Options
while getopts ":o:d:fliuhbv-:" OPT; do
    if [ $OPT = "-" ] ; then
        LONGOPT="${OPTARG%%=*}"
        OPTARG="${OPTARG#*=}"
        case $LONGOPT in
            output) OPT="o" ;;
            force) OPT="f" ;;
            layers) OPT="l" ;;
            log) log=1; loglist=""; logfile=`basename $0 .sh`.log ;;
            in-place) OPT="i" ;;
            unique-directory) OPT="u" ;;
            pdf) outpdf=1;;
            ps) outps=1;;
            eps) outeps=1;;
            dpi) OPT="d";;
            nosvgtex) nosvgtex=1;;
            debug) debug=1;;
            black) OPT="b";;
            verbose) OPT="v";;
            help) OPT="h" ;;
            *) echo $usage ; exit 1 ;;
        esac
    fi 
    case $OPT in
        f) force=1 ;;
        l) layers=$OPTARG;;
        o) outdir=$OPTARG;; # affoutdir="${OPTARG%/}/" ;;
        i) samedir=1 ;;
        u) samedir=0 ;;
        d) dpi=$OPTARG;;
        b) black=1 ;;
        v) verbose=1 ;;
        h) echo "$helpmsg"; exit 0 ;;
        -) ;;
        *) echo $usage; exit 1 ;;
    esac
done

if [ $debug -eq 1 ];
then
    echo "$(basename $0) $*"
fi

shift $((OPTIND-1))

# Output format

if [ $outpdf -eq 0 ] && [ $outps -eq 0 ] && [ $outeps -eq 0 ];
then
    outpdf=1
    outps=1
    outeps=1
fi

# Output directory

if [ ${#outdir} -eq 0 ]; then
    if [ $samedir -eq 0 ]; then outdir='.';
    else  outdir="tex"; fi
fi

nonsvg=""
list=""

# Test arguments

# 1. No args = help # OLD: current directory
if [ $# -eq 0 ]; then 
    # OLD: list=$(ls *.svg);
    echo "$helpmsg"; exit 1;
else
    for arg in $*; do

# 2. If arg is a file: test whether it is a svg file or not
        if [ -f $arg ]; then
            if [ "${arg##*.}" = "svg" ]; then list+=" $arg";
                                         else nonsvg+=" $arg";
            fi

# 3. If arg is a directory: find all svg files in it
        elif [ -d $arg ]; then list+=" $(ls $arg/*svg)";
        fi
    done
fi

if [ $verbose -eq 1 ]; then echo -n "*** Exporting SVGs to TeX; "; fi

# Ready to do the job for each svg file
for svg in $list; do
    latex=""                    # Choose LaTeX export or not
    basesvg=$(basename $svg)    # Basename of the current SVG file
    currentLayer=0
  while [ $currentLayer -lt $layers ] || [ $(($layers+$currentLayer)) -eq 0 ]; do
    currentLayer=$(($currentLayer+1))
    if [ $layers -le 1 ]; then
        filename=${basesvg%.svg}
        layerOpt=""
    else
        filename=${basesvg%.svg}-$currentLayer
        layerOpt="-i layer$currentLayer"
    fi
    pdf=$filename".pdf"         # Name of the produced PDF file
    ps=$filename".ps"           # Name of the produced PS file
    pdftex=$pdf"_tex"           # Name of the PDF_TEX file Inkscape creates
    eps=$filename".eps"         # Name of the produced EPS file
    pstex=$ps"_tex"             # Name of the PS_TEX file Inkscape creates
    epstex=$eps"_tex"           # Name of the EPS_TEX file this script creates
    svgtex=$filename".svg_tex"  # Name of the SVG_TEX file this script creates
    svgtexcreated=0             # 1 iff the .svg_tex was already created
    treated=0                   # 1 iff the svg file has been treated at least once
    if [ $samedir -eq 1 ]; then
        dir=$(dirname $svg)
    else 
        dir="."
    fi
    
# Output directory is created if needed
    if [ ! -e $dir/$outdir ]; then mkdir $dir/$outdir; fi

# If there is some text, use LaTeX export (useless if no text!)
    if [ -n "$(grep 'id="text' $svg)" ]; then latex="--export-latex"; fi

# Export first in PS+LaTeX 
    if [ $outps -eq 1 ] || [ $outeps -eq 1 ]; then
# Produced iff the svg file has changed
        if [ $force -eq 1 ] || [ $svg -nt $dir/$outdir/$ps ] || [ $svg -nt $dir/$outdir/$svgtex ]; then
# Call inkscape with the right parameter!
            $inkscape -C -z --export-dpi=$dpi --file=$svg --export-ps=$dir/$outdir/$ps $latex $layerOpt
            if [ $verbose -eq 1 ]; then echo -n "$svg, "; fi
            treated=1
# If no LaTeX export, create a fake PS_TEX file (unless -nosvgtex option is passed)
            if [ $nosvgtex -eq 0 ]; then
                if [ ${#latex} -eq 0 ]; then 
                    echo "\\ifx\svgwidth\undefined" > $dir/$outdir/$pstex ; 
                    echo "\\includegraphics{$ps}" >> $dir/$outdir/$pstex ; 
                    echo "\\else" >> $dir/$outdir/$pstex ; 
                    echo "\\includegraphics[width=\\svgwidth]{$ps}" >> $dir/$outdir/$pstex ; 
                    echo "\\fi" >> $dir/$outdir/$pstex ; 
                    echo "\\global\\let\\svgwidth\\undefined" >> $dir/$outdir/$pstex ; 
                fi
# Create the .svg_tex file (no test since it is the first time
                sed -e "s/\(\\includegraphics.*\){$ps}/\1{${ps%.ps}}/" -e "/^%%/d" -e "/^$/d" $dir/$outdir/$pstex > $dir/$outdir/$svgtex
                svgtexcreated=1
                rm $dir/$outdir/$pstex
            fi
        fi
    fi
    
# Convert PS file to EPS
    if [ $outeps -eq 1 ]; then
        if [ $force -eq 1 ] || [ $svg -nt $dir/$outdir/$eps ] || [ $svg -nt $dir/$outdir/$epstex ]; then
            ps2eps --resolution=$dpi -f $dir/$outdir/$ps 2> /dev/null; 

# Copy BoundingBox from ps to eps 
# /!\ This does not respect EPS specifications, but this /seems/ to work with LaTeX
            bb=$(grep "^%%BoundingBox:" $dir/$outdir/$ps | cut -d: -f2 | cut -d" " -f2-)
            bb1=$(echo $bb | cut -d" " -f1).000000
            bb2=$(echo $bb | cut -d" " -f2).000000
            bb3=$(echo $bb | cut -d" " -f3).000000
            bb4=$(echo $bb | cut -d" " -f4).000000
            sed -i -e "s/^%%BoundingBox: .*/%%BoundingBox: $bb/" -e "s/^%%HiResBoundingBox: .*/%%HiResBoundingBox: $bb1 $bb2 $bb3 $bb4/" $dir/$outdir/$eps
            treated=1

# If -nosvgtex option and there is text is the svg file (= ps_tex exists), produce an eps_tex
            if [ $nosvgtex -eq 1 ] && [ -e $dir/$outdir/$pstex ]; then
                sed -e "s/\(\\includegraphics.*\){$ps}/\1{$eps}/" $dir/$outdir/$pstex > $dir/$outdir/$epstex
            fi
        fi
# If no --ps option, rm .ps and .ps_tex files
        if [ $outps -eq 0 ]; then rm -f $dir/$outdir/$ps $dir/$outdir/$pstex; fi
    fi

# Export in PDF+LaTeX
    if [ $outpdf -eq 1 ]; then
        if [ $force -eq 1 ] || [ $svg -nt $dir/$outdir/$pdf ] || [ $svg -nt $dir/$outdir/$svgtex ]; then
# Call inkscape
            $inkscape -C -z --export-dpi=$dpi --file=$svg --export-pdf=$dir/$outdir/$pdf $latex $layerOpt
# If no LaTeX export, create a fake PDF_TEX file (unless -nosvgtex option is passed)
            if [ $nosvgtex -eq 0 ]; then
                if [ ${#latex} -eq 0 ]; then
                    echo "\\ifx\svgwidth\undefined" > $dir/$outdir/$pdftex ; 
                    echo "\\includegraphics{$pdf}" >> $dir/$outdir/$pdftex ; 
                    echo "\\else" >> $dir/$outdir/$pdftex ; 
                    echo "\\includegraphics[width=\\svgwidth]{$pdf}" >> $dir/$outdir/$pdftex ; 
                    echo "\\fi" >> $dir/$outdir/$pdftex ; 
                    echo "\\global\\let\\svgwidth\\undefined" >> $dir/$outdir/$pdftex ; 
                fi
# Create .svg_tex file. Test whether it has already been created or not!
                if [ $treated -eq 0 ]; then
                    sed -e "s/\(\\includegraphics.*\){$pdf}/\1{${pdf%.pdf}}/" -e "/^%%/d" -e "/^$/d" $dir/$outdir/$pdftex > $dir/$outdir/$svgtex
                fi
                rm $dir/$outdir/$pdftex
                if [ $verbose -eq 1 ] && [ $treated -eq 0 ]; then echo -n "$svg, "; fi
                treated=1
            fi
# Turn PDF-1.5 to PDF-1.4, for compatibility with pdfLaTeX
            gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$dir/$outdir/$pdf-1.4 $dir/$outdir/$pdf
            rm $dir/$outdir/$pdf
            mv $dir/$outdir/$pdf-1.4 $dir/$outdir/$pdf
        fi
    fi

# Create the SVG_TEX file from PS_TEX or PDF_TEX, and removes PDF_TEX and PS_TEX
# Note that useless commented or empty lines are removed, to shrink the file's size.
    if [ $nosvgtex -eq 0 ]; then
##        if [ -e $dir/$outdir/$pstex ]; then
##            sed -e "s/\(\\includegraphics.*\){$ps}/\1{${ps%.ps}}/" -e "/^%%/d" -e "/^$/d" $dir/$outdir/$pstex > $dir/$outdir/$svgtex
##        elif [ -e $dir/$outdir/$epstex ]; then
##            sed -e "s/\(\\includegraphics.*\){$eps}/\1{${eps%.eps}}/" -e "/^%%/d" -e "/^$/d" $dir/$outdir/$epstex > $dir/$outdir/$svgtex
##        elif [ -e $dir/$outdir/$pdftex ]; then
##            sed -e "s/\(\\includegraphics.*\){$pdf}/\1{${pdf%.pdf}}/" -e "/^%%/d" -e "/^$/d" $dir/$outdir/$pdftex > $dir/$outdir/$svgtex
##        fi
# If --black option: remove the \color commands
        if [ $black -eq 1 ]; then
            sed -i -e 's/\\color\[rgb\]{[^}]*}//' $dir/$outdir/$svgtex
        fi
##        rm -f $dir/$outdir/$pstex $dir/$outdir/$epstex $dir/$outdir/$pdftex
    fi


# Write the log list
    if [ $log -eq 1 ] && [ $treated -eq 1 ]; then
        loglist+=" $svg"
    fi
  done
done

if [ $verbose -eq 1 ]; then echo -e "\b\b \b"; fi

# Write the log file
if [ $log -eq 1 ]; then
    echo $loglist > $logfile
fi

# If some Non-SVG files were given as argument, report that nothing was done
if [ ${#nonsvg} -gt 0 ]; then echo "Non-SVG files ignored:$nonsvg"; fi      

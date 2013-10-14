ink2tex
=======

SVG to [PDF|PS|EPS] + LaTeX using Inkscape

###Usage


`ink2tex [OPTIONS] [file1.svg|dir1] [file2.svg|dir2] [...]`

###Options

No argument is equivalent to option `-h`.  
Several `FILES` and `DIRECTORIES` can be treated in the same time.  
If a `DIRECTORY` is passed as argument, all the SVG files it contains are converted.  


    -h,--help               Print this message.
    -f,--force              Re-generate all files, even when SVG file is not modified.
    --log                   Write the names of the successfuly treated files in `basename $0 .sh`.log
    --pdf,--ps,--eps        Choose PDF, PS or EPS output format. Several output formats possible.
                            Default is to output the three formats.
    -d,--dpi=VALUE          Set the dpi resolution. Default is 90.
    --nosvgtex              Do not replace [pdf|ps|eps]_tex files by a svg_tex file.
                            With this option, if the svg file has no text, no *_tex is produced.
    -l,--layers=NUMBER      Multi-export NUMBER layers, named layer1 to layerNUMBER. 
                            File names are File-1.ext to File-NUMBER.ext.
    -b,--black              Remove the \color commands in svg_tex. No effect with --nosvgtex.
    -u,--unique-directory   (Default) All files are produced in the same directory, given by -o option.
    -i,--in-place           Each file is produced where the SVG source is, in the subdirectory given by -o option. 
                            Incompatible with -u.
    -o,--output=OUTDIR      All files are produced in directory OUTDIR. 
                            With -u, default is the current directory.
                            With -i, default is \"tex\".
    -v,--verbose            Print extra informations.
    --debug                 Print the command line used. 
 
 **Note for option `--layers`:** You need to define several layers with the names layers1, layers2, etc. It does not work (yet) with arbitrary names.

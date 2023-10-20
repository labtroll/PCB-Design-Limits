#!/bin/bash
# Shell script to generate Gerber and drill Files satisfying JLCPCB requirements.
# Syntax:
# jlcgerber <project>
# - <project> can be project directory or project.kicad_pcb file
# - gerber and drill files will be generated in the current directory
# - a zip file will be created (in the current directory) containing all gerber files

# TODO
# option -h --help: display syntax help
# option -r: pack in zip archive and remove gerber files
# Support for pcbs with >2 layers (--layers).
#	Inner layer names default to "In1.Cu", "In2.Cu", ...
#   If specified in --layers, gerber files are generated even if layer is not defined
#   (e.g. 'Project-In1_Cu.g2', 'Project-In2_Cu.g3').

project_or_pcbfile="$1"
if test -f "$project_or_pcbfile"
then
	pcbfile="$project_or_pcbfile"
else
	pcbfile="${project_or_pcbfile}.kicad_pcb"
fi

if ! test -f "$pcbfile"
then
	>&2 echo "ERROR: $pcbfile does not exist"
	exit 2
fi

basefile=$(basename "${pcbfile}" .kicad_pcb) # remove path segments and suffix
zipfile="${basefile}.zip"
gbrpattern="${basefile}-*.g??"
drlpattern="${basefile}-*.drl"

echo "Generating gerber and drill files from $pcbfile to zip archive $zipfile"

if test -n "$(find . -name "$gbrpattern" -maxdepth 1)"
then
	echo "Removing old gerber files ($gbrpattern)"
	rm $gbrpattern
fi

if test -n "$(find . -name "$drlpattern" -maxdepth 1)"
then
	echo "Removing old drill files ($drlpattern)"
	rm $drlpattern
fi


echo "Generating gerber files from $pcbfile"
kicad-cli pcb export gerbers --layers F.Cu,B.Cu,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts --exclude-value --no-x2 --no-netlist --subtract-soldermask --disable-aperture-macros "$pcbfile"
# no way to avoid generating "*-job.gbrjob" file
rm "${basefile}-job.gbrjob"

echo "Generating drill files from $pcbfile"
kicad-cli pcb export drill --format excellon --drill-origin absolute --excellon-zeros-format decimal --excellon-oval-format alternate --excellon-units mm --excellon-separate-th --generate-map --map-format gerberx2 "$pcbfile"

if test -f "$zipfile"
then
	echo "Removing old zip archive $zipfile"
	rm $zipfile
fi

echo "Creating new zip archive $zipfile"
# -m option removes source files as they are added to archive
# Consider using -9 for best compression (difference btw default -6 and -9 is 0.5%)
zip -omq "$zipfile" $gbrpattern $drlpattern

echo # Blank line before listing zip file contents
echo "Zip archive path: $(realpath "$zipfile")"
unzip -lv "$zipfile"

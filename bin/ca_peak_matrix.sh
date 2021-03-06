#!/bin/bash

# This script reads many bedtools coverage peak output files and outputs
# them in matrixmarket format. See ca_top_regions.sh for more comments.

set -euo pipefail

peakbedfile=
filelist=
cellnames=
force=false
prefix=


while getopts :c:i:p:x:Fh opt
do
    case "$opt" in
    c)
      cellnames=$OPTARG
      ;;
    i)
      filelist=$OPTARG
      ;;
    p)
      peakbedfile=$OPTARG
      ;;
    x)
      prefix=$OPTARG
      ;;
    F)
      force=true
      ;;
    h)
      cat <<EOU
-c cell ID file (barcodes usually; one id per line)
-i file with file locations inside, one file per line, full path name
EOU
      exit
      ;;
    :) echo "Flag $OPTARG needs argument"
        exit 1;;
    ?) echo "Flag $OPTARG unknown"              # Yes that's right, $OPTARG. bash bish bosh.
        exit 1;;
   esac
done

if [[ -z $filelist || -z $peakbedfile ]]; then
   echo "Need -i filelistfile and -p peak bed file! (see -h)"
   false
fi


ca_region_maketab.sh $peakbedfile __peak.tab

nl -v0 -nln -w1 < $cellnames > __cell.tab

cut -f 2 __peak.tab > peaks.txt
cut -f 2 __cell.tab > cells.txt         # will be identical to $cellnames.


export MCLXIOFORMAT=8   # force native binary format, it's 20-30 times faster.

# # ###################################
 #  Stream all files for matrix loading
#   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
if $force || [[ ! -e peak2cell.mcx ]]; then

  while read f; do

    g=${f##*/}
    export b=${g%.mp.txt}

    perl -ane 'local $"="_"; print "$F[0]:$F[1]-$F[2]\t$ENV{b}\t$F[3]\n"' $f

  done < "$filelist" | mcxload \
          --stream-split -abc - -strict-tabr __cell.tab -strict-tabc __peak.tab --write-binary -o peak2cell.mcx
else
>&2 echo "Reusing peak2cell.mcx"
fi


mcx query -imx peak2cell.mcx -o peak2cell.stats -tab __peak.tab
n_entries=$(tail -n +2 peak2cell.stats | perl -ane '$S+=$F[1]; END{print "$S\n";}')


# # #############################
 #  Output to matrixmarket format
#   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

mx_p2c=peaks_bc_matrix.mmtx.gz
mx_c2p=bc_peaks_matrix.mmtx.gz
ca_make_mmtx.sh -r peaks.txt -c cells.txt -m peak2cell.mcx -e $n_entries -t integer -o $mx_p2c
ca_make_mmtx.sh -c peaks.txt -r cells.txt -m peak2cell.mcx -e $n_entries -t integer -T -o $mx_c2p
# various naming schemes exist. Maybe we'll use bc.
ln cells.txt bc.txt

if [[ -n $prefix ]]; then
  ln $mx_p2c $prefix''$mx_p2c
  ln $mx_c2p $prefix''$mx_c2p
  ln bc.txt $prefix''bc.txt
  ln peaks.txt $prefix''peaks.txt
fi



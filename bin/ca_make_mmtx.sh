#!/bin/bash

# convert a matrix in mcl/mcx format to matrixmarket format. See -h for more information.

set -euo pipefail

colnames==
rownames==
n_entries=
fn_matrix=
thetype=
transposeOpt=""
output=mtx.gz


while getopts :c:r:t:e:m:o:Th opt
do
    case "$opt" in
    c)
      colnames=$OPTARG
      ;;
    r)
      rownames=$OPTARG
      ;;
    t)
      thetype=$OPTARG
      ;;
    m)
      fn_matrix=$OPTARG
      ;;
    e)
      n_entries=$OPTARG
      ;;
    o)
      output=$OPTARG
      ;;
    T)
      transposeOpt="--transpose"
      ;;
    h)
      cat <<EOU
All arguments required:
-r file with row names
-c file with column names
-m file with matrix (mcl format)
-e count of the number of entries
-t type of matrix; e.g. <integer> or <pattern>
Optional
-o ouptut name (default $output)
EOU
      exit
      ;;
    :) echo "Flag $OPTARG needs argument"
        exit 1;;
    ?) echo "Flag $OPTARG unknown"              # Yes that's right, $OPTARG. bash bish bosh.
        exit 1;;
   esac
done


if [[ -z $colnames || -z $rownames || -z $n_entries || -z $thetype || -z $fn_matrix ]]; then
   echo "Need more arguments (see -h)"
   false
fi


  n_rows=$(cat $rownames | wc -l)
  n_cols=$(cat $colnames | wc -l)

>&2 echo "Writing matrix market file"
(
cat <<EOH
%%MatrixMarket matrix coordinate $thetype general
$n_rows $n_cols $n_entries
EOH
if [[ $thetype == 'pattern' ]]; then
  mcxdump $transposeOpt -imx $fn_matrix --no-values | perl -ane 'print $F[0]+1, "\t", $F[1]+1, "\n";'
elif [[ $thetype == 'integer' ]]; then
  mcxdump $transposeOpt -imx $fn_matrix | perl -ane 'print $F[0]+1, "\t", $F[1]+1, "\t", int($F[2]), "\n";'
fi
) | gzip > $output


#!/bin/bash

function useage()
{
  echo "useage: ${0} <source> <dest>"
  exit 1
}

set -e

[ -z "${1}" -o -z "${2}" -o ! -d "${1}_v1_00_a" ] && useage
rm -rvf "${2}_v1_00_a"
mkdir -pv "${2}_v1_00_a"
cd "${1}_v1_00_a"
for file in `find . -type f`
do
  install -m 644 -vD "${file}" \
    "../${2}_v1_00_a/`echo $file | sed -e \"s@${1}@${2}@g\"`"
  git add \
    "../${2}_v1_00_a/`echo $file | sed -e \"s@${1}@${2}@g\"`"
done
cd "../${2}_v1_00_a/"
for file in `find . -type f -exec grep -li "${1}" {} \;`
do
  u1=`echo "${1}" | tr '[:lower:]' '[:upper:]'`
  u2=`echo "${2}" | tr '[:lower:]' '[:upper:]'`
  sed -e "s@${1}@${2}@g" -e "s@${u1}@${u2}@g" "${file}" | grep -i "${2}"
  sed -e "s@${1}@${2}@g" -e "s@${u1}@${u2}@g" -i "${file}"
done

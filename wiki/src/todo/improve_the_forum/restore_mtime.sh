#!/bin/bash

for post in *.mdwn ; do
  echo ${post}
  date=`git log --format=%aD "${post}" | tail -1`
  touch --date="${date}" "${post}"
  dir="${post%.mdwn}"
  if [ -d "${dir}" ] ; then
    touch --date="${date}" "${dir}"
  fi
done

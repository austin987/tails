#!/bin/bash

find * -maxdepth 0 -mtime -$1 | while read file ; do
  post=${file%%.mdwn}.mdwn
  echo ${post}
  date=`git log --format=%aD "${post}" | tail -1`
  touch --date="${date}" "${post}"
  dir="${post%.mdwn}"
  if [ -d "${dir}" ] ; then
    touch --date="${date}" "${dir}"
  fi
done

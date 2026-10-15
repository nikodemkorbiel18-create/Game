#!/bin/bash
D=/tmp/claude-0/-home-user-Game/6bcd8953-5119-5cfc-8809-be01c57c648d/scratchpad
cd $D/bl
for s in hook dock lift deck offwheels tanker coins mismatch twistlock patent anycrane today; do
  ../bv/bin/python -I render.py $s $D/bframes --fps 24 --samples 12 > $D/blog_$s.txt 2>&1
  echo "SCENE $s exit $? frames=$(ls $D/bframes | wc -l)"
done
echo FULLDONE

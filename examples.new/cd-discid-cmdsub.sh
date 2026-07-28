# Demonstrate cd-discid in command substitution
# cd-discid is an external command, not the cd builtin
DISCID=`cd-discid /dev/cdrom | tr " " "+"`
echo "$DISCID"

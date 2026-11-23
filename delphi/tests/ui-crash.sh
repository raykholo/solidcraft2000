# The scheduled blue screen (start with --crashtest: the first one is at 10
# seconds). Any key puts everything back exactly as it was.
rm -f tests/out/c*.png
key r
key Return
key e
key Return
sleep 9
shot c01-bluescreen
key space
sleep 1
shot c02-back

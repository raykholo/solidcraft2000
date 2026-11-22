# Save, Open, STL, Publish, the floppy, and quitting with unsaved work.
rm -rf tests/out/files; mkdir -p tests/out/files
sleep 3
key r
key Return
key e
key Return
key h
key Return
sleep 1
key ctrl+s
sleep 2
shot f01-savedlg
key ctrl+a
type_ $HERE/tests/out/files/box.sc98
key Return
sleep 2
shot f02-saved
file_all
key alt+f
key r
sleep 2
key ctrl+a
type_ $HERE/tests/out/files/box.stl
key Return
sleep 2
shot f03-stl
key Return
file_all
key alt+f
key w
sleep 2
key ctrl+a
type_ $HERE/tests/out/files/box.htm
key Return
sleep 3
shot f04-published
key Return
file_all
key alt+f
key d
sleep 1
shot f05-nofloppy
key Return
key ctrl+o
sleep 2
type_ "$SAMPLES/Mounting Plate.sc98"
sleep 1
key Return
sleep 3
shot f06-opened
key Return
sleep 1
shot f06b-upgraded
key ctrl+o
sleep 2
type_ "$SAMPLES/Plate with holes.solidcraft"
sleep 1
key Return
sleep 3
shot f07-imported
key Return
sleep 1
turbo_on
file_all
key alt+f
key d
sleep 3
shot f08-floppy
sleep 3
shot f09-floppy-disk2
key Escape
sleep 1
key Escape
sleep 1
shot f10-cancelled
key Return
key Return
key ctrl+n
key r
key Return
key alt+f
key x
sleep 1
shot f11-quit-ask
key Escape
sleep 1
shot f12-still-here
key alt+f
key x
sleep 1
key alt+n
sleep 2

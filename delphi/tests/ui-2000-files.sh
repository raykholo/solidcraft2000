# SolidCraft 2000 parts: a part from SolidCraft 98 is upgraded, a 2000 part with
# fillets opens, and Save As writes an .sc2.
rm -f tests/out/o*.png tests/out/saved-upgrade.sc2
sleep 3
key ctrl+o
sleep 2
type_ "$SAMPLES/Filleted Plate.sc2"
sleep 1
key Return
sleep 3
shot o01-filleted-plate
key s
sleep 4
shot o02-filleted-plate-shaded
key s
key ctrl+o
sleep 2
type_ "$SAMPLES/Mounting Plate.sc98"
sleep 1
key Return
sleep 3
shot o03-upgraded
key Return
sleep 1
key ctrl+s
sleep 2
key ctrl+a
type_ "$HERE/tests/out/saved-upgrade.sc2"
sleep 1
shot o04-save-as
key Return
sleep 2
shot o05-saved
# a SolidCraft design with a fillet: it comes over as a real SolidCraft 2000 fillet
key ctrl+o
sleep 2
type_ "$SAMPLES/Rounded Block.solidcraft"
sleep 1
key Return
sleep 3
shot o06-rounded-block
key s
sleep 4
shot o07-rounded-block-shaded

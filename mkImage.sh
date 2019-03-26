#!/usr/bin/env bash

INPUT_FRIENDLYCORE_XENIAL_SHA256=\
3af561494858e2e59537605ce0a1d6832679989a62c11beb5e3e2e3ce646caa8

INPUT_NIXOS_SD_IMAGES_SHA256=\
a66d25be56a83c48bd2e76c53dbfccd6f2ce307e6e16c59118c29b3b20c2154c

PATCHED_NIXOS_SD_IMAGES_SHA256=\
a763bf6eaa4a29bdf7b5d4a6718ce2b63493308b4bdc6093ae2d347c1dea3f80

IDENTICAL_SOURCE=true


if test -z "$1"
then
    INPUT_NIXOS_SD_IMAGE_FILENAME=`
    `"nixos-sd-image-18.09.2327.37694c8cc0e-aarch64-linux.img"
else
    INPUT_NIXOS_SD_IMAGE_FILENAME="$1"
fi

NEW_NIXOS_SD_IMAGE_FILENAME="nanopi-neo2-$INPUT_NIXOS_SD_IMAGE_FILENAME"

if test -z "$2"
then
    INPUT_FRIENDLYCORE_XENIAL_FILENAME=`
    `"nanopi-neo2_sd_friendlycore-xenial_4.14_arm64_20181011.img"
else
    INPUT_FRIENDLYCORE_XENIAL_FILENAME="$2"
fi


partition_offset()
{
    parted -ms "$2" unit s  print \
        | grep -E "^$1:" | cut -d':' -f2 | cut -d's' -f1
}

partition_size()
{
    parted -ms "$2" unit s  print \
        | grep -E "^$1:" | cut -d':' -f4 | cut -d's' -f1
}

SHA256_CHECK_STRING=`
`"$INPUT_FRIENDLYCORE_XENIAL_SHA256 $INPUT_FRIENDLYCORE_XENIAL_FILENAME"
if ! (echo "$SHA256_CHECK_STRING" | sha256sum -c)
then
    echo "warning: given former friendlycore xenial image differs in checksum!"
    IDENTICAL_SOURCE=false
fi

INPUT_NIXOS_SD_IMAGE_SHA256=`
`$(sha256sum "$INPUT_NIXOS_SD_IMAGE_FILENAME" | cut -d' ' -f1)
case $INPUT_NIXOS_SD_IMAGES_SHA256 in
    *$INPUT_NIXOS_SD_IMAGE_SHA256*)
        echo "note: given nixos sd image is tested `\
        `and known to produce expected image"
        ;;
    *)
        echo "warning: given former nixos sd image was not tested!"
        IDENTICAL_SOURCE=false
        ;;
esac

# getting unpartitioned boot area size of the former friendlycore xenial image
BOOT_AREA_SIZE=$(partition_offset 1 "$INPUT_FRIENDLYCORE_XENIAL_FILENAME")

# getting nixos partitions properties
NIXOS_PART_BOOT_OFFSET=$(partition_offset 1 "$INPUT_NIXOS_SD_IMAGE_FILENAME")
NIXOS_PART_BOOT_SIZE=$(partition_size 1 "$INPUT_NIXOS_SD_IMAGE_FILENAME")
NIXOS_PART_SD_OFFSET=$(partition_offset 2 "$INPUT_NIXOS_SD_IMAGE_FILENAME")
NIXOS_PART_SD_SIZE=$(partition_size 2 "$INPUT_NIXOS_SD_IMAGE_FILENAME")
if test -z "$NIXOS_PART_BOOT_SIZE" || test -z "$NIXOS_PART_SD_SIZE" \
        || test -z "$NIXOS_PART_SD_OFFSET" || test -z "$NIXOS_PART_SD_SIZE"
then
    echo "error: cannot get nixos partitions offsets and sizes!"
    exit 1
fi

echo "copying bootloader area"
if ! dd if="$INPUT_FRIENDLYCORE_XENIAL_FILENAME" \
     of="$NEW_NIXOS_SD_IMAGE_FILENAME" \
     count="$BOOT_AREA_SIZE" bs=512
then
    echo "error in dd!"
    exit 2
fi

echo "appending nixos boot partition"
if ! dd if="$INPUT_NIXOS_SD_IMAGE_FILENAME" `
     `skip="$NIXOS_PART_BOOT_OFFSET" count="$NIXOS_PART_BOOT_SIZE" bs=512 `
     `>> "$NEW_NIXOS_SD_IMAGE_FILENAME"
then
    echo "error in dd!"
    exit 3
fi

echo "appending nixos sd (store) partition"
if ! dd if="$INPUT_NIXOS_SD_IMAGE_FILENAME" `
   `skip="$NIXOS_PART_SD_OFFSET" count="$NIXOS_PART_SD_SIZE" bs=512`
   `>> "$NEW_NIXOS_SD_IMAGE_FILENAME"
then
    echo "error in dd!"
    exit 4
fi

echo "writing new partition table"
if ! sfdisk --no-tell-kernel --delete "$NEW_NIXOS_SD_IMAGE_FILENAME" 2
then
    echo "error in sfdisk when deleting oversized partition!"
    exit 5
fi
if ! parted -s -a none "$NEW_NIXOS_SD_IMAGE_FILENAME" \
     unit s \
     resizepart 1 $(("$BOOT_AREA_SIZE" + "$NIXOS_PART_BOOT_SIZE" - 1)) \
     mkpart primary ext4 $(("$BOOT_AREA_SIZE" + "$NIXOS_PART_BOOT_SIZE")) 100%
then
    echo "error in parted when writing new partition table!"
    exit 6
fi

echo "stabilizing (nullify) partition table identifier"
if ! dd if=/dev/zero of="$NEW_NIXOS_SD_IMAGE_FILENAME" seek=110 bs=4 count=1 \
     conv=notrunc
then
    echo "error in dd when overwriting partition table identifier!"
    exit 7
fi

if $IDENTICAL_SOURCE
then
    NEW_NIXOS_SD_IMAGE_SHA256=`
    `$(sha256sum "$NEW_NIXOS_SD_IMAGE_FILENAME" | cut -d' ' -f1)
    case *$PATCHED_NIXOS_SD_IMAGES_SHA256* in
        *$NEW_NIXOS_SD_IMAGE_SHA256*)
            echo "congrats, new image in correct!"
            exit 0
            ;;
        *)
            echo "error: "`
                 `"new image differs in checksum despite identical input!"
            ;;
    esac
fi

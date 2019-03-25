## description
Produces a bootable on nanopi neo2 image based on boot area from
friendlycore-xenial image and nixos sd image for aarch64.

## requirements
- bash
- dd
- parted
- sha256sum
- sfdisk (awkward, since parted is unable to delete oversized partitions)

## running
```shell
$ ./mkImage.sh [nixos-sd-image [friendlycore-xenial-image]]
```

## tested inputs
- friendlycore-xenial:
`nanopi-neo2_sd_friendlycore-xenial_4.14_arm64_20181011.img`, sha256:
`3af561494858e2e59537605ce0a1d6832679989a62c11beb5e3e2e3ce646caa8`
 
 Taken from https://drive.google.com/open?id=1WkEeHJlDT3uggTDNj8pHib96JbhJhMnS
 Direct link: https://drive.google.com/open?id=1rPCdq8dAs2bKRnUnVnWDMju8yOpoyTfJ.

- nixos sd image for aarch64:
`nixos-sd-image-18.09.2327.37694c8cc0e-aarch64-linux.img`, sha256:
`a66d25be56a83c48bd2e76c53dbfccd6f2ce307e6e16c59118c29b3b20c2154c`

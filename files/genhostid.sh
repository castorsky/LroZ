#!/usr/bin/bash
#
# Use CRC-32 to hash a hex string a nibble at a time to generate a ZFS
#    "hostid" from the DMI data host UUID
#
# CRC-32 as defined in zlib is:
#        poly is 0x104c11db7
#        initial value is 0xffffffff
#        final value has 0xffffffff xor "added"
#        bits are processed lsb first
#
# That last bit is unfortunately a problem for this use case of doing
#    things a nibble at a time, but since we really just want to scramble
#    a larger bit string into a smaller bit string, we can just decide
#    to use the polynomial and math, but skip the parts that complicate
#    with no gain.  So msb first and no final xor.
#
# We can check that we've got a valid CRC by tacking the CRC onto the end
#    of the original string and passing both through this same calculation
#    which in this case without the final 0xff..ff xor will produce 0
#
#    $ genhostid.sh <uuid> $(genhostid.sh <uuid>)
#
#    That should always produce 00000000 as output
#
# Set "TABLE" to see the CRC table.  Set VERBOSE to see the intermediate
#    values

# Generate a table of nibble CRC feedbacks
poly=0x04c11db7
declare -a crctab
for i in {0..15} ; do
   # The most significant nibble of the poly is 0 so we don't have to
   #     deal with feedback of bits in these terms
   fb=$(( (poly*(i&8)) ^ (poly*(i&4)) ^ (poly*(i&2)) ^ (poly*(i&1)) ))
   crctab[$i]=$fb
   if [[ -n "$TABLE" ]]; then
      printf "crctab[%d] = %10d  %08x\n" $i ${crctab[i]} ${crctab[i]}
   fi
done

# Hash or CRC what's on the command line or the "product_uuid" from
#    the DMI data by default
input="$*"
if [[ -z "$input" ]]; then
   input=$(</sys/devices/virtual/dmi/id/product_uuid)
fi

# Init with all ones to process leading zeros
hostid=$((0xFFFFFFFF))

# Add one nibble at a time
for nibble in $(sed -e 's/\(.\)/\1 /g' <<<"$input") ; do 
   case "$nibble" in
   [0-9a-fA-F] )
      nib=$(( (0x$nibble ^ (hostid>>28)) & 0xf ))
      new=$(( ((hostid&0x0FFFFFFF)<<4) ^ ${crctab[nib]} ))
      ;;
   * ) : ;;  # Ignore anything that isn't hex digit
   esac
   if [[ -n "$VERBOSE" ]]; then
      printf "%08x + %s = %07x0 ^ %08x[%1x] = %08x\n" $hostid $nibble $((hostid&0x0FFFFFFF)) ${crctab[nib]} $nib $new
   fi
   hostid=$new
done

if [[ -n "$FINAL" ]]; then
   # Hush, it's a secret: final xor option
   hostid=$((hostid ^ FINAL))
   # Which if you use 4294967295 which is "0xffffffff" in decimal
   # will change the final crc residual value to always be 0xc704dd7b
   # for a valid bit string with the crc appended.  That signature is
   # specific to the CRC-32 polynomial used in this way.  Every poly
   # has a different signature value.
fi

# Print the hashed hostid
printf "%08x\n" $hostid

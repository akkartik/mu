fn load-sectors disk: (addr disk), lba: int, n: int, out: (addr stream byte) {
  var curr-lba/ebx: int <- copy lba
  var remaining/edx: int <- copy n
  {
    compare remaining, 0
    break-if-<=
    # sectors = min(remaining, 0x100)
    var sectors/eax: int <- copy remaining
    compare sectors, 0x100
    {
      break-if-<=
      sectors <- copy 0x100
    }
    #
    read-ata-disk disk, curr-lba, sectors, out
    #
    remaining <- subtract sectors
    curr-lba <- add sectors
    loop
  }
}

fn store-sectors disk: (addr disk), lba: int, n: int, in: (addr stream byte) {
  var curr-lba/ebx: int <- copy lba
  var remaining/edx: int <- copy n
  {
    compare remaining, 0
    break-if-<=
    # sectors = min(remaining, 0x100)
    var sectors/eax: int <- copy remaining
    compare sectors, 0x100
    {
      break-if-<=
      sectors <- copy 0x100
    }
    #
    write-ata-disk disk, curr-lba, sectors, in
    #
    remaining <- subtract sectors
    curr-lba <- add sectors
    loop
  }
}

type cell {
  type: int
  # type 0: pair
  left: (handle cell)
  right: (handle cell)
  # type 1: number
  number-data: float
  # type 2: symbol
  # type 3: string
  text-data: (handle array byte)
  # TODO: array, (associative) table, stream
}

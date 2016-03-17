//:: Interacting with the file-system

:(before "End Primitive Recipe Declarations")
OPEN_FILE_FOR_READING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "open-file-for-reading", OPEN_FILE_FOR_READING);
:(before "End Primitive Recipe Checks")
case OPEN_FILE_FOR_READING: {
  break;
}
:(before "End Primitive Recipe Implementations")
case OPEN_FILE_FOR_READING: {
  break;
}

:(before "End Primitive Recipe Declarations")
OPEN_FILE_FOR_WRITING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "open-file-for-reading", OPEN_FILE_FOR_WRITING);
:(before "End Primitive Recipe Checks")
case OPEN_FILE_FOR_WRITING: {
  break;
}
:(before "End Primitive Recipe Implementations")
case OPEN_FILE_FOR_WRITING: {
  break;
}

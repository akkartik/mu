#ifndef HASHTABLE_H
#define HASHTABLE_H

#include "common.h"

typedef struct HashTable HashTable;

HashTable* HashTable_create(uint32 capacity);
void HashTable_destroy(HashTable* hashTable);
BOOL HashTable_search(HashTable* hashTable, uint32 key, uint32* value);
BOOL HashTable_insert(HashTable* hashTable, uint32 key, uint32 data);
BOOL HashTable_remove(HashTable* hashTable, uint32 key);

#endif // HASHTABLE_H

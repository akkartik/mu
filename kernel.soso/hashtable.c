#include "hashtable.h"
#include "alloc.h"

typedef struct DataItem
{
   uint32 data;
   uint32 key;
   uint8 used;
} DataItem;

typedef struct HashTable
{
   DataItem* items;
   uint32 capacity;
} HashTable;

static uint32 hashCode(HashTable* hashTable, uint32 key)
{
   return key % hashTable->capacity;
}

HashTable* HashTable_create(uint32 capacity)
{
    HashTable* hashTable = kmalloc(sizeof(HashTable));
    memset((uint8*)hashTable, 0, sizeof(HashTable));
    hashTable->capacity = capacity;
    hashTable->items = kmalloc(sizeof(DataItem) * capacity);

    return hashTable;
}

void HashTable_destroy(HashTable* hashTable)
{
    kfree(hashTable->items);
    kfree(hashTable);
}

DataItem* HashTable_search_internal(HashTable* hashTable, uint32 key)
{
   //get the hash
   uint32 hashIndex = hashCode(hashTable, key);

   uint32 counter = 0;
   while(counter < hashTable->capacity)
   {
      if(hashTable->items[hashIndex].key == key)
      {
          if(hashTable->items[hashIndex].used == TRUE)
          {
              return &(hashTable->items[hashIndex]);
          }
      }

      //go to next cell
      ++hashIndex;

      //wrap around the table
      hashIndex %= hashTable->capacity;

      ++counter;
   }

   return NULL;
}

BOOL HashTable_search(HashTable* hashTable, uint32 key, uint32* value)
{
    DataItem* existing = HashTable_search_internal(hashTable, key);

    if (existing)
    {
        *value = existing->data;

        return TRUE;
    }

    return FALSE;
}

BOOL HashTable_insert(HashTable* hashTable, uint32 key, uint32 data)
{
    DataItem* existing = HashTable_search_internal(hashTable, key);

    if (existing)
    {
        existing->data = data;

        return TRUE;
    }

    //get the hash
    uint32 hashIndex = hashCode(hashTable, key);

    uint32 counter = 0;
    //move in array until an empty or deleted cell
    while(counter < hashTable->capacity)
    {
        if (hashTable->items[hashIndex].used == FALSE)
        {
            hashTable->items[hashIndex].key = key;
            hashTable->items[hashIndex].data = data;
            hashTable->items[hashIndex].used = TRUE;

            return TRUE;
        }


        //go to next cell
        ++hashIndex;

        //wrap around the table
        hashIndex %= hashTable->capacity;

        ++counter;
    }

    return FALSE;
}

BOOL HashTable_remove(HashTable* hashTable, uint32 key)
{
    DataItem* existing = HashTable_search_internal(hashTable, key);

    if (existing)
    {
        existing->used = FALSE;

        return TRUE;
    }

    return FALSE;
}

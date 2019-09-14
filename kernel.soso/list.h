#ifndef LIST_H
#define LIST_H

#include "common.h"

#define List_Foreach(listNode, list) for (ListNode* listNode = list->head; NULL != listNode ; listNode = listNode->next)

typedef struct ListNode
{
    struct ListNode* previous;
    struct ListNode* next;
    void* data;
} ListNode;

typedef struct List
{
    struct ListNode* head;
    struct ListNode* tail;
} List;

List* List_Create();
void List_Clear(List* list);
void List_Destroy(List* list);
List* List_CreateClone(List* list);
BOOL List_IsEmpty(List* list);
void List_Append(List* list, void* data);
void List_Prepend(List* list, void* data);
ListNode* List_GetFirstNode(List* list);
ListNode* List_GetLastNode(List* list);
ListNode* List_FindFirstOccurrence(List* list, void* data);
int List_FindFirstOccurrenceIndex(List* list, void* data);
int List_GetCount(List* list);
void List_RemoveNode(List* list, ListNode* node);
void List_RemoveFirstNode(List* list);
void List_RemoveLastNode(List* list);
void List_RemoveFirstOccurrence(List* list, void* data);

typedef struct Stack
{
    List* list;
} Stack;

Stack* Stack_Create();
void Stack_Clear(Stack* stack);
void Stack_Destroy(Stack* stack);
BOOL Stack_IsEmpty(Stack* stack);
void Stack_Push(Stack* stack, void* data);
void* Stack_Pop(Stack* stack);

typedef struct Queue
{
    List* list;
} Queue;

Queue* Queue_Create();
void Queue_Clear(Queue* queue);
void Queue_Destroy(Queue* queue);
BOOL Queue_IsEmpty(Queue* queue);
void Queue_Enqueue(Queue* queue, void* data);
void* Queue_Dequeue(Queue* stack);

#endif // LIST_H

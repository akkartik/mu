#include "alloc.h"
#include "common.h"
#include "list.h"

List* List_Create()
{
    List* list = (List*)kmalloc(sizeof(List));

    memset((uint8*)list, 0, sizeof(List));

    return list;
}

void List_Clear(List* list)
{
    ListNode* listNode = list->head;

    while (NULL != listNode)
    {
        ListNode* next = listNode->next;

        kfree(listNode);

        listNode = next;
    }

    list->head = NULL;
    list->tail = NULL;
}

void List_Destroy(List* list)
{
    List_Clear(list);

    kfree(list);
}

List* List_CreateClone(List* list)
{
    List* newList = List_Create();

    List_Foreach(n, list)
    {
        List_Append(newList, n->data);
    }

    return newList;
}

BOOL List_IsEmpty(List* list)
{
    //At empty state, both head and tail are null!
    return list->head == NULL;
}

void List_Append(List* list, void* data)
{
    ListNode* node = (ListNode*)kmalloc(sizeof(ListNode));

    memset((uint8*)node, 0, sizeof(ListNode));
    node->data = data;

    //At empty state, both head and tail are null!
    if (NULL == list->tail)
    {
        list->head = node;

        list->tail = node;

        return;
    }

    node->previous = list->tail;
    node->previous->next = node;
    list->tail = node;
}

void List_Prepend(List* list, void* data)
{
    ListNode* node = (ListNode*)kmalloc(sizeof(ListNode));

    memset((uint8*)node, 0, sizeof(ListNode));
    node->data = data;

    //At empty state, both head and tail are null!
    if (NULL == list->tail)
    {
        list->head = node;

        list->tail = node;

        return;
    }

    node->next = list->head;
    node->next->previous = node;
    list->head = node;
}

ListNode* List_GetFirstNode(List* list)
{
    return list->head;
}

ListNode* List_GetLastNode(List* list)
{
    return list->tail;
}

ListNode* List_FindFirstOccurrence(List* list, void* data)
{
    List_Foreach(n, list)
    {
        if (n->data == data)
        {
            return n;
        }
    }

    return NULL;
}

int List_FindFirstOccurrenceIndex(List* list, void* data)
{
    int result = 0;

    List_Foreach(n, list)
    {
        if (n->data == data)
        {
            return result;
        }

        ++result;
    }

    return -1;
}

int List_GetCount(List* list)
{
    int result = 0;

    List_Foreach(n, list)
    {
        ++result;
    }

    return result;
}

void List_RemoveNode(List* list, ListNode* node)
{
    if (NULL == node)
    {
        return;
    }

    if (NULL != node->previous)
    {
        node->previous->next = node->next;
    }

    if (NULL != node->next)
    {
        node->next->previous = node->previous;
    }

    if (node == list->head)
    {
        list->head = node->next;
    }

    if (node == list->tail)
    {
        list->tail = node->previous;
    }

    kfree(node);
}

void List_RemoveFirstNode(List* list)
{
    if (NULL != list->head)
    {
        List_RemoveNode(list, list->head);
    }
}

void List_RemoveLastNode(List* list)
{
    if (NULL != list->tail)
    {
        List_RemoveNode(list, list->tail);
    }
}

void List_RemoveFirstOccurrence(List* list, void* data)
{
    ListNode* node = List_FindFirstOccurrence(list, data);

    if (NULL != node)
    {
        List_RemoveNode(list, node);
    }
}

Stack* Stack_Create()
{
    Stack* stack = (Stack*)kmalloc(sizeof(Stack));

    memset((uint8*)stack, 0, sizeof(Stack));

    stack->list = List_Create();

    return stack;
}

void Stack_Clear(Stack* stack)
{
    List_Clear(stack->list);
}

void Stack_Destroy(Stack* stack)
{
    List_Destroy(stack->list);

    kfree(stack);
}

BOOL Stack_IsEmpty(Stack* stack)
{
    return List_IsEmpty(stack->list);
}

void Stack_Push(Stack* stack, void* data)
{
    List_Prepend(stack->list, data);
}

void* Stack_Pop(Stack* stack)
{
    void* result = NULL;

    ListNode* node = List_GetFirstNode(stack->list);

    if (NULL != node)
    {
        result = node->data;

        List_RemoveNode(stack->list, node);
    }

    return result;
}

Queue* Queue_Create()
{
    Queue* queue = (Queue*)kmalloc(sizeof(Queue));

    memset((uint8*)queue, 0, sizeof(Queue));

    queue->list = List_Create();

    return queue;
}

void Queue_Clear(Queue* queue)
{
    List_Clear(queue->list);
}

void Queue_Destroy(Queue* queue)
{
    List_Destroy(queue->list);

    kfree(queue);
}

BOOL Queue_IsEmpty(Queue* queue)
{
    return List_IsEmpty(queue->list);
}

void Queue_Enqueue(Queue* queue, void* data)
{
    List_Append(queue->list, data);
}

void* Queue_Dequeue(Queue* stack)
{
    void* result = NULL;

    ListNode* node = List_GetFirstNode(stack->list);

    if (NULL != node)
    {
        result = node->data;

        List_RemoveNode(stack->list, node);
    }

    return result;
}

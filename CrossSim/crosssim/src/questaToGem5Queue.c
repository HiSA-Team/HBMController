#include "questaToGem5Queue.h"

uint8_t qtg5_init(struct QuestaToGem5Queue * shq)
{
    if (!shq->is_init)
    {
        shq->head = 0;
        shq->tail = 0;
        for (int i = 0; i < QUEUE_SIZE; i++)
        {
            shq->id            [i] = 0;
            shq->ack           [i] = 0;
            shq->data          [i] = 0;
            shq->clock_cycles  [i] = 0;
        }

        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
        pthread_mutex_init(&shq->queueMutex, &attr);

        shq->is_init = 1;
    }
    return 1;
}

uint8_t qtg5_full(struct QuestaToGem5Queue * shq)
{
    return shq->tail == shq->head && shq->id[shq->tail] != 0;
}

uint8_t qtg5_empty(struct QuestaToGem5Queue * shq)
{
    return shq->tail == shq->head && shq->id[shq->tail] == 0;
}

uint8_t qtg5_enqueue(struct QuestaToGem5Queue * shq, uint8_t id, uint8_t ack, uint64_t data, uint8_t clock_cycles)
{
    pthread_mutex_lock(&shq->queueMutex);
    // printf("questa_send(): starting...\n");

    // The queue is full, unlock the mutex and return
    if (qtg5_full(shq))
    {
        pthread_mutex_unlock(&shq->queueMutex);
        // printf("questa_send(): full queue, exiting...\n");
        return 0;
    }

    // printf("questa_send(): id           = %" PRId8 "\n", id);
    // printf("questa_send(): ack          = %" PRId8 "\n", ack);
    // printf("questa_send(): data         = %" PRId64 "\n", data);
    // printf("questa_send(): clock_cycles = %" PRId8 "\n", clock_cycles);

    shq->id[shq->tail]            = id;
    shq->ack[shq->tail]           = ack;
    shq->data[shq->tail]          = data;
    shq->clock_cycles[shq->tail]  = clock_cycles;

    shq->tail = (shq->tail + 1) % QUEUE_SIZE;

    pthread_mutex_unlock(&shq->queueMutex);
    // printf("questa_send(): exiting...\n");
    return 1;
}


uint8_t qtg5_dequeue(struct QuestaToGem5Queue * shq, uint8_t* id, uint8_t* ack, uint64_t* data, uint8_t* clock_cycles)
{

    pthread_mutex_lock(&shq->queueMutex);

    // printf("gem5_receive(): starting...\n");

    // The queue is empty, unlock the mutex and return
    if (qtg5_empty(shq))
    {
        pthread_mutex_unlock(&shq->queueMutex);
        // printf("gem5_receive(): empty queue, exiting...\n");
        return 0;
    }

    // Get the data from the queue at the head
    *id           =   shq->id[shq->head];
    *ack          =   shq->ack[shq->head];
    *data         =   shq->data[shq->head];
    *clock_cycles =   shq->clock_cycles[shq->head];

    shq->id[shq->head]              = 0;
    shq->ack[shq->head]             = 0;
    shq->data[shq->head]            = 0;
    shq->clock_cycles[shq->head]    = 0;

    // printf("gem5_receive(): id           = %" PRId8 "\n", *id);
    // printf("gem5_receive(): ack          = %" PRId8 "\n", *ack);
    // printf("gem5_receive(): data         = %" PRId64 "\n", *data);
    // printf("gem5_receive(): clock_cycles = %" PRId8 "\n", *clock_cycles);

    // Update the head pointer
    shq->head = (shq->head + 1) % QUEUE_SIZE;

    // Unlock the mutex and return
    pthread_mutex_unlock(&shq->queueMutex);

    // printf("gem5_receive(): exiting...\n");
    return 1;
}

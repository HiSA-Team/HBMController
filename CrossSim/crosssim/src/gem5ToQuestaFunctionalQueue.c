#include "gem5ToQuestaFunctionalQueue.h"

uint8_t g5tq_functional_init(struct Gem5ToQuestaFunctionalQueue * shq)
{
    if (!shq->is_init)
    {
        shq->head = 0;
        shq->tail = 0;
        for (int i = 0; i < QUEUE_SIZE; i++)
        {
            shq->id       [i] = 0;
            shq->address  [i] = 0;
            shq->data     [i] = 0;
            shq->is_write [i] = 0;
        }

        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
        pthread_mutex_init(&shq->queueMutex, &attr);

        shq->is_init = 1;
    }
    return 1;
}

uint8_t g5tq_functional_full(struct Gem5ToQuestaFunctionalQueue * shq)
{
    return shq->tail == shq->head && shq->id[shq->tail] != 0;
}

uint8_t g5tq_functional_empty(struct Gem5ToQuestaFunctionalQueue * shq)
{
    return shq->tail == shq->head && shq->id[shq->tail] == 0;
}

uint8_t g5tq_functional_generate_id(struct Gem5ToQuestaFunctionalQueue * shq)
{
    uint8_t found;
    uint8_t id;

    do
    {
        found = 0;
        id = rand() % 256; // id in [0,255]

        for(int i = 0; i < QUEUE_SIZE; ++i)
            if(id == shq->id[i])
                found = 1;
    }
    while(found);

    printf("[functional_generate_id] %d\n", id);

    return id;
}

uint8_t g5tq_functional_enqueue(struct Gem5ToQuestaFunctionalQueue * shq, uint64_t address, uint64_t data, uint8_t is_write)
{
    pthread_mutex_lock(&shq->queueMutex);

    // The queue is full, unlock the mutex and return
    if (g5tq_functional_full(shq))
    {
        pthread_mutex_unlock(&shq->queueMutex);
        // printf("gem5_send(): full queue, exiting... \n");
        return 0;
    }

    shq->id[shq->tail]       = g5tq_functional_generate_id(shq);
    shq->address[shq->tail]  = address;
    shq->data[shq->tail]     = data;
    shq->is_write[shq->tail] = is_write;

    // printf("gem5_send(): id       = %" PRId8 "\n", shq->id[shq->tail]);
    // printf("gem5_send(): address  = %" PRId64 "\n", address);
    // printf("gem5_send(): data     = %" PRId64 "\n", data);
    // printf("gem5_send(): is_write = %" PRId8 "\n", is_write);

    shq->tail = (shq->tail + 1) % QUEUE_SIZE;

    pthread_mutex_unlock(&shq->queueMutex);

    // printf("gem5_send(): exiting...\n");
    return 1;
}


uint8_t g5tq_functional_dequeue(struct Gem5ToQuestaFunctionalQueue * shq, uint8_t* id, uint64_t* address, uint64_t* data, uint8_t* is_write)
{
    pthread_mutex_lock(&shq->queueMutex);

    // printf("questa_receive(): starting...\n");

    // The queue is empty, unlock the mutex and return
    if (g5tq_functional_empty(shq))
    {
        pthread_mutex_unlock(&shq->queueMutex);
        return 0;
    }

    // Get the data from the queue at the head
    *id       =   shq->id[shq->head];
    *address  =   shq->address[shq->head];
    *data     =   shq->data[shq->head];
    *is_write =   shq->is_write[shq->head];

    // Pop the request from the queue
    shq->id[shq->head]       = 0;
    shq->address[shq->head]  = 0;
    shq->data[shq->head]     = 0;
    shq->is_write[shq->head] = 0;

    printf("questa_functional_receive(): id       = %" PRId8 "\n", *id);
    printf("questa_functional_receive(): address  = %" PRId64 "\n", *address);
    printf("questa_functional_receive(): data     = %" PRId64 "\n", *data);
    printf("questa_functional_receive(): is_write = %" PRId8 "\n", *is_write);

    // Update the head pointer
    shq->head = (shq->head + 1) % QUEUE_SIZE;

    // Unlock the mutex and return
    pthread_mutex_unlock(&shq->queueMutex);

    // printf("questa_receive(): exiting...\n");
    return 1;
}

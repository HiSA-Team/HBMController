#ifndef GEM5_TO_QUESTA_QUEUE_H__
#define GEM5_TO_QUESTA_QUEUE_H__

#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <inttypes.h>

#define QUEUE_SIZE 10

__attribute__((visibility ("hidden")))  struct Gem5ToQuestaQueue {
    uint8_t is_init;
    uint8_t id[QUEUE_SIZE];
    uint64_t address[QUEUE_SIZE];
    uint64_t data[QUEUE_SIZE];
    uint8_t is_write[QUEUE_SIZE];
    int head;
    int tail;
    pthread_mutex_t queueMutex;
};

__attribute__((visibility ("hidden")))  uint8_t g5tq_init(struct Gem5ToQuestaQueue * shq);
__attribute__((visibility ("hidden")))  uint8_t g5tq_empty(struct Gem5ToQuestaQueue * shq);
__attribute__((visibility ("hidden")))  uint8_t g5tq_full(struct Gem5ToQuestaQueue * shq);

// it returns 1 if to_check hasn't already been used, 0 otherwise
__attribute__((visibility ("hidden")))  uint8_t g5tq_generate_id(struct Gem5ToQuestaQueue * shq);

__attribute__((visibility ("hidden")))  uint8_t g5tq_enqueue(struct Gem5ToQuestaQueue * shq, uint64_t address, uint64_t  data, uint8_t is_write );
__attribute__((visibility ("hidden")))  uint8_t g5tq_dequeue(struct Gem5ToQuestaQueue * shq, uint8_t* id,  uint64_t* address, uint64_t* data, uint8_t* is_write);

#endif

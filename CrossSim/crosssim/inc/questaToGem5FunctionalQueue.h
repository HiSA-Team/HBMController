#ifndef QUESTA_TO_GEM5_FUNCTIONAL_QUEUE_H__
#define QUESTA_TO_GEM5_FUNCTIONAL_QUEUE_H__

#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <inttypes.h>

#define QUEUE_SIZE 10

__attribute__((visibility ("hidden")))  struct QuestaToGem5FunctionalQueue {
    uint8_t is_init;
    uint8_t id[QUEUE_SIZE];
    uint8_t ack[QUEUE_SIZE];
    uint64_t data[QUEUE_SIZE];
    uint8_t clock_cycles[QUEUE_SIZE];
    int head;
    int tail;
    pthread_mutex_t queueMutex;
};

__attribute__((visibility ("hidden")))  uint8_t qtg5_functional_init(struct QuestaToGem5FunctionalQueue * shq);
__attribute__((visibility ("hidden")))  uint8_t qtg5_functional_empty(struct QuestaToGem5FunctionalQueue * shq);
__attribute__((visibility ("hidden")))  uint8_t qtg5_functional_full (struct QuestaToGem5FunctionalQueue * shq);

// it returns 1 if to_check hasn't already been used, 0 otherwise
//__attribute__((visibility ("hidden")))  uint8_t qtg5_functional_check_id(struct QuestaToGem5FunctionalQueue * shq, uint8_t to_check);

__attribute__((visibility ("hidden")))  uint8_t qtg5_functional_enqueue(struct QuestaToGem5FunctionalQueue * shq, uint8_t id, uint8_t ack, uint64_t  data, uint8_t clock_cycles);
__attribute__((visibility ("hidden")))  uint8_t qtg5_functional_dequeue(struct QuestaToGem5FunctionalQueue * shq, uint8_t* id, uint8_t* ack, uint64_t* data, uint8_t* clock_cycles);

#endif // SHARED_QUEUE_H__
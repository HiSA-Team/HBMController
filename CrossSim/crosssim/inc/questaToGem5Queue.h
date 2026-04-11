#ifndef QUESTA_TO_GEM5_QUEUE_H__
#define QUESTA_TO_GEM5_QUEUE_H__

#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <inttypes.h>

#define QUEUE_SIZE 10

__attribute__((visibility ("hidden")))  struct QuestaToGem5Queue {
    uint8_t is_init;
    uint8_t id[QUEUE_SIZE];
    uint8_t ack[QUEUE_SIZE];
    uint64_t data[QUEUE_SIZE];
    uint8_t clock_cycles[QUEUE_SIZE];
    int head;
    int tail;
    pthread_mutex_t queueMutex;
};

__attribute__((visibility ("hidden")))  uint8_t qtg5_init(struct QuestaToGem5Queue * shq);
__attribute__((visibility ("hidden")))  uint8_t qtg5_empty(struct QuestaToGem5Queue * shq);
__attribute__((visibility ("hidden")))  uint8_t qtg5_full (struct QuestaToGem5Queue * shq);

// it returns 1 if to_check hasn't already been used, 0 otherwise
//__attribute__((visibility ("hidden")))  uint8_t qtg5_check_id(struct QuestaToGem5Queue * shq, uint8_t to_check);

__attribute__((visibility ("hidden")))  uint8_t qtg5_enqueue(struct QuestaToGem5Queue * shq, uint8_t id, uint8_t ack, uint64_t  data, uint8_t clock_cycles);
__attribute__((visibility ("hidden")))  uint8_t qtg5_dequeue(struct QuestaToGem5Queue * shq, uint8_t* id, uint8_t* ack, uint64_t* data, uint8_t* clock_cycles);

#endif // SHARED_QUEUE_H__
#include <pthread.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h> // needed for memset
#include <time.h>

#include "gem5ToQuestaQueue.h"
#include "questaToGem5Queue.h"

#include "gem5ToQuestaFunctionalQueue.h"
#include "questaToGem5FunctionalQueue.h"


struct Gem5ToQuestaQueue * g5tq_queue = NULL;
struct QuestaToGem5Queue * qtg5_queue = NULL;

struct Gem5ToQuestaFunctionalQueue * g5tq_functional_queue = NULL;
struct QuestaToGem5FunctionalQueue * qtg5_functional_queue = NULL;


void initialize()
{
    printf("initialize(): starting... \n");
    int g5tq_already_created = 0;
    int qtg5_already_created = 0;

    int g5tq_functional_already_created = 0;
    int qtg5_functional_already_created = 0;

    // Try to create the shared memories
    int g5tq_fd = shm_open("/gem5_to_questa", O_EXCL | O_CREAT | O_RDWR, 0666);
    int qtg5_fd = shm_open("/questa_to_gem5", O_EXCL | O_CREAT | O_RDWR, 0666);

    // Functional
    int g5tq_functional_fd = shm_open("/gem5_to_questa_functional", O_EXCL | O_CREAT | O_RDWR, 0666);
    int qtg5_functional_fd = shm_open("/questa_to_gem5_functional", O_EXCL | O_CREAT | O_RDWR, 0666);

    // The shared memory GEM5->QUESTA already exists
    if (g5tq_fd == -1)
    {
        g5tq_already_created = 1;

        // Try to open the already created shared memory
        g5tq_fd = shm_open("/gem5_to_questa", O_RDWR, 0666);

        // There is an error
        if (g5tq_fd == -1)
        {
            printf("/gem5_to_questa: shm_open failed\n");
            exit(EXIT_FAILURE);
        }
    }

    // The shared memory QUESTA->GEM5 already exists
    if (qtg5_fd == -1)
    {
        qtg5_already_created = 1;

        // Try to open the already created shared memory
        qtg5_fd = shm_open("/questa_to_gem5", O_RDWR, 0666);

        // There is an error
        if (qtg5_fd == -1)
        {
            printf("/questa_to_gem5: shm_open failed\n");
            exit(EXIT_FAILURE);
        }
    }

    // The shared memory GEM5->QUESTA FUNCTIONAL already exists
    if (g5tq_functional_fd == -1)
    {
        g5tq_functional_already_created = 1;

        // Try to open the already created shared memory
        g5tq_functional_fd = shm_open("/gem5_to_questa_functional", O_RDWR, 0666);

        // There is an error
        if (g5tq_functional_fd == -1)
        {
            printf("/gem5_to_questa_functional: shm_open failed\n");
            exit(EXIT_FAILURE);
        }
    }

    // The shared memory QUESTA->GEM5 FUNCTIONAL already exists
    if (qtg5_functional_fd == -1)
    {
        qtg5_functional_already_created = 1;

        // Try to open the already created shared memory
        qtg5_functional_fd = shm_open("/questa_to_gem5_functional", O_RDWR, 0666);

        // There is an error
        if (qtg5_functional_fd == -1)
        {
            printf("/questa_to_gem5_functional: shm_open failed\n");
            exit(EXIT_FAILURE);
        }
    }



    if (ftruncate(g5tq_fd, sizeof(struct Gem5ToQuestaQueue)) == -1) {
        close(g5tq_fd);
        printf("/gem5_to_questa: ftruncate failed\n");
        exit(EXIT_FAILURE);
    }

    if (ftruncate(qtg5_fd, sizeof(struct QuestaToGem5Queue)) == -1) {
        close(qtg5_fd);
        printf("/questa_to_gem5: ftruncate failed\n");
        exit(EXIT_FAILURE);
    }

     if (ftruncate(g5tq_functional_fd, sizeof(struct Gem5ToQuestaFunctionalQueue)) == -1) {
        close(g5tq_functional_fd);
        printf("/gem5_to_questa_functional: ftruncate failed\n");
        exit(EXIT_FAILURE);
    }

    if (ftruncate(qtg5_functional_fd, sizeof(struct QuestaToGem5FunctionalQueue)) == -1) {
        close(qtg5_functional_fd);
        printf("/questa_to_gem5_functional: ftruncate failed\n");
        exit(EXIT_FAILURE);
    }


    g5tq_queue = (struct Gem5ToQuestaQueue *) mmap( NULL, sizeof(struct Gem5ToQuestaQueue), PROT_READ | PROT_WRITE, MAP_SHARED, g5tq_fd, 0 );
    qtg5_queue = (struct QuestaToGem5Queue *) mmap( NULL, sizeof(struct QuestaToGem5Queue), PROT_READ | PROT_WRITE, MAP_SHARED, qtg5_fd, 0 );

    g5tq_functional_queue = (struct Gem5ToQuestaFunctionalQueue *) mmap( NULL, sizeof(struct Gem5ToQuestaFunctionalQueue), PROT_READ | PROT_WRITE, MAP_SHARED, g5tq_functional_fd, 0 );
    qtg5_functional_queue = (struct QuestaToGem5FunctionalQueue *) mmap( NULL, sizeof(struct QuestaToGem5FunctionalQueue), PROT_READ | PROT_WRITE, MAP_SHARED, qtg5_functional_fd, 0 );


    if (g5tq_queue == MAP_FAILED)
    {
        close(g5tq_fd);
        printf("/gem5_to_questa: mmap failed\n");
        exit(EXIT_FAILURE);
    }

    if (qtg5_queue == MAP_FAILED)
    {
        close(qtg5_fd);
        printf("/questa_to_gem5: mmap failed\n");
        exit(EXIT_FAILURE);
    }

    if (g5tq_functional_queue == MAP_FAILED)
    {
        close(g5tq_functional_fd);
        printf("/gem5_to_questa_functional: mmap failed\n");
        exit(EXIT_FAILURE);
    }

    if (qtg5_functional_queue == MAP_FAILED)
    {
        close(qtg5_functional_fd);
        printf("/questa_to_gem5_functional: mmap failed\n");
        exit(EXIT_FAILURE);
    }


    if (!g5tq_already_created)
    {
        memset(g5tq_queue, 0, sizeof(struct Gem5ToQuestaQueue));
    }

    if (!qtg5_already_created)
    {
        memset(qtg5_queue, 0, sizeof(struct QuestaToGem5Queue));
    }

    if (!g5tq_functional_already_created)
    {
        memset(g5tq_functional_queue, 0, sizeof(struct Gem5ToQuestaFunctionalQueue));
    }

    if (!qtg5_functional_already_created)
    {
        memset(qtg5_functional_queue, 0, sizeof(struct QuestaToGem5FunctionalQueue));
    }

    close(g5tq_fd);
    close(qtg5_fd);

    close(g5tq_functional_fd);
    close(qtg5_functional_fd);

    srand(time(NULL));

    g5tq_init(g5tq_queue);
    qtg5_init(qtg5_queue);

    g5tq_functional_init(g5tq_functional_queue);
    qtg5_functional_init(qtg5_functional_queue);

}

uint8_t gem5_send(uint64_t address, uint64_t data, uint8_t is_write)
{
    return g5tq_enqueue(g5tq_queue, address, data, is_write);
}

uint8_t gem5_receive(uint8_t* id, uint8_t* ack, uint64_t* data, uint8_t* clock_cycles)
{
    return qtg5_dequeue(qtg5_queue, id, ack, data, clock_cycles);
}

uint8_t questa_send(uint8_t id, uint8_t ack, uint64_t data, uint8_t clock_cycles)
{
    return qtg5_enqueue(qtg5_queue, id, ack, data, clock_cycles);
}

uint8_t questa_receive(uint8_t* id, uint64_t* address, uint64_t* data, uint8_t* is_write)
{
    return g5tq_dequeue(g5tq_queue, id, address, data, is_write);
}

uint8_t gem5_functional_send(uint64_t address, uint64_t data, uint8_t is_write)
{
    return g5tq_functional_enqueue(g5tq_functional_queue, address, data, is_write);
}

uint8_t gem5_functional_receive(uint8_t* id, uint8_t* ack, uint64_t* data, uint8_t* clock_cycles)
{
    return qtg5_functional_dequeue(qtg5_functional_queue, id, ack, data, clock_cycles);
}

uint8_t questa_functional_send(uint8_t id, uint8_t ack, uint64_t data, uint8_t clock_cycles)
{
    return qtg5_functional_enqueue(qtg5_functional_queue, id, ack, data, clock_cycles);
}

uint8_t questa_functional_receive(uint8_t* id, uint64_t* address, uint64_t* data, uint8_t* is_write)
{
    return g5tq_functional_dequeue(g5tq_functional_queue, id, address, data, is_write);
}


void finalize()
{
    shm_unlink("/gem5_to_questa");
    shm_unlink("/questa_to_gem5");
    shm_unlink("/gem5_to_questa_functional");
    shm_unlink("/questa_to_gem5_functional");
}

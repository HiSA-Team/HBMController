#ifndef CROSSSIM_H__
#define CROSSSIM_H__

__attribute__((visibility("default"))) void initialize();

__attribute__((visibility("default"))) uint8_t gem5_send(uint64_t address, uint64_t data, uint8_t is_write);
__attribute__((visibility("default"))) uint8_t gem5_receive(uint8_t* id, uint8_t* ack, uint64_t* data, uint8_t* clock_cycles);

__attribute__((visibility("default"))) uint8_t gem5_functional_send(uint64_t address, uint64_t data, uint8_t is_write);
__attribute__((visibility("default"))) uint8_t gem5_functional_receive(uint8_t* id, uint8_t* ack, uint64_t* data, uint8_t* clock_cycles);

__attribute__((visibility("default"))) uint8_t questa_send(uint8_t id, uint8_t ack, uint64_t data, uint8_t clock_cycles);
__attribute__((visibility("default"))) uint8_t questa_receive(uint8_t* id, uint64_t* address, uint64_t* data, uint8_t* is_write);

__attribute__((visibility("default"))) uint8_t questa_functional_send(uint8_t id, uint8_t ack, uint64_t data, uint8_t clock_cycles);
__attribute__((visibility("default"))) uint8_t questa_functional_receive(uint8_t* id, uint64_t* address, uint64_t* data, uint8_t* is_write);

__attribute__((visibility("default"))) void finalize();

#endif // CROSSSIM_H__

#include "learning_gem5/my_mem_ctrl/DpiMemCtrl.hh"
#include "sim/core.hh"
#include "sim/sim_exit.hh"
#include "mem/packet_access.hh"
#include "mem/request.hh"
#include "mem/packet.hh"
#include <dlfcn.h>
#include "base/time.hh"
#include "base/types.hh"

#include <unistd.h>

namespace gem5
{
	DpiMemCtrl::DpiMemCtrl(const DpiMemCtrlParams &params) : MemCtrl(params), sharedLibPath(params.shared_lib_path),
														     memoryEvent([this]{memoryResponseCallback();}, name())
	{
	    std::cout << curTick() << " -> DpiMemCtrl: starting constructor" << std::endl;

	    // Load shared library
	    void* handle;

	    if (!sharedLibPath.empty())
	    {
			handle = dlopen(sharedLibPath.c_str(), RTLD_LAZY | RTLD_GLOBAL);
			if (!handle)
			{
				panic("Failed to load shared library: %s\n", dlerror());
			}
	    }
	    else
	    {
			panic("No shared library path provided!");
	    }

	    // Initialize shared library functions
	    initialize = (void (*)()) dlsym(handle, "initialize");
	    gem5_send = (uint8_t (*)(uint64_t, uint64_t, uint8_t)) dlsym(handle, "gem5_send");
	    gem5_receive = (uint8_t (*)(uint8_t*, uint8_t*, uint64_t*, uint8_t*)) dlsym(handle, "gem5_receive");

		gem5_functional_send = (uint8_t (*)(uint64_t, uint64_t, uint8_t)) dlsym(handle, "gem5_functional_send");
	    gem5_functional_receive = (uint8_t (*)(uint8_t*, uint8_t*, uint64_t*, uint8_t*)) dlsym(handle, "gem5_functional_receive");

	    finalize = (void (*)()) dlsym(handle, "finalize");

	    if (!initialize || !gem5_send || !gem5_receive || !gem5_functional_send || !gem5_functional_receive || !finalize)
	    {
			panic("Failed to load required functions from shared library");
	    }

	    // Initialize shared memory
	    initialize();

		std::cout << curTick() << " -> DpiMemCtrl: ending constructor" << std::endl;
	}

	DpiMemCtrl::~DpiMemCtrl()
	{
	    // Destroy shared memory
	    finalize();
	}

	void DpiMemCtrl::memoryResponseCallback()
    {
        std::cout << curTick() << " -> DpiMemCtrl: starting memoryResponseCallback" << std::endl;
        ResponsePort* port = dynamic_cast<ResponsePort*>(&getPort("port"));

        if (port && port->isConnected())
            std::cout << "Connected to " << port->getPeer().name() << std::endl;

        // cpuRequestPacket must have been set by recvTimingReq for reads.
        if (!cpuRequestPacket) {
            std::cerr << curTick() << " -> DpiMemCtrl: ERROR: cpuRequestPacket is null in callback\n";
            return;
        }

        PacketPtr pkt = cpuRequestPacket;
        unsigned pktSize = pkt->getSize();
        uint8_t* pktPtr = pkt->getPtr<uint8_t>();

        std::cout << curTick() << " -> memoryResponseCallback: pkt addr=0x"
                  << std::hex << pkt->getAddr() << std::dec
                  << " size=" << pktSize
                  << " response_id=" << int(memoryResponse.id)
                  << " ack=" << int(memoryResponse.ack)
                  << " data=0x" << std::hex << memoryResponse.data << std::dec << std::endl;

		if (!pkt->isWrite()) {
				if (pktSize == 0) {
					std::cerr << "ERROR: packet size==0\n";
				} else if (!pktPtr) {
						std::cerr << "ERROR: packet has no data pointer\n";
				} else {
						// copy exactly the requested bytes (safely)
						unsigned toCopy = pktSize;
						if (toCopy > sizeof(memoryResponse.data)) {
							// Defensive: if gem5 ever asks > 8 bytes, copy only up to available
							std::cerr << "Warning: pktSize (" << pktSize << ") > 8, truncating copy\n";
							toCopy = sizeof(memoryResponse.data);
						}
						memcpy(pktPtr, &memoryResponse.data, toCopy);
				}
		}

        // mark timing response and send it back
        pkt->makeTimingResponse();

        if (!port->sendTimingResp(pkt)) {
            std::cout << "sendTimingResponse failed... scheduling retry\n";
            // schedule retry in 1 tick (simple retry logic)
            schedule(new EventFunctionWrapper([this, pkt]{
                ResponsePort* p = dynamic_cast<ResponsePort*>(&getPort("port"));
                if (!p->sendTimingResp(pkt)) {
                    std::cerr << "sendTimingResp retry failed — dropping packet (bug)\n";
                }
            }, name()), curTick() + 1);
        } else {
            std::cout << "sendTimingResponse succeeded!\n";
        }

        // clear stored pointer (single outstanding request model)
        cpuRequestPacket = nullptr;
    }

    bool DpiMemCtrl::recvTimingReq(PacketPtr pkt)
    {
        std::cout << curTick() << " -> DpiMemCtrl: starting recvTimingReq" << std::endl;

        uint64_t addr = pkt->getAddr();
        bool is_write = pkt->isWrite();
        unsigned pktSize = pkt->getSize();

        std::cout << "recvTimingReq: addr=0x" << std::hex << addr << std::dec
                  << " size=" << pktSize << " is_write=" << is_write << std::endl;

        // Extract write data only if this is a write and size>0
       	uint64_t data = 0;
		if (is_write) {
			const uint8_t* src = pkt->getConstPtr<uint8_t>();
			if (!src) {
				std::cerr << "recvTimingReq: WARNING write packet has no data ptr\n";
			}
			/* else {
				if (pktSize < sizeof(uint64_t)) {
				std::cerr << "recvTimingReq: ERROR write smaller than 8 bytes: " << pktSize << std::endl;
			}*/
			memcpy(&data, src, sizeof(pktSize));
		}

        // send to external shared lib (blocking receive follows)
        gem5_send(addr, data, (uint8_t)is_write);
        // std::cout << "gem5_send() called\n";

        // blocking receive
        while (!gem5_receive(&memoryResponse.id, &memoryResponse.ack,
                             &memoryResponse.data, &memoryResponse.clock_cycles)) {
            // You might want a tiny sleep or yield in some environments, but
            // keep it simple for now (you wanted blocking).
        }

        // compute delay in ticks (same as your code)
        double ratio = static_cast<double>(memoryResponse.clock_cycles) / DpiMemCtrl::FREQUENCY;
        Tick offset = static_cast<Tick>(ratio * sim_clock::Frequency);

        // if (!is_write) {
            // store packet pointer for callback (single-request model)
            cpuRequestPacket = pkt;
            schedule(memoryEvent, curTick() + offset);
        /* } else {
            // for writes: optionally create a response now, or make the protocol
            // such that writes are acknowledged through memoryResponse. For safety:
            pkt->makeTimingResponse();
            ResponsePort* port = dynamic_cast<ResponsePort*>(&getPort("port"));
            if (!port->sendTimingResp(pkt)) {
                std::cout << "sendTimingResp for write failed, scheduling retry\n";
                schedule(new EventFunctionWrapper([this, pkt]{
                    ResponsePort* p = dynamic_cast<ResponsePort*>(&getPort("port"));
                    if (!p->sendTimingResp(pkt)) {
                        std::cerr << "sendTimingResp retry for write failed — dropping packet\n";
                    }
                }, name()), curTick() + 1);
            }
        }*/

        std::cout << curTick() << " -> DpiMemCtrl: exiting recvTimingReq" << std::endl;
        return true;
    }

	void DpiMemCtrl::recvFunctional(PacketPtr pkt)
	{
		uint64_t addr = pkt->getAddr();
		unsigned size = pkt->getSize();
		uint8_t *ptr = pkt->getPtr<uint8_t>();

		if (!ptr) {
			pkt->makeResponse();
			return;
		}

		std::cout << "Functional: Pkt addr: " << addr << " Size: " << size << " Ptr: " << *ptr << std::endl;

		uint8_t resp = 0, ack = 0;
		uint64_t data = 0;
		uint8_t clock_cycles = 0;

		uint64_t data_to_write = 0;

		// unsigned int transactions = 0;
		unsigned int last_transaction = 0;

		if (pkt->isWrite()) {

			// Get how many transactions of 64 bits
			// transactions  = size/64;
			last_transaction = size%64;

			unsigned int i = 0;
			for (i = 0; i < size; i += 8) {
				memcpy(&data_to_write, ptr, sizeof(uint64_t));
				while(!gem5_functional_send(addr, data_to_write, (uint8_t) 1)); // write
				std::cout << "gem5_send() called : " << data_to_write << std::endl;
    			// while(!gem5_receive(&resp, &ack, &data, &clock_cycles)){ // wait for response
				// }
				ptr = ptr + 8;
				addr = addr + 8;
			}

			if (last_transaction != 0) {
				data_to_write = 0;
				memcpy(&data_to_write, ptr, sizeof(last_transaction));
				while(!gem5_functional_send(addr, data_to_write, (uint8_t) 1)); // write
				std::cout << "gem5_send() called\n";
				// while(!gem5_receive(&resp, &ack, &data, &clock_cycles)){ // wait for response
				// }
			}

		} else {
			// TODO: fix this
			// read from Questa via gem5_send / gem5_receive
			for (unsigned int i = 0; i < size; i++) {
				gem5_send(addr + i, 0, 0); // 0 = is_read
				while(!gem5_receive(&resp, &ack, &data, &clock_cycles));
				ptr[i] = data;
			}
		}

		pkt->makeResponse();
	}

	Tick DpiMemCtrl::recvAtomic(PacketPtr pkt)
	{
		Addr addr = pkt->getAddr();
		unsigned size = pkt->getSize();
		uint8_t *ptr = pkt->getPtr<uint8_t>();

		if (!ptr) {
			pkt->makeAtomicResponse();
			return 0;
		}

		if (pkt->isWrite()) {
			for (unsigned int i = 0; i < size; i++){
				uint64_t addr64 = static_cast<uint64_t>(addr + i);
    			uint64_t data64 = static_cast<uint64_t>(ptr[i]);
    			gem5_send(addr64, data64, 1); // write
    			uint8_t resp, ack;
    			while(!gem5_receive(&resp, &ack, nullptr, nullptr)); // wait for response
			}
		} else {
			for (unsigned i = 0; i < size; i++) {
				gem5_send(addr + i, 0, 0);
				uint8_t data = 0;
				while(!gem5_receive(&data, nullptr, nullptr, nullptr));
				ptr[i] = data;
			}
		}

		pkt->makeAtomicResponse();
		return 0;
	}
}

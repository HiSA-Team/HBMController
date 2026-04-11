
#ifndef __DPI_MEM_CTRL_HH__
#define __DPI_MEM_CTRL_HH__

#include "mem/mem_ctrl.hh"
#include "params/DpiMemCtrl.hh"
#include "sim/eventq.hh"
#include "mem/packet.hh"


namespace gem5
{
	class DpiMemCtrl : public memory::MemCtrl
	{
	  public:
	    DpiMemCtrl(const DpiMemCtrlParams &p);
	    ~DpiMemCtrl();

	    void (*initialize)();
	    uint8_t (*gem5_send)(uint64_t, uint64_t, uint8_t);
	    uint8_t (*gem5_receive)(uint8_t*, uint8_t*, uint64_t*, uint8_t*);

		uint8_t (*gem5_functional_send)(uint64_t, uint64_t, uint8_t);
	    uint8_t (*gem5_functional_receive)(uint8_t*, uint8_t*, uint64_t*, uint8_t*);

	    void (*finalize)();

	    bool recvTimingReq(PacketPtr pkt) override;

		// These are used by gem5 to load the elf
		void recvFunctional(PacketPtr pkt) override;
    	Tick recvAtomic(PacketPtr pkt) override;

	  private:
	    std::string sharedLibPath; // To store the shared library path
		static constexpr uint32_t FREQUENCY = 450000000; //450 MHz

		struct MemoryResponse
		{
			uint8_t id, ack, clock_cycles;
			uint64_t data;
		} memoryResponse;

		PacketPtr cpuRequestPacket;

		void memoryResponseCallback();

		EventFunctionWrapper memoryEvent;
	};
}

#endif

import m5
from m5.objects import *

system = System()

# Clock
system.clk_domain = SrcClockDomain()
system.clk_domain.clock = '1GHz'
system.clk_domain.voltage_domain = VoltageDomain()

# Mode and memory range
system.mem_mode = 'timing'
system.mem_ranges = [AddrRange('512MB')]

# CPU
system.cpu = X86TimingSimpleCPU()

# System crossbar
system.membus = SystemXBar()

# Connection CPU with the crossbar
system.cpu.icache_port = system.membus.cpu_side_ports
system.cpu.dcache_port = system.membus.cpu_side_ports

# I/O, interrupt controller and functional connection
system.cpu.createInterruptController()
system.cpu.interrupts[0].pio = system.membus.mem_side_ports
system.cpu.interrupts[0].int_requestor = system.membus.cpu_side_ports
system.cpu.interrupts[0].int_responder = system.membus.mem_side_ports
system.system_port = system.membus.cpu_side_ports

# Memory system, controller, DDR ...
# system.mem_ctrl = MemCtrl()
system.mem_ctrl = DpiMemCtrl(
    shared_lib_path="/absolute/path/to/HBMController/CrossSim/crosssim/bin/crosssim.so"
)
system.mem_ctrl.dram = DDR3_1600_8x8()
system.mem_ctrl.dram.range = system.mem_ranges[0]
# system.mem_ctrl.range = system.mem_ranges[0]
system.mem_ctrl.port = system.membus.mem_side_ports


# Program to execute
binary = 'tests/test-progs/hello/bin/x86/linux/hello' # Change this to your test executable
system.workload = SEWorkload.init_compatible(binary)
process = Process()
process.cmd = [binary]
system.cpu.workload = process
system.cpu.createThreads()

# Root and instantiation
root = Root(full_system = False, system = system)
m5.instantiate()

# Simulate
print("Beginning simulation!")
exit_event = m5.simulate()

# End simulation infos
print('Exiting @ tick {} because {}'
      .format(m5.curTick(), exit_event.getCause()))


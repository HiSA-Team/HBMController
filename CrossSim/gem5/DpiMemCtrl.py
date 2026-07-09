from m5.objects import MemCtrl
from m5.params import *

class DpiMemCtrl(MemCtrl):
    type = 'DpiMemCtrl'
    cxx_class = 'gem5::DpiMemCtrl'
    cxx_header = 'learning_gem5/my_mem_ctrl/DpiMemCtrl.hh'
    shared_lib_path = Param.String("", "Path to the shared library")



import pyrogue
import rogue.interfaces.stream
import time
import numpy as n
import os

# load the multiprocessing library functions needed
from multiprocessing import Process, Lock, Pipe

## load for parsing of configuration file
#import configparser

# load the data writer
import rogueFreeStreamRaw_PyMod as freeStream


#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# get the home directory
""" temporarily disable the configuration read
configfile = os.path.join(os.environ['HOME'],'python/python-lib/lzrd_rogue/lzrd_phase1_config')    # temporarily hardcoded until I find a better way to do this

config = configparser.ConfigParser(converters={
    'iarr': lambda arrstr: n.fromstring(arrstr, dtype=n.int64, sep=','), 
    'farr': lambda arrstr: n.fromstring(arrstr, dtype=n.float64, sep=','),
    'tupple': lambda arrstr: tuple(n.fromstring(arrstr, dtype=n.int64, sep=','))})
a=config.read(configfile)

# How many digitizers are there?
DIGI_BOARD_NUM = config['DIGITIZER'].getint('board_num')
# get the digitizer ID mapping
DIGI_BOARD_INDEX = {}
for i in range(DIGI_BOARD_NUM):
    digikey = 'DIGI_BOARD_%d' %(i)
    # get the IDs of the digitizers
    tid = config[digikey].getint('id')
    DIGI_BOARD_INDEX[tid] = i

"""
DIGI_BOARD_NUM = n.array(1, dtype=n.float64)
DIGI_BOARD_INDEX = {0:0}


UINT64_VERSION_OF_32 = n.uint64(32)


#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Stream processors
class StreamProc(rogue.interfaces.stream.Slave):
    
    def __init__(self, stime, sevts, realTimeSim = False):
        # initialize interfaces
        rogue.interfaces.stream.Slave.__init__(self)
        
        # store the setting used to indicate that we are simulating waveforms
        self.realTimeSim = realTimeSim
        # Keep track of the dead time
        self.running_deadtime = 0
        # Create locks and pipes
        self.lock = Lock()
        self.parent_conn, self.child_conn = Pipe()        
        # pass the main running function to a separate thread
        self.processor = Process(target=sevts.run_subprocess, args=(self.lock, self.child_conn))
        self.processor.start()
        # keep track of times
        self.t0 = time.time()   # initial time for frame generation
        self.ft0 = stime
    
    def __del__(self):
        # 
        rogue.interfaces.stream.Slave.__del__(self)
    
    def end(self):
        # send the command to end the execution
        self.parent_conn.send((True, None, 0))
        self.parent_conn.close()
        self.processor.join()   # rejoin the terminated tread
        self.processor.terminate()
        del self.processor
    
    def _acceptFrame(self,frame):
        cframe = bytearray(frame.getPayload())
        frame.read(cframe,0)
        #
        #rdata = n.frombuffer(cframe, dtype=n.uint32, count=4, offset=len(cframe)-16)
        #fstarttime = (n.uint64(rdata[0]) << UINT64_VERSION_OF_32) + n.uint64(rdata[1])
        #fendtime = (n.uint64(rdata[2]) << UINT64_VERSION_OF_32) + n.uint64(rdata[3])
        # temporarily disable the frame start and end reading since they don't exist yet. 
        fstarttime = n.uint64(0)
        fendtime = n.uint64(0)
        framelen = n.int64(fendtime)-fstarttime
        #print(self.running_deadtime, framelen)
        if self.realTimeSim:
            # enable real time distribution of waveforms
            fcurrenttime = (fendtime-self.ft0)/1e9
            currenttime = (time.time()-self.t0)
            if currenttime < fcurrenttime:
                time.sleep(fcurrenttime-currenttime)
        #print('framelen', framelen)
        # add a frame to the streamer
        # make sure there is no data waiting to be picked up by the processor
        child_conn_stat = self.child_conn.poll()
        if not child_conn_stat:
            # pipe is empty. Check if the processor has the thread locked. If not, send the frame
            lockstatus = self.lock.acquire(block=False) # aquire lock if the processor isn't busy
            #print('loop lockstatus is', lockstatus, child_conn_stat)
            if lockstatus:
                # Send current frame to the processor along with the pre-frame dead time
                #print("Sending data")
                self.parent_conn.send((False, cframe, self.running_deadtime))
                self.lock.release()
                # wait until the child process confirms that it got the data. This is needed for synchronization since the processor tends to be slower than the parent process hence the parent process might jump to the next frame before the processor is finished reading the current one.
                # I know that it's not great since it means that this process can hang if the processor takes too long but I couldn't think of a way to give the processor enough time to finish reading the data (before the parent process tries to send another frame) without putting an artifical sleep in the processor or the parent or making the processor use 100% of the cpu (stuck in a full speed while True loop)
                self.parent_conn.recv_bytes()    # this was sent after the processor aquired a lock
                # reset the dead time
                self.running_deadtime = 0
            else:
                self.running_deadtime += framelen
        else:
            self.running_deadtime += framelen



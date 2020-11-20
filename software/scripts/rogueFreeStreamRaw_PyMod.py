
# This is meant to be run in python 3.4 or higher

# This module is a basic, raw writer of the DAQ data to disk.

from __future__ import print_function

import numpy as n
import time, calendar

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

LZ_EPOCH_STRING = '20150101T0000'
#LZ_EPOCH_DATETIME_DT = datetime.strptime(LZ_EPOCH_STRING, '%Y%m%dT%H%M')
LZ_EPOCH_DATETIME = n.uint64(calendar.timegm(time.strptime(LZ_EPOCH_STRING, '%Y%m%dT%H%M')) * 1e9)

NS_PER_S_UINT64 = n.uint64(1e9)

UINT64_VERSION_OF_32 = n.uint64(32)

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


class processStream:
    def __init__(self, digi_time_at_start_ns, outfile_base='data/lzrd_sue_raw', buffer_size_bytes=1048576, buffer_write_timeout_s = 60, max_file_size_bytes = 1073741824, verbose=0):
        """
        
        """
        # store verbose level. 0 means no output. 1 mean minimum output. And so forth
        self.verbose = verbose
        # start time of the acquisition. Technically, it's the time this object got instantiated 
        # minus whatever offset needed
        self.abs_starttime_ns = n.uint64(time.time()*1e9) - LZ_EPOCH_DATETIME - n.uint64(digi_time_at_start_ns)
        
        
        # create a base of a filename to write to
        gmtime = time.gmtime((self.abs_starttime_ns+LZ_EPOCH_DATETIME)/1e9)
        timestamp = time.strftime('%Y%m%dT%H%M%S', gmtime)
        self.outfile_base = "%s_%s" %(outfile_base, timestamp)
        
        self.outfile_handle = None
        self.max_file_size_bytes = max_file_size_bytes
        self.current_file_ind = 0
        
        # initialize a buffer for storing the events before writing them. 
        self.write_buffer = bytearray()
        ## A simple byte object that we continously append to and delete may be too slow. So, try a fixed bytearray
        #self.write_buffer = bytearray(int(buffer_size_bytes*2))
        #self.write_buffer_size = 0
        # turns out that, with what I'm trying right now, the fixed bytearray isn't any faster
        # keep track of when we last wrote the data to a buffer
        self.last_buffer_write = time.time()
        # file write variables
        self.buffer_size_bytes = buffer_size_bytes
        self.buffer_write_timeout_s = buffer_write_timeout_s
        
        # get the info string for this data set
        self.acq_string = self.construct_acq_string()
        
    def __del__(self):
        """
        Event destructor. It writes the remaining frames to file.
        ____________________________________________________________________
        Inputs:
        
        Optional:
            
        ____________________________________________________________
        Returns:
        
        """
        if self.verbose > 1:
            print("processStream instance destructor started")
        
        self.write_final()
        if self.verbose > 1:
            print("processStream instance destructor executed after final file write")
    
    def run_subprocess(self, lock, conn):
        """
        function executed from a separate thread
        ____________________________________________________________________
        Inputs:
            lock
                The lock object needed for safe threading
                
            conn
                The pipe object used for communication
            
        Optional:
            
        ____________________________________________________________
        Returns:
        
        """
        while True:
            # the conn.recv call will cause this thread to stop and wait for input
            break_condition, frame_bytes, deadtime = conn.recv()
            if break_condition:
                # exit loop and end function if told to do
                break
            lockstatus = lock.acquire()
            try:
                # let the parent process know that the processor is working
                conn.send_bytes(b'1')
                self.write_ready(frame_bytes, deadtime=deadtime)
            finally:
                lock.release()
        # initiate final write
        self.write_final()
    
    def new_file(self):
        """
        Open a new file 
        ____________________________________________________________________
        Inputs:
        
        Optional:
            
        ____________________________________________________________
        Returns:
        
        """
        filename = "%s_%05d.dat" %(self.outfile_base, self.current_file_ind)
        self.outfile_handle = open(filename, 'bw')
        self.current_file_ind += 1  # increment file index
        # write the endian check string
        self.outfile_handle.write(n.array([0x01020304]).astype('<u4').tostring())
        # write out settings
        self.outfile_handle.write(n.array([len(self.acq_string)]).astype('<u4').tostring())
        self.outfile_handle.write(self.acq_string)
        if self.verbose > 3:
            print("Opened file %s of initial size %d" %(filename, len(setting_string) + 8))
    
    def construct_acq_string(self):
        """
        Constructs an event header string
        ____________________________________________________________________
        Inputs:
        
        Optional:
           
            
        ____________________________________________________________
        Returns:
            A binary setting string and the size of the settings string.
        """
        # Store some info.
        # event timestamp
        timestamp_highbits = n.uint32(self.abs_starttime_ns >> UINT64_VERSION_OF_32)    # timestamp_highbits
        timestamp_lowbits = n.uint32(self.abs_starttime_ns)
        acq_header_string = b"acqStartTime_ns_high:"
        acq_header_string +=timestamp_highbits.tostring()
        acq_header_string += b"acqStartTime_ns_low:"
        acq_header_string += timestamp_lowbits.tostring()
        # attach the length of the entry
        acq_header_string = n.array([len(acq_header_string)]).astype('<u4').tostring() + acq_header_string
        return acq_header_string

    
    def write_ready(self, frame_bytes, deadtime=0):
        """
        Add a new frame to the write buffer.
        ____________________________________________________________________
        Inputs:
            frame_bytes
                The byte string frame
            
        Optional:
            deadtime = 0
                The dead time to prepend before each frame.
        ____________________________________________________________
        Returns:
        
        """
        # open file for writing if None open
        if self.outfile_handle is None: self.new_file()
        # store the dead time along with the size of the current frame
        deadtime = n.uint64(deadtime)
        deadtime_highbits = n.uint32(deadtime >> UINT64_VERSION_OF_32)
        deadtime_lowbits = n.uint32(deadtime)
        deadtime_string = b"deadtime_ns_high:"
        deadtime_string +=deadtime_highbits.tostring()
        deadtime_string += b"deadtime_ns_low:"
        deadtime_string += deadtime_lowbits.tostring()
        self.write_buffer.extend(n.array([len(deadtime_string) + len(frame_bytes)]).astype('<u4').tostring())
        self.write_buffer.extend(deadtime_string)
        # append data
        self.write_buffer.extend(frame_bytes)
        # write the event if needed
        write_buffer_len = len(self.write_buffer)
        if self.verbose > 5: print("writing to buffer of total size %d bytes" %(write_buffer_len))
        current_time = time.time()  # current time for timeout purposes
        if (write_buffer_len > self.buffer_size_bytes) or \
            ((current_time - self.last_buffer_write) > self.buffer_write_timeout_s):
            # If the buffer size limit or timeout are reached, the buffer
            # will be written.
            print("writing file")
            self.outfile_handle.write(self.write_buffer)
            if self.verbose > 3:
                print("Dumping buffer of size %d to file after %.2f seconds" %(write_buffer_len, (current_time - self.last_buffer_write)))
            # clear the buffer
            self.write_buffer.clear()
            self.last_buffer_write = current_time
        # check if file should be closed
        if self.outfile_handle.tell() >= self.max_file_size_bytes:
            # reached maximum file size
            self.outfile_handle.close() # close file
            self.outfile_handle = None  # clear variable
    
    def write_final(self):
        """
        
        ____________________________________________________________________
        Inputs:
        
        Optional:
            
        ____________________________________________________________
        Returns:
        
        """
        if self.verbose > 2:
            print("Entered write_final with %d PODs left to write" %(len(self.waveforms)))
        write_buffer_len = len(self.write_buffer)
        if write_buffer_len > 0:
            # open file for writing if None open
            if self.outfile_handle is None: self.new_file()
            # write the event if needed
            write_buffer_len = len(self.write_buffer)
            if self.verbose > 5: print("writing to buffer of total size %d bytes" %(write_buffer_len))
            # write the buffer
            self.outfile_handle.write(self.write_buffer)
            # clear the buffer
            self.write_buffer.clear()
            current_time = time.time()  # current time
            self.last_buffer_write = current_time
            # close the file
            self.outfile_handle.close() # close file
            self.outfile_handle = None  # clear variable
    




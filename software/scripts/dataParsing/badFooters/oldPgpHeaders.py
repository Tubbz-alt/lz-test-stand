
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import sys


f=open('oldPgpData/testFrameDataOldPGP_board-02-03-05-04_packetsOff_0001.dat', mode='rb') 

data = f.read()
f.close()
len(data)

################################################################
#print all headers
################################################################
# convert to 32 bit words to easily look into data writer header
dataU32 = np.frombuffer(data, dtype='uint32')
dwOffset8 = 0
goodPackets = 0
badPackets = 0
timeMax = 0.0
timeMin = sys.float_info.max
while dwOffset8 < len(data):
   header = np.frombuffer(data, dtype='uint16', count=12, offset=dwOffset8+8)
   timeCur = ((header[11] << 48) | (header[10] << 32) | (header[9] << 16) | header[8])/250000000.0
   if timeCur < timeMin:
      timeMin = timeCur
   if timeCur > timeMax:
      timeMax = timeCur
   if header[0] != 1 or header[1] != 0:
      badPackets = badPackets + 1
   else:
      goodPackets = goodPackets + 1
   print('# PKT: Offset %d, size %d, ID %d' %(dwOffset8, dataU32[int(dwOffset8/4)], dataU32[int(dwOffset8/4)+1]>>24))
   print('Header time %f' %(timeCur))
   if header[3] & 0xf000 == 0:
      print('Header ADC type fast')
   else:
      print('Header ADC type slow')
   print('Header ADC channel %d' %(header[2]&0xff))
   dwOffset8 = dwOffset8 + dataU32[0] + 4
print('####: Good packets %d, bad packets %d, min time %f, max time %f' %(goodPackets, badPackets, timeMin, timeMax))


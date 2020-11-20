
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# uncomment one file to look into particular example
# old PGP card with 4 boards - all footers are correct
#f=open('oldPgpData/testFrameDataOldPGP_board-02-03-05-04_packetsOn-timeout-1000ms_0001.dat', mode='rb')  
#f=open('oldPgpData/testFrameDataOldPGP_board-02-03-05-04_packetsOn-timeout-10ms_0001.dat', mode='rb')  
f=open('oldPgpData/testFrameDataOldPGP_board-02_packetsOn-timeout-10ms_0001.dat', mode='rb')  


data = f.read()
f.close()
len(data)


################################################################
#print all footers
################################################################
# convert to 32 bit words to easily look into data writer header
dataU32 = np.frombuffer(data, dtype='uint32')
dwOffset8 = int(dataU32[0])+4
goodPackets = 0
badPackets = 0
first = True
while dwOffset8 < len(data):
   # copy footer from the end of the packet
   footer = np.frombuffer(data, dtype='uint16', count=24, offset=dwOffset8-24*2)
   
   # print content of the footer
   dnaL = int((footer[11] << 48) | (footer[10] << 32) | (footer[9] << 16) | footer[8])
   dnaL = dnaL & 0xffffffffffffffff
   if dnaL != 0x8DAC810100008004:
      badPackets = badPackets + 1
      print('################## Offset %d, Bad DNA_L %x != 0x8DAC810100008004' %(dwOffset8, dnaL))
   else:
      goodPackets = goodPackets + 1
      print('################## Offset %d, Good DNA_L %x == 0x8DAC810100008004' %(dwOffset8, dnaL))
   
   print('Footer time max %f' %(( ((footer[3] << 48) | (footer[2] << 32) | (footer[1] << 16) | footer[0])/250000000.0  )))
   print('Footer time min %f' %(( ((footer[7] << 48) | (footer[6] << 32) | (footer[5] << 16) | footer[4])/250000000.0  )))
   print('Footer DNA_L 0x%04X%04X%04X%04X' %( footer[11] ,footer[10] ,footer[9] , footer[8] ))
   print('Footer DNA_H 0x%04X%04X%04X%04X' %( footer[15] ,footer[14] ,footer[13], footer[12] ))
   print('Footer lost flag %d' %(footer[16] & 0x1))
   print('Footer ext flag %d' %((footer[16]>>1) & 0x1))
   print('Footer int flag %d' %((footer[16]>>2) & 0x1))
   print('Footer empty flag %d' %((footer[16]>>3) & 0x1))
   print('Footer veto flag %d' %((footer[16]>>4) & 0x1))
   print('Footer bad ADC flag %d' %((footer[16]>>5) & 0x1))
   
   # move offset to next packet
   dwOffset8=dwOffset8+dataU32[int(dwOffset8/4)]+4
print('####: Good packets %d, bad packets %d' %(goodPackets, badPackets))

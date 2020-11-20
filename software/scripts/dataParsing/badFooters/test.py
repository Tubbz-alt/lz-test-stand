
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


# new PGP card with 4 boards - there are corrupted packets (bad footers)!!!
#f=open('newPgpData/testFrameData_board-02-03-05-04_packetsOn-timeout-1000ms_0001.dat', mode='rb') 


#f=open('testFrameData_board-14_badFrameEndTimes_0000.dat', mode='rb') 
f=open('grabData.dat', mode='rb') 



#new PGP card with 1 board - there are corrupted packets (bad footers)!!!
#f=open('newPgpData/testFrameData_board-02_packetsOn-timeout-1000ms_0001.dat', mode='rb') 

data = f.read()
f.close()
len(data)


################################################################
#print all footers
################################################################
# convert to 32 bit words to easily look into data writer header
dataU32 = np.frombuffer(data, dtype='uint32')
endOffset8 = int(dataU32[0])+4
goodPackets = 0
badPackets = 0
first = True
while endOffset8 < len(data):
   # copy footer from the end of the packet
   footer = np.frombuffer(data, dtype='uint16', count=24, offset=endOffset8-24*2)
   
   # print content of the footer
   dnaL = int((footer[11] << 48) | (footer[10] << 32) | (footer[9] << 16) | footer[8])
   dnaL = dnaL & 0xffffffffffffffff
   if dnaL != 0x8DAC810100008004:
      badPackets = badPackets + 1
      print('################## Offset %d, Bad DNA_L %x != 0x8DAC810100008004' %(endOffset8, dnaL))
   else:
      goodPackets = goodPackets + 1
      print('################## Offset %d, Good DNA_L %x == 0x8DAC810100008004' %(endOffset8, dnaL))
   
   print('Footer time max %f (%X %X %X %X)' %(( ((footer[3] << 48) | (footer[2] << 32) | (footer[1] << 16) | footer[0])/250000000.0, footer[3], footer[2], footer[1], footer[0])  ))
   maxTime = ((footer[3] << 48) | (footer[2] << 32) | (footer[1] << 16) | footer[0])/250000000.0
   print('Footer time min %f (%X %X %X %X)' %(( ((footer[7] << 48) | (footer[6] << 32) | (footer[5] << 16) | footer[4])/250000000.0, footer[7], footer[6], footer[5], footer[4])  ))
   minTime = ((footer[7] << 48) | (footer[6] << 32) | (footer[5] << 16) | footer[4])/250000000.0
   if minTime > maxTime:
      print('--------------- BAD TIME -------------------')
   print('Footer DNA_L 0x%04X%04X%04X%04X' %( footer[11] ,footer[10] ,footer[9] , footer[8] ))
   print('Footer DNA_H 0x%04X%04X%04X%04X' %( footer[15] ,footer[14] ,footer[13], footer[12] ))
   print('Footer lost flag %d' %(footer[16] & 0x1))
   print('Footer ext flag %d' %((footer[16]>>1) & 0x1))
   print('Footer int flag %d' %((footer[16]>>2) & 0x1))
   print('Footer empty flag %d' %((footer[16]>>3) & 0x1))
   print('Footer veto flag %d' %((footer[16]>>4) & 0x1))
   print('Footer bad ADC flag %d' %((footer[16]>>5) & 0x1))
   
   # move offset to next packet
   endOffset8=endOffset8+dataU32[int(endOffset8/4)]+4
print('####: Good packets %d, bad packets %d' %(goodPackets, badPackets))



for i in range(0, 24):
   print('%04X' %(footer[i]))



###########################################
# look at and analyse one super packet
###########################################

##bad timestamp in the footer
#startOffset = 4194732+8
#endOffset = 7897808


##bad timestamp in the footer
#startOffset = 17336392+8
#endOffset = 25314688

##bad timestamp in the footer
#startOffset = 28460876+8
#endOffset = 30643732

#bad timestamp in the footer
startOffset = 30643732+8
endOffset = 31692380

##all good
#startOffset = 1048648+8
#endOffset = 2097412

##all good
#startOffset = 2097412+8
#endOffset = 3146084

##all good
#startOffset = 34838500+8
#endOffset = 35887352


int((endOffset-startOffset)/2)

adcChannles = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
adcSizeMax = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

superPacket = np.frombuffer(data, dtype='uint16', count=int((endOffset-startOffset)/2), offset=startOffset)

# get first trigger size and other header data
trigSize = ((superPacket[5] & 0x3F) << 16) | superPacket[4]
trigTime = ((superPacket[11] << 48) | (superPacket[10] << 32) | (superPacket[9] << 16) | superPacket[8])/250000000.0
trigChannel = superPacket[2] & 0xF
if superPacket[3] & 0xF000 != 0:
   trigChannel = trigChannel + 8
adcChannles[trigChannel] = adcChannles[trigChannel] + 1

if adcSizeMax[trigChannel] < trigSize:
   adcSizeMax[trigChannel] = trigSize

packet = 0
print('Pkt %d: channel %d, size %d, time %f' %(packet, trigChannel, trigSize, trigTime))

trigTimeMin = trigTime
trigTimeMax = trigTime

if trigSize%2 != 0:
   trigSize = trigSize + 1
nextOffset = trigSize+12

# scan all folowing trggers
while nextOffset < len(superPacket)-24:
   packet = packet + 1
   trigSize = ((superPacket[5+nextOffset] & 0x3F) << 16) | superPacket[4+nextOffset]
   trigTime = ((superPacket[11+nextOffset] << 48) | (superPacket[10+nextOffset] << 32) | (superPacket[9+nextOffset] << 16) | superPacket[8+nextOffset])/250000000.0
   trigChannel = superPacket[2+nextOffset] & 0xF
   if superPacket[3+nextOffset] & 0xF000 != 0:
      trigChannel = trigChannel + 8
   adcChannles[trigChannel] = adcChannles[trigChannel] + 1
   if adcSizeMax[trigChannel] < trigSize:
      adcSizeMax[trigChannel] = trigSize
   if trigTime < trigTimeMin:
      trigTimeMin = trigTime
   if trigTime > trigTimeMax:
      trigTimeMax = trigTime
   print('Pkt %d, offset %d: channel %d, size %d, time %f (%X %X %X %X)' %(packet, nextOffset, trigChannel, trigSize, trigTime, superPacket[11+nextOffset], superPacket[10+nextOffset], superPacket[9+nextOffset], superPacket[8+nextOffset]))
   
   if trigSize%2 != 0:
      trigSize = trigSize + 1
   
   nextOffset = nextOffset + trigSize+12


#offsetSel=524354
#for i in range(offsetSel, offsetSel+12):
#   print('%04X' %(superPacket[i]))

for i in range(0, 12):
   print('%04X' %(superPacket[i]))
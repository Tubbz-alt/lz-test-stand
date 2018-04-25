
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

f=open('Lane0_sigleFrameDataBinary5.dat', mode='rb')  


data = f.read()
f.close()
len(data)


################################################################
# Print seleced POD header
################################################################

#header = np.frombuffer(data, dtype='uint16', count=12, offset=(192+12)*2)
for i in range(0, 12):
   print('%d %04x' %(i, header[i]))


#Found repeated time stamp pairs in ADC channel 0
#[1723, 1735, 5419, 5433]
#Found repeated time stamp pairs in ADC channel 1
#[1631, 1643, 4933, 4945, 4993, 5005]
#Found repeated time stamp pairs in ADC channel 3
#[999, 1013, 6101, 6115, 6143, 6157]
#Found repeated time stamp pairs in ADC channel 4
#[4603, 4617]
#Found repeated time stamp pairs in ADC channel 5
#[23, 37]
#

#verifyPods = [4933, 4945] # empty triggers with INT_POST_S ???
verifyPods = [703, 707] 

dataOffset = 0

for podNo in range(0, max(verifyPods)+1):
   header = np.frombuffer(data, dtype='uint16', count=12, offset=dataOffset)

   adcCh    = header[2] & 0xFF
   if ((header[3] & 0xF000) >> 12) == 0:
      adcType = 'fast'
   else:
      adcType = 'slow'
   debugInfo= header[1]
   isFooter = header[3] & 0x1
   trigSize = ((header[5] & 0x3F) << 16) | header[4]
   trigOfs  = (header[7] << 16) | header[6]
   fastOfs  = (header[5] & 0x180) >> 7
   lostFlg  = (header[5] & 0x40) >> 6
   extFlg   = (header[5] & 0x800) >> 11
   intFlg   = (header[5] & 0x1000) >> 12
   emptyFlg = (header[5] & 0x2000) >> 13
   vetoFlg  = (header[5] & 0x4000) >> 14
   badAFlg  = (header[5] & 0x8000) >> 15
   trigTime = (header[11] << 48) | (header[10] << 32) | (header[9] << 16) | header[8]
   
   
   if podNo in verifyPods:
      print('############ POD number: %d ############' %(podNo))
      print('ADC channel %d' %(adcCh))
      print('ADC type %s' %(adcType))
      print('Footer present %d' %(isFooter))
      print('Trig size %d' %(trigSize))
      print('Trig offset %d' %(trigOfs))
      print('Fast ADC sample offset %d' %(fastOfs))
      print('Lost flag %d' %(lostFlg))
      print('Ext flag %d' %(extFlg))
      print('Int flag %d' %(intFlg))
      print('Empty flag %d' %(emptyFlg))
      print('Veto flag %d' %(vetoFlg))
      print('Bad ADC flag %d' %(badAFlg))
      print('Header time %d' %(trigTime))
      if adcType == 'fast':
         print('Debug info %s' %(format(debugInfo, 'b')))
      #save data in csv file
      fileName = 'POD' + str(podNo) +'_ch' + str(adcCh) + adcType + '_T' + str(trigTime)
      #f = open(fileName, 'w')
      adcData = np.frombuffer(data, dtype='uint16', count=trigSize, offset=dataOffset+24)
      
      plt.plot(adcData, '.')
      plt.savefig(fileName + '.png')
      plt.clf()
      plt.close()
      
      f = open(fileName + '.csv', 'w')
      for i in range(len(adcData)):
         f.write('%d,' %(adcData[i]))
      f.write('\n')
      f.close()
      
   
   #check for bad ADC flag
   if badAFlg == 1:
      print('########################## Bad ADC flag in POD %d' %(podNo))
   
   # correct odd trigSize
   if trigSize%2 != 0:
      trigSize = trigSize + 1
   
   #move to next offset
   dataOffset = dataOffset + (trigSize+12)*2
   
   if dataOffset > len(data):
      print("No more data for POD number %d" %(podNo+1))
      break
   
################################################################
# Find repeated timestamps in all channels
################################################################

timeStamps = [{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}]
repeatedStamps = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
dataOffset = 0
podNo = 0
countRepPods = 0

while True:
   header = np.frombuffer(data, dtype='uint16', count=12, offset=dataOffset)

   adcCh    = header[2] & 0xFF
   if ((header[3] & 0xF000) >> 12) == 1:
      adcCh = adcCh + 8
   trigSize = ((header[5] & 0x3F) << 16) | header[4]
   trigTime = (header[11] << 48) | (header[10] << 32) | (header[9] << 16) | header[8]
   
   for podNoPrev, trigTimePrev in timeStamps[adcCh].items():
      if trigTimePrev == trigTime:
         repeatedStamps[adcCh].append(podNoPrev)
         repeatedStamps[adcCh].append(podNo)
         countRepPods = countRepPods + 2
   
   timeStamps[adcCh][podNo] = trigTime
   
   # correct odd trigSize
   if trigSize%2 != 0:
      trigSize = trigSize + 1
   
   #move to next offset
   dataOffset = dataOffset + (trigSize+12)*2
   
   podNo = podNo + 1
   
   if dataOffset >= (len(data)-48):
      print("No more data for POD number %d" %(podNo))
      break

# print results
# can use the POD pair numbers to print details (above)
for i in range(0, 16):
   if len(repeatedStamps[i]) > 0:
      print("Found repeated time stamp pairs in ADC channel %d" %(i))
      print(repeatedStamps[i])


################################################################
# Check if any of the pods stored in repeatedStamps is: 
# - internal type
# - slow ADC type
################################################################

# flaten the repeatedStamps list
verifyPods = []
for i in range (0, 16):
   if len(repeatedStamps[i]) == 0:
      continue
   verifyPods.extend(repeatedStamps[i])
podNo       = 0
dataOffset  = 0
while True:
   header = np.frombuffer(data, dtype='uint16', count=12, offset=dataOffset)

   adcCh    = header[2] & 0xFF
   if ((header[3] & 0xF000) >> 12) == 0:
      adcType = 'fast'
   else:
      adcType = 'slow'
   isFooter = header[3] & 0x1
   trigSize = ((header[5] & 0x3F) << 16) | header[4]
   trigOfs  = (header[7] << 16) | header[6]
   fastOfs  = (header[5] & 0x180) >> 7
   lostFlg  = (header[5] & 0x40) >> 6
   extFlg   = (header[5] & 0x800) >> 11
   intFlg   = (header[5] & 0x1000) >> 12
   emptyFlg = (header[5] & 0x2000) >> 13
   vetoFlg  = (header[5] & 0x4000) >> 14
   badAFlg  = (header[5] & 0x8000) >> 15
   trigTime = (header[11] << 48) | (header[10] << 32) | (header[9] << 16) | header[8]
   
   
   if podNo in verifyPods:
      if intFlg == 0:
         print("Pod number %d is not internal type" %(podNo))
      if adcType != 'fast':
         print("Pod number %d is not fast ADC type" %(podNo))
      if emptyFlg != 0:
         print("Pod number %d is empty type" %(podNo))
   
   # correct odd trigSize
   if trigSize%2 != 0:
      trigSize = trigSize + 1
   
   #move to next offset
   dataOffset = dataOffset + (trigSize+12)*2
   
   podNo = podNo + 1
   
   if dataOffset > len(data):
      print("No more data for POD number %d" %(podNo))
      print("Verified %d repeated time PODs" %(len(verifyPods)))
      print("Expected %d repeated time PODs" %(countRepPods))
      break


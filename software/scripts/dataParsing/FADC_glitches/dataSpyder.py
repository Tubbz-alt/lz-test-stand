
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

#%%

#f=open('lane1_glitches.dat', mode='rb')  
f=open('fastGlitches1.dat', mode='rb')  

data = f.read()
f.close()
len(data)

#%%

################################################################
# Print seleced POD header
################################################################

#header = np.frombuffer(data, dtype='uint16', count=12, offset=(192+12)*2)
#for i in range(0, 12):
#   print('%d %04x' %(i, header[i]))

#%%

dataOffset = 8
podNo = 0

while 1:
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
   
   adcData = np.frombuffer(data, dtype='uint16', count=trigSize, offset=dataOffset+24)
   #print('############ POD number: %d ############' %(podNo))
   #print('ADC max %d' %(max(adcData)))
   #print('ADC min %d' %(min(adcData)))
   
   if max(adcData) > 39000 or min(adcData) < 27000:
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
      print('ADC max %d' %(max(adcData)))
      print('ADC min %d' %(min(adcData)))
      #save data in csv file
      fileName = 'POD' + str(podNo) +'_ch' + str(adcCh) + adcType + '_T' + str(trigTime)
      
      if podNo == 741:
          break
      
      #plt.plot(adcData, '.')
      #plt.savefig(fileName + '.png')
      #plt.clf()
      #plt.close()
      
      #f = open(fileName + '.csv', 'w')
      #for i in range(len(adcData)):
      #   f.write('%d\n' %(adcData[i]))
      #f.write('\n')
      #f.close()
      
   
   #check for bad ADC flag
   if badAFlg == 1:
      print('########################## Bad ADC flag in POD %d' %(podNo))
   
   # correct odd trigSize
   if trigSize%2 != 0:
      trigSize = trigSize + 1
   
   #move to next offset
   dataOffset = dataOffset + (trigSize+12)*2 + 8
   
   podNo = podNo + 1
   
   if dataOffset > len(data):
      print("No more data for POD number %d" %(podNo+1))
      break

#%%

fig = plt.figure(1,figsize=(12,8),dpi=150)
plt.plot(bins)
print(len(adcData))

#%%

bins = 2**16 * [0]
for i in range(len(adcData)):
    bins[adcData[i]] = bins[adcData[i]] + 1

#%%

for i in range(2**16):
    if bins[i] != 0:
        print('bin %d val %d'%(i, bins[i]))


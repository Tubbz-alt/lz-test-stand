#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : local waveform viewer for the LZTS digitizer
#-----------------------------------------------------------------------------
# File       : lztsViewer.py
# Author     : Maciej Kwiatkowski
# Created    : 2017-25-07
# Last update: 2017-25-07
#-----------------------------------------------------------------------------
# Description:
# Simple wave viewer that enble a local feedback from data collected using
# LZTS digitizer. Based on Dionisio's Doering ePix viewer
#
#-----------------------------------------------------------------------------
# This file is part of the LZTS rogue. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the LZTS rogue, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import sys
import os
import math
import rogue.utilities
import rogue.utilities.fileio
import rogue.interfaces.stream
import pyrogue    
import time
from PyQt4 import QtGui, QtCore
from PyQt4.QtGui import *
from PyQt4.QtCore import QObject, pyqtSignal
import numpy as np
from matplotlib.backends.backend_qt4agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from itertools import count, takewhile

import pdb


PRINT_VERBOSE = 1

################################################################################
################################################################################
#   Window class
#   Implements the screen that display all images.
#   Calls other classes defined in this file to properly read and process
#   the images in a givel file
################################################################################
class Window(QtGui.QMainWindow, QObject):
    """Class that defines the main window for the viewer."""
    
    ## Define a new signal called 'trigger' that has no arguments.
    dataTrigger = pyqtSignal()
    #processDataFrameTrigger = pyqtSignal()


    def __init__(self):
        super(Window, self).__init__()    
        # window init
        self.mainWdGeom = [50, 50, 1100, 600] # x, y, width, height
        self.setGeometry(self.mainWdGeom[0], self.mainWdGeom[1], self.mainWdGeom[2],self.mainWdGeom[3])
        self.setWindowTitle("LZTS data viewer")

        # add actions for menu item
        extractAction = QtGui.QAction("&Quit", self)
        extractAction.setShortcut("Ctrl+Q")
        extractAction.setStatusTip('Leave The App')
        extractAction.triggered.connect(self.close_viewer)

        # display status tips for all menu items (or actions)
        self.statusBar()

        # Creates the main menu, 
        mainMenu = self.menuBar()
        # adds items and subitems
        fileMenu = mainMenu.addMenu('&File')
        fileMenu.addAction(extractAction)

        # Create widget
        self.prepairWindow()
        
        # rogue interconection  #
        # Create the objects            
        self.eventReaderData = EventReader(self)
        self.enabled = [False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False]
        
        # Connect the trigger signal to a slot.
        # the different threads send messages to synchronize their tasks
        self.dataTrigger.connect(self.displayDataFromReader)
        #self.processDataFrameTrigger.connect(self.eventReaderData._processFrame)
        
        # display the window on the screen after all items have been added 
        self.show()


    def prepairWindow(self):
        # Center UI
        self.imageScaleMax = int(10000)
        self.imageScaleMin = int(-10000)
        screen = QtGui.QDesktopWidget().screenGeometry(self)
        size = self.geometry()
        self.buildUi()


    #creates the main display element of the user interface
    def buildUi(self):
        
        # left hand side layout
        self.mainWidget = QtGui.QWidget(self)
        vbox = QVBoxLayout()
        
        
        self.SadcCh0 = QtGui.QCheckBox('SADC Ch0')
        self.SadcCh1 = QtGui.QCheckBox('SADC Ch1')
        self.SadcCh2 = QtGui.QCheckBox('SADC Ch2')
        self.SadcCh3 = QtGui.QCheckBox('SADC Ch3')
        self.SadcCh4 = QtGui.QCheckBox('SADC Ch4')
        self.SadcCh5 = QtGui.QCheckBox('SADC Ch5')
        self.SadcCh6 = QtGui.QCheckBox('SADC Ch6')
        self.SadcCh7 = QtGui.QCheckBox('SADC Ch7')
        self.FadcCh0 = QtGui.QCheckBox('FADC Ch0')
        self.FadcCh1 = QtGui.QCheckBox('FADC Ch1')
        self.FadcCh2 = QtGui.QCheckBox('FADC Ch2')
        self.FadcCh3 = QtGui.QCheckBox('FADC Ch3')
        self.FadcCh4 = QtGui.QCheckBox('FADC Ch4')
        self.FadcCh5 = QtGui.QCheckBox('FADC Ch5')
        self.FadcCh6 = QtGui.QCheckBox('FADC Ch6')
        self.FadcCh7 = QtGui.QCheckBox('FADC Ch7')
        self.enableNone = QtGui.QRadioButton('Off')
        self.enableFFT  = QtGui.QRadioButton('FFT')
        self.enableHist = QtGui.QRadioButton('Histogram')
        self.enableNone.setChecked(1);
        
        controlFrame = QtGui.QFrame()
        controlFrame.setFrameStyle(QtGui.QFrame.Panel);
        controlFrame.setGeometry(100, 200, 0, 0)
        controlFrame.setLineWidth(1);
        
        # add widgets into tab2
        grid = QtGui.QGridLayout()
        grid.setSpacing(5)
        grid.setColumnMinimumWidth(0, 1)
        grid.setRowMinimumHeight(1, 30)
        grid.setRowMinimumHeight(2, 30)
        grid.setRowMinimumHeight(3, 30)
        grid.addWidget(controlFrame,0,0,4,9)
        grid.addWidget(self.SadcCh0, 1, 1)
        grid.addWidget(self.SadcCh1, 1, 2)
        grid.addWidget(self.SadcCh2, 1, 3)
        grid.addWidget(self.SadcCh3, 1, 4)
        grid.addWidget(self.SadcCh4, 1, 5)
        grid.addWidget(self.SadcCh5, 1, 6)
        grid.addWidget(self.SadcCh6, 1, 7)
        grid.addWidget(self.SadcCh7, 1, 8)
        grid.addWidget(self.FadcCh0, 2, 1)
        grid.addWidget(self.FadcCh1, 2, 2)
        grid.addWidget(self.FadcCh2, 2, 3)
        grid.addWidget(self.FadcCh3, 2, 4)
        grid.addWidget(self.FadcCh4, 2, 5)
        grid.addWidget(self.FadcCh5, 2, 6)
        grid.addWidget(self.FadcCh6, 2, 7)
        grid.addWidget(self.FadcCh7, 2, 8)
        grid.addWidget(self.enableNone, 3, 1)
        grid.addWidget(self.enableFFT,  3, 2)
        grid.addWidget(self.enableHist, 3, 3)

        # line plot 1
        self.lineDisplay1 = MplCanvas(MyTitle = "ADC Samples Display")
        hSubbox2 = QHBoxLayout()
        hSubbox2.addWidget(self.lineDisplay1)
        
        # line plot 2
        self.lineDisplay2 = MplCanvas(MyTitle = "FFT/Histogram Display")        
        hSubbox3 = QHBoxLayout()
        hSubbox3.addWidget(self.lineDisplay2)
        
        vbox.addLayout(grid)
        vbox.addLayout(hSubbox2)
        vbox.addLayout(hSubbox3)
        
        self.mainWidget.setLayout(vbox)
        self.mainWidget.setFocus()        
        self.setCentralWidget(self.mainWidget)
  
    # checks if the user really wants to exit
    def close_viewer(self):
        choice = QtGui.QMessageBox.question(self, 'Quit!',
                                            "Do you want to quit viewer?",
                                            QtGui.QMessageBox.Yes | QtGui.QMessageBox.No)
        if choice == QtGui.QMessageBox.Yes:
            print("Exiting now...")
            sys.exit()
        else:
            pass


    def displayDataFromReader(self):
        # converts bytes to array of dwords
        chData = [bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray()]
        for i in range(0, 16):
            chData[i] = np.frombuffer(self.eventReaderData.channelDataArray[i], dtype='uint16')
            # currently header is 12 x 16 bit words (will be more)
            # read header information
            trigSamples = 0
            if len(chData[i]) >= 11:
               trigSamples = ((chData[i][5] << 16) | chData[i][4])&0x3fffff
               
               #print(len(chData[i][12:]))
            
            # check how many samples in the trigger
            # the packet can be padded with extra zeros (2 bytes)
            if trigSamples < len(chData[i][12:]):
               chData[i] = chData[i][12:12+trigSamples]
            else:
               chData[i] = chData[i][12:]
            
            
            
            #if (PRINT_VERBOSE): 
            
            if (len(chData[i]) > 0):
                print('Channel %d, min ADU %d, max ADU %d, Vpp %f' %(i, min(chData[i]), max(chData[i]), (max(chData[i])-min(chData[i]))/2**16*2.0 ))
        
        
        self.enabled = [self.SadcCh0.isChecked(), self.SadcCh1.isChecked(), self.SadcCh2.isChecked(), self.SadcCh3.isChecked(), 
                        self.SadcCh4.isChecked(), self.SadcCh5.isChecked(), self.SadcCh6.isChecked(), self.SadcCh7.isChecked(),
                        self.FadcCh0.isChecked(), self.FadcCh1.isChecked(), self.FadcCh2.isChecked(), self.FadcCh3.isChecked(), 
                        self.FadcCh4.isChecked(), self.FadcCh5.isChecked(), self.FadcCh6.isChecked(), self.FadcCh7.isChecked()]
        colors = ['xkcd:blue',    
                  'xkcd:brown',   
                  'xkcd:black',   
                  'xkcd:coral',   
                  'xkcd:cyan',    
                  'xkcd:darkblue',
                  'xkcd:aqua',    
                  'xkcd:fuchsia', 
                  'xkcd:gold',    
                  'xkcd:green',   
                  'xkcd:magenta', 
                  'xkcd:olive',   
                  'xkcd:orange',  
                  'xkcd:purple',  
                  'xkcd:red',     
                  'xkcd:plum']
        
        labels = ["SADC Channel 0",
                  "SADC Channel 1",
                  "SADC Channel 2",
                  "SADC Channel 3",
                  "SADC Channel 4",
                  "SADC Channel 5",
                  "SADC Channel 6",
                  "SADC Channel 7",
                  "FADC Channel 0",
                  "FADC Channel 1",
                  "FADC Channel 2",
                  "FADC Channel 3",
                  "FADC Channel 4",
                  "FADC Channel 5",
                  "FADC Channel 6",
                  "FADC Channel 7"]
        
        
        self.lineDisplay1.update_plot( self.enabled, chData, colors, labels)
        if self.enableHist.isChecked():
            self.lineDisplay2.update_fft( self.enabled, chData, colors, labels, 1)
        elif self.enableFFT.isChecked():
            self.lineDisplay2.update_fft( self.enabled, chData, colors, labels, 2)
        else:
            self.lineDisplay2.update_fft( self.enabled, chData, colors, labels, 0)
        self.eventReaderData.busy = False
        
        if (PRINT_VERBOSE): print('Display done')

################################################################################
################################################################################
#   Event reader class
#   
################################################################################
class EventReader(rogue.interfaces.stream.Slave):
    """retrieves data from a file using rogue utilities services"""

    def __init__(self, parent) :
        rogue.interfaces.stream.Slave.__init__(self)
        super(EventReader, self).__init__()
        self.enable = True
        self.chReceived = [False]*16
        self.enabledCh = [False]*16
        self.lastFrame = rogue.interfaces.stream.Frame
        self.channelDataArray = [bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray()]
        self.parent = parent
        self.lastTime = 0
        #############################
        # define the data type IDs
        #############################
        self.VIEW_DATA_CHANNEL_ID    = 0x1
        self.busy = False
        self.busyTimeout = 0
        


    # Checks all frames in the file to look for the one that needs to be displayed
    # self.frameIndex defines which frame should be returned.
    # Once the frame is found, saves data and emits a signal do enable the class window
    # to dislplay it. The emit signal is needed because only that class' thread can 
    # access the screen.
    def _acceptFrame(self,frame):
        
        
        self.enabledCh = [self.parent.SadcCh0.isChecked(), self.parent.SadcCh1.isChecked(), self.parent.SadcCh2.isChecked(), self.parent.SadcCh3.isChecked(), 
                          self.parent.SadcCh4.isChecked(), self.parent.SadcCh5.isChecked(), self.parent.SadcCh6.isChecked(), self.parent.SadcCh7.isChecked(),
                          self.parent.FadcCh0.isChecked(), self.parent.FadcCh1.isChecked(), self.parent.FadcCh2.isChecked(), self.parent.FadcCh3.isChecked(), 
                          self.parent.FadcCh4.isChecked(), self.parent.FadcCh5.isChecked(), self.parent.FadcCh6.isChecked(), self.parent.FadcCh7.isChecked()]
        
        
        self.lastFrame = frame
        # reads entire frame
        p = bytearray(self.lastFrame.getPayload())
        self.lastFrame.read(p,0)
        VcNum =  p[0] & 0xF
        if (VcNum == self.VIEW_DATA_CHANNEL_ID):
            
            # print basic info
            trigSamples = 0
            trigOffset = 0
            trigTime = 0
            if (PRINT_VERBOSE): print('Received packet size is %d' %(len(p)))
            if len(p) >= 24:
                dataConv = np.frombuffer(p, dtype='uint16', count=12)
                trigSamples = ((dataConv[5] << 16) | dataConv[4])&0x3fffff
                trigOffset = (dataConv[7] << 16) | dataConv[6]
                trigTime = (dataConv[11] << 48) | (dataConv[10] << 32) | (dataConv[9] << 16) | dataConv[8]
                if (PRINT_VERBOSE): print('Trigger size is %d samples' %(trigSamples))
                if (PRINT_VERBOSE): print('Trigger offset is %d samples' %(trigOffset))
                if (PRINT_VERBOSE): print('Trigger time is %f' %(trigTime/250000000.0))
            
            
            # sort ADC channels
            # copy data only when display is not busy
            if self.busy == False:
                chIndex = 0
                if ((p[7] & 0x10)>>4 == 1):
                    if (PRINT_VERBOSE): print('Slow ADC channnel: ', (p[4] & 0xFF))
                    chIndex = (p[4] & 0xFF)
                    self.channelDataArray[chIndex][:] = p
                # sort fast ADC channels
                elif ((p[7] & 0x10)>>4 == 0):
                    if (PRINT_VERBOSE): print('Fast ADC channnel: ', (p[4] & 0xFF))
                    chIndex = 8+(p[4] & 0xFF)
                    self.channelDataArray[chIndex][:] = p
                    
                self.chReceived[chIndex] = True
                testAllData = np.array_equal(np.logical_or(np.logical_not(self.enabledCh), np.logical_and(self.chReceived, self.enabledCh)), [True]*16)
                # Emit the signal but no more often than every 0.5s
                # do not emit unless data for all enabled channels arrived
                if (self.lastTime == 0 or (trigTime-self.lastTime>int(math.ceil(0.5/0.000000004)))) and testAllData == True:
                    self.parent.dataTrigger.emit()
                    self.chReceived = [False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False]
                    self.busy = True
                    self.lastTime = trigTime
            #busy timeout (5 seconds)
            elif (trigTime-self.lastTime) > int(math.ceil(5/0.000000004)):
                self.busy = False

################################################################################
################################################################################
#   Matplotlib class
#   
################################################################################
class MplCanvas(FigureCanvas):
    """This is a QWidget derived from FigureCanvasAgg."""


    def __init__(self, parent=None, width=5, height=4, dpi=100, MyTitle=""):

        self.fig = Figure(figsize=(width, height), dpi=dpi)
        self.axes = self.fig.add_subplot(111)

        self.compute_initial_figure()

        FigureCanvas.__init__(self, self.fig)
        self.setParent(parent)
        FigureCanvas.setSizePolicy(self, QtGui.QSizePolicy.Expanding, QtGui.QSizePolicy.Expanding)
        FigureCanvas.updateGeometry(self)
        self.MyTitle = MyTitle
        self.axes.set_title(self.MyTitle)
        self.fig.cbar = None

        

    def compute_initial_figure(self):
        #if one wants to plot something at the begining of the application fill this function.
        #self.axes.plot([0, 1, 2, 3], [1, 2, 0, 4], 'b')
        self.axes.plot([], [], 'b')
    
    def update_plot(self, enabled, chData, colors, labels):

        self.axes.cla()
        for i in range(0, 16):
            N = len(chData[i])
            if (N > 0 and enabled[i] == True):
                self.axes.plot(chData[i], colors[i], label=labels[i])
                self.axes.legend() 
        self.axes.set_title(self.MyTitle)
        self.draw()

    def update_fft(self, enabled, chData, colors, labels, plotSel):
        self.axes.cla()
        for i in range(0, 16):
            # Number of samplepoints
            N = len(chData[i])
            if (N > 0 and enabled[i] == True):
                if plotSel == 1:
                    binwidth = 1
                    rms = np.sqrt(np.mean((chData[i]-np.mean(chData[i]))**2))
                    #label = labels[i] + ' (RMS ' + str(rms) + ')' 
                    label = "%s (RMS %.2f)" %(labels[i] ,rms) 
                    self.axes.hist(chData[i], bins=range(min(chData[i]), max(chData[i]) + binwidth, binwidth), normed=1, facecolor=colors[i], label=label, histtype='bar')
                    #self.axes.hist(chData[i], bins=list(self.my_frange(start=min(chData[i]), stop=max(chData[i]), step=0.5)), normed=1, facecolor=colors[i], label=labels[i], histtype='stepfilled')
                    self.axes.legend() 
                elif plotSel == 2:
                    # sample spacing
                    if (i<8):
                        T = 1.0 / 250000000.0
                    else:
                        T = 1.0 / 1000000000.0
                    yf = np.fft.rfft(chData[i]*np.hanning(N))
                    #yf = np.fft.rfft(chData[i])
                    #print(np.hanning(N))
                    #print(np.hanning(N)*chData[i])
                    yf = np.fft.rfft(chData[i])
                    xf = np.linspace(0.0, 1.0/(2.0*T), N/2)
                    #freq = np.fft.fftfreq(N, d=4e-9)
                    #self.axes.plot(freq[:len(yf)], yf, colors[i], label=labels[i])
                    self.axes.semilogx(xf[1:], np.abs(yf[1:N//2]), colors[i], label=labels[i])
                    self.axes.legend()  
        self.axes.set_title(self.MyTitle)
        self.draw()
       
    def my_frange(self, start, stop, step):
        return takewhile(lambda x: x< stop, count(start, step))        
    
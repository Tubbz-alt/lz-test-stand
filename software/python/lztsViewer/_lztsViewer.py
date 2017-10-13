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
    processDataFrameTrigger = pyqtSignal()


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
        
        # Connect the trigger signal to a slot.
        # the different threads send messages to synchronize their tasks
        self.dataTrigger.connect(self.displayDataFromReader)
        self.processDataFrameTrigger.connect(self.eventReaderData._processFrame)
        
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
        self.enableFFT = QtGui.QCheckBox('Enable FFT')
        
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
        grid.addWidget(self.enableFFT, 3, 1)  

        # line plot 1
        self.lineDisplay1 = MplCanvas(MyTitle = "ADC Samples Display")
        hSubbox2 = QHBoxLayout()
        hSubbox2.addWidget(self.lineDisplay1)
        
        # line plot 2
        self.lineDisplay2 = MplCanvas(MyTitle = "FFT Display")        
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
            if (i<8):
                chData[i] = np.frombuffer(self.eventReaderData.channelDataArray[i], dtype='uint16')
            else:
                chData[i] = np.frombuffer(self.eventReaderData.channelDataArray[i], dtype='int16')
            
            # currently header is 12 x 16 bit words (will be more)
            # read header information
            trigSamples = 0
            trigOffset = 0
            if len(chData[i]) >= 11:
               trigSamples = (chData[i][5] << 16) | chData[i][4]
               trigOffset = (chData[i][7] << 16) | chData[i][6]
               print('Trigger size is %d samples' %(trigSamples))
               print('Trigger offset is %d samples' %(trigOffset))
               #print(len(chData[i][12:]))
            
            # check how many samples in the trigger
            # the packet can be padded with extra zeros (2 bytes)
            if trigSamples < len(chData[i][12:]):
               chData[i] = chData[i][12:trigSamples]
            else:
               chData[i] = chData[i][12:]
            
            
            
            
        
        
        enabled = [self.SadcCh0.isChecked(), self.SadcCh1.isChecked(), self.SadcCh2.isChecked(), self.SadcCh3.isChecked(), 
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
        
        
        self.lineDisplay1.update_plot( enabled, chData, colors, labels)
        if self.enableFFT.isChecked():
            self.lineDisplay2.update_fft( enabled, chData, colors, labels)
        
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
        self.numAcceptedFrames = 0
        self.numProcessFrames  = 0
        self.lastFrame = rogue.interfaces.stream.Frame
        self.frameDataArray = [bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray()]
        self.channelDataArray = [bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray(),bytearray()]
        self.parent = parent
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
        
        self.lastFrame = frame
        # reads entire frame
        p = bytearray(self.lastFrame.getPayload())
        self.lastFrame.read(p,0)
        if (PRINT_VERBOSE): print('_accepted p[',self.numAcceptedFrames, ']: ', p[0:4])
        if (PRINT_VERBOSE): print('_accepted p[',self.numAcceptedFrames, ']: ', p[4:8])
        if (PRINT_VERBOSE): print('_accepted p[',self.numAcceptedFrames, ']: ', p[8:12])
        if (PRINT_VERBOSE): print('_accepted p[',self.numAcceptedFrames, ']: ', p[12:16])
        self.frameDataArray[self.numAcceptedFrames%16][:] = p#bytearray(self.lastFrame.getPayload())
        self.numAcceptedFrames += 1

        VcNum =  p[0] & 0xF
        if (self.busy): 
            self.busyTimeout = self.busyTimeout + 1
            print("Event Reader Busy: " +  str(self.busyTimeout))
            if self.busyTimeout == 10:
                self.busy = False
        else:
            self.busyTimeout = 0

        if ((VcNum == self.VIEW_DATA_CHANNEL_ID) and (not self.busy)):
            self.parent.processDataFrameTrigger.emit()


    def _processFrame(self):

        index = self.numProcessFrames%16
        self.numProcessFrames += 1
        if ((self.enable) and (not self.busy)):
            self.busy = True
            
            # reads payload only
            p = self.frameDataArray[index] 
            # reads entire frame
            VcNum =  p[0] & 0xF
            if (PRINT_VERBOSE): print('-------- Frame ',self.numAcceptedFrames,'Channel flags',self.lastFrame.getFlags(), ' Vc Num:' , VcNum)
            
            #during stream chNumId is not assigned so these ifs cannot be used to distiguish the frames
            if (VcNum == self.VIEW_DATA_CHANNEL_ID) :
                #view data
                if (PRINT_VERBOSE): print('Num. data readout: ', len(p))
                # sort slow ADC channnels
                if ((p[7] & 0x10)>>4 == 1):
                    if (PRINT_VERBOSE): print('Slow ADC channnel: ', (p[4] & 0xFF))
                    self.channelDataArray[(p[4] & 0xFF)][:] = p
                # sort fast ADC channnels
                elif ((p[7] & 0x10)>>4 == 0):
                    if (PRINT_VERBOSE): print('Fast ADC channnel: ', (p[4] & 0xFF))
                    self.channelDataArray[8+(p[4] & 0xFF)][:] = p
                # Emit the signal.
                self.parent.dataTrigger.emit()


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

    def update_fft(self, enabled, chData, colors, labels):
        self.axes.cla()
        for i in range(0, 16):
            # Number of samplepoints
            N = len(chData[i])
            if (N > 0 and enabled[i] == True):
                # sample spacing
                if (i<8):
                    T = 1.0 / 250000000.0
                else:
                    T = 1.0 / 1000000000.0
                #yf = np.fft.rfft(chData[i]*np.hanning(N))
                yf = np.fft.rfft(chData[i])
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
        
    
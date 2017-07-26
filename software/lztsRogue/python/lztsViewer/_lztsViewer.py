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
        grid.addWidget(controlFrame,0,0,3,9)
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

        # line plot 1
        self.lineDisplay1 = MplCanvas(MyTitle = "SADC Display")
        hSubbox2 = QHBoxLayout()
        hSubbox2.addWidget(self.lineDisplay1)
        
        # line plot 2
        self.lineDisplay2 = MplCanvas(MyTitle = "FADC Display")        
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
        sadcCh0Data  = np.frombuffer(self.eventReaderData.sadcCh0Data, dtype='uint16')
        sadcCh1Data  = np.frombuffer(self.eventReaderData.sadcCh1Data, dtype='uint16')
        sadcCh2Data  = np.frombuffer(self.eventReaderData.sadcCh2Data, dtype='uint16')
        sadcCh3Data  = np.frombuffer(self.eventReaderData.sadcCh3Data, dtype='uint16')
        sadcCh4Data  = np.frombuffer(self.eventReaderData.sadcCh4Data, dtype='uint16')
        sadcCh5Data  = np.frombuffer(self.eventReaderData.sadcCh5Data, dtype='uint16')
        sadcCh6Data  = np.frombuffer(self.eventReaderData.sadcCh6Data, dtype='uint16')
        sadcCh7Data  = np.frombuffer(self.eventReaderData.sadcCh7Data, dtype='uint16')
        fadcCh0Data  = np.frombuffer(self.eventReaderData.fadcCh0Data, dtype='uint16')
        fadcCh1Data  = np.frombuffer(self.eventReaderData.fadcCh1Data, dtype='uint16')
        fadcCh2Data  = np.frombuffer(self.eventReaderData.fadcCh2Data, dtype='uint16')
        fadcCh3Data  = np.frombuffer(self.eventReaderData.fadcCh3Data, dtype='uint16')
        fadcCh4Data  = np.frombuffer(self.eventReaderData.fadcCh4Data, dtype='uint16')
        fadcCh5Data  = np.frombuffer(self.eventReaderData.fadcCh5Data, dtype='uint16')
        fadcCh6Data  = np.frombuffer(self.eventReaderData.fadcCh6Data, dtype='uint16')
        fadcCh7Data  = np.frombuffer(self.eventReaderData.fadcCh7Data, dtype='uint16')
        # limits trace length for fast display (may be removed in the future)

        #header are 5 32 bit words
        sadcCh0Data  = sadcCh0Data[12:]
        sadcCh1Data  = sadcCh1Data[12:]
        sadcCh2Data  = sadcCh2Data[12:]
        sadcCh3Data  = sadcCh3Data[12:]
        sadcCh4Data  = sadcCh4Data[12:]
        sadcCh5Data  = sadcCh5Data[12:]
        sadcCh6Data  = sadcCh6Data[12:]
        sadcCh7Data  = sadcCh7Data[12:]
        fadcCh0Data  = fadcCh0Data[12:]
        fadcCh1Data  = fadcCh1Data[12:]
        fadcCh2Data  = fadcCh2Data[12:]
        fadcCh3Data  = fadcCh3Data[12:]
        fadcCh4Data  = fadcCh4Data[12:]
        fadcCh5Data  = fadcCh5Data[12:]
        fadcCh6Data  = fadcCh6Data[12:]
        fadcCh7Data  = fadcCh7Data[12:]
        
        self.lineDisplay1.update_plot(  self.SadcCh0.isChecked(), "SADC Channel 0", 'b',  sadcCh0Data, 
                                        self.SadcCh1.isChecked(), "SADC Channel 1", 'b',  sadcCh1Data,
                                        self.SadcCh2.isChecked(), "SADC Channel 2", 'b',  sadcCh2Data,
                                        self.SadcCh3.isChecked(), "SADC Channel 3", 'b',  sadcCh3Data,
                                        self.SadcCh4.isChecked(), "SADC Channel 4", 'b',  sadcCh4Data,
                                        self.SadcCh5.isChecked(), "SADC Channel 5", 'b',  sadcCh5Data,
                                        self.SadcCh6.isChecked(), "SADC Channel 6", 'b',  sadcCh6Data,
                                        self.SadcCh7.isChecked(), "SADC Channel 7", 'b',  sadcCh7Data)
        
        self.lineDisplay2.update_plot(  self.FadcCh0.isChecked(), "SADC Channel 0", 'b',  fadcCh0Data,
                                        self.FadcCh1.isChecked(), "SADC Channel 1", 'b',  fadcCh1Data,
                                        self.FadcCh2.isChecked(), "SADC Channel 2", 'b',  fadcCh2Data,
                                        self.FadcCh3.isChecked(), "SADC Channel 3", 'b',  fadcCh3Data,
                                        self.FadcCh4.isChecked(), "SADC Channel 4", 'b',  fadcCh4Data,
                                        self.FadcCh5.isChecked(), "SADC Channel 5", 'b',  fadcCh5Data,
                                        self.FadcCh6.isChecked(), "SADC Channel 6", 'b',  fadcCh6Data,
                                        self.FadcCh7.isChecked(), "SADC Channel 7", 'b',  fadcCh7Data)
        
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
        self.fadcCh0Data = bytearray()
        self.fadcCh1Data = bytearray()
        self.fadcCh2Data = bytearray()
        self.fadcCh3Data = bytearray()
        self.fadcCh4Data = bytearray()
        self.fadcCh5Data = bytearray()
        self.fadcCh6Data = bytearray()
        self.fadcCh7Data = bytearray()
        self.sadcCh0Data = bytearray()
        self.sadcCh1Data = bytearray()
        self.sadcCh2Data = bytearray()
        self.sadcCh3Data = bytearray()
        self.sadcCh4Data = bytearray()
        self.sadcCh5Data = bytearray()
        self.sadcCh6Data = bytearray()
        self.sadcCh7Data = bytearray()
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
                    if ((p[4] & 0xFF) == 0):
                        self.sadcCh0Data[:] = p
                    elif ((p[4] & 0xFF) == 1):
                        self.sadcCh1Data[:] = p
                    elif ((p[4] & 0xFF) == 2):
                        self.sadcCh2Data[:] = p
                    elif ((p[4] & 0xFF) == 3):
                        self.sadcCh3Data[:] = p
                    elif ((p[4] & 0xFF) == 4):
                        self.sadcCh4Data[:] = p
                    elif ((p[4] & 0xFF) == 5):
                        self.sadcCh5Data[:] = p
                    elif ((p[4] & 0xFF) == 6):
                        self.sadcCh6Data[:] = p
                    elif ((p[4] & 0xFF) == 7):
                        self.sadcCh7Data[:] = p
                # sort fast ADC channnels
                elif ((p[7] & 0x10)>>4 == 0):
                    if (PRINT_VERBOSE): print('Fast ADC channnel: ', (p[4] & 0xFF))
                    if ((p[4] & 0xFF) == 0):
                        self.fadcCh0Data[:] = p
                    elif ((p[4] & 0xFF) == 1):
                        self.fadcCh1Data[:] = p
                    elif ((p[4] & 0xFF) == 2):
                        self.fadcCh2Data[:] = p
                    elif ((p[4] & 0xFF) == 3):
                        self.fadcCh3Data[:] = p
                    elif ((p[4] & 0xFF) == 4):
                        self.fadcCh4Data[:] = p
                    elif ((p[4] & 0xFF) == 5):
                        self.fadcCh5Data[:] = p
                    elif ((p[4] & 0xFF) == 6):
                        self.fadcCh6Data[:] = p
                    elif ((p[4] & 0xFF) == 7):
                        self.fadcCh7Data[:] = p
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

    def update_plot(self):
        # Build a list of 4 random integers between 0 and 10 (both inclusive)
        l = [-1, -2, 10, 14] #[random.randint(0, 10) for i in range(4)]
        #self.axes.cla()
        self.axes.plot([0, 1, 2, 3], l, 'r')
        self.draw()

    #the arguments are expected in the following sequence
    # (display enabled, line name, line color, data array)
    def update_plot(self, *args):
        argIndex = 0
        lineName = ""
#        if (self.fig.cbar!=None):              
#            self.fig.cbar.remove()

        self.axes.cla()
        for arg in args:
            if (argIndex == 0):
                lineEnabled = arg
            if (argIndex == 1):
                lineName = arg
            if (argIndex == 2):
                lineColor = arg
            if (argIndex == 3):
                ##if (PRINT_VERBOSE): print(lineName)
                if (lineEnabled):
                    l = arg #[random.randint(0, 10) for i in range(4)]
                    self.axes.plot(l, lineColor)
                argIndex = -1
            argIndex = argIndex + 1    
        self.axes.set_title(self.MyTitle)        
        self.draw()

    def update_figure(self, image=None, contrast=None, autoScale = True):
        self.axes.cla()
        self.axes.autoscale = autoScale

        if (len(image)>0):
            #self.axes.gray()        
            if (contrast != None):
                self.cax = self.axes.imshow(image, interpolation='nearest', cmap='gray',vmin=contrast[1], vmax=contrast[0])
            else:
                self.cax = self.axes.imshow(image, interpolation='nearest', cmap='gray')

#            if (self.fig.cbar==None):              
#                self.fig.cbar = self.fig.colorbar(self.cax)
#            else:
#                self.fig.cbar.remove()
#                self.fig.cbar = self.fig.colorbar(self.cax)
        self.draw()

        


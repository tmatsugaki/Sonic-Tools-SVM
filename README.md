# Sonic-Tools-SVM
This is an analyzer for <b>sound</b>, <b>vibration</b>, and <b>magnetic fields</b> on iOS. This has following measuring functions.</br>

* Sound (Analyzer [FFT / RTA / Spectrogram], Scope, RMS, Signal Generator)</br>
* Vibration (Analyzer [FFT], Scope, RMS)</br>
* Magnetic field (Scope, RMS)</br>

You can pinch (zoom) and pan (scroll) on measurement screens other than RTA and spectrogram, and pan (band selection) on RTA. You can pause by tapping the measurement screen. Since the measurement time is displayed at the time of pause, it is suitable for leaving as evidence. Please take a screenshot of the screen in the system standard way.
</br>
</br>
## Application example</br>
· Record the present situation as quantitative evidence, such as by using recording and use it for the improvement of obstacles.</br>
· Use it for science education.</br>
· Use it along with the sweep generator to improve the acoustic characteristics of the listening room.</br>

## Note</br>
This application has an audio signal oscillation function, and depending on the operation it may generate sound that is harmful to the human body, so please refrain from using things like headphones or headsets. We are not responsible for damage caused by using that equipment.</br>

The resolution of the spectrum analysis of speech is about 11 Hz inherent, however, the actual resolution is in the maximum of 3 Hz by Lagrange interpolation processing. It is not the accuracy that can be used to tune an instrument. Please use the instrument tuning application for that purpose.</br>

If you can not find the current point by zooming in or scrolling, you can return to the default state that you can see the whole picture by pressing and holding the measurement screen long.</br>

If a remarkable peak near 1 Hz lasts for more than 10 seconds from the beginning of the spectrum analysis results. It will ignore the peak below 1 Hz after 10 seconds. In most cases, this might happen when the accelerometer is dull.</br>

For a good result with Octave RTA, we recommend using Window Function.</br>

Allows you to output the data of Sound Spectrum, Sound Spectrogram, and every RMS'.</br>

You can use the data files by Files.app on iOS or iTunes File Sharing on Mac.</br>
Please note that the output file of Spectrogram is not small not like other data files.</br>

## for Progammers
Despite this FFT analizer part is somewhat famous for detecting precise frequency stably in Japan, I didn't do almost anything special except for Lagrange interpolation. Please try to add Lagrange interpolation into your FFT code.

## Copyright
    Sonic Tools SVM (FFT Analyzer/RTA for iOS)
    Copyright (C) 2017-2021  Takuji Matsugaki

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

## MoMu
  MoMu: A Mobile Music Toolkit</br>
  Copyright (c) 2010 Nicholas J. Bryan, Jorge Herrera, Jieun Oh, and Ge Wang</br>
  All rights reserved.</br>
    http://momu.stanford.edu/toolkit/</br>
 </br>
  Mobile Music Research @ CCRMA</br>
  Music, Computing, Design Group</br>
  Stanford University</br>
    http://momu.stanford.edu/</br>
    http://ccrma.stanford.edu/groups/mcd/</br>
 </br>
 MoMu is distributed under the following BSD style open source license:</br>
 </br>
 Permission is hereby granted, free of charge, to any person obtaining a </br>
 copy of this software and associated documentation files (the</br>
 "Software"), to deal in the Software without restriction, including</br>
 without limitation the rights to use, copy, modify, merge, publish,</br>
 distribute, sublicense, and/or sell copies of the Software, and to</br>
 permit persons to whom the Software is furnished to do so, subject to</br>
 the following conditions:</br>
 </br>
 The authors encourage users of MoMu to include this copyright notice,</br>
 and to let us know that you are using MoMu. Any person wishing to </br>
 distribute modifications to the Software is encouraged to send the </br>
 modifications to the original authors so that they can be incorporated </br>
 into the canonical version.</br>
 </br>
 The Software is provided "as is", WITHOUT ANY WARRANTY, express or implied,</br>
 including but not limited to the warranties of MERCHANTABILITY, FITNESS</br>
 FOR A PARTICULAR PURPOSE and NONINFRINGEMENT.  In no event shall the authors</br>
 or copyright holders by liable for any claim, damages, or other liability,</br>
 whether in an actino of a contract, tort or otherwise, arising from, out of</br>
 or in connection with the Software or the use or other dealings in the </br>
 software.</br>
 
 ## コメント</br>
 コメントはほとんど入れていませんし、あってもほとんど日本語なので外国人の方は頑張ってください。

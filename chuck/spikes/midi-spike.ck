InitMidiFacade.instance @=> MidiFacade midi;
MidiDevices midiDevices;
NativeMidiOut2.create(findMidiOut(midiDevices.STEP12)) @=> NativeMidiOut2 midiOut;

class MyMidiOut2 {
    fun void send(MidiMsg msg) {
        //this.send(msg);
    }

    fun void send(int data1, int data2, float data3) {
        MidiMsg msgOut;
        data1 => msgOut.data1;
        data2 => msgOut.data2;
        data3 $ int => msgOut.data3;
        this.send(msgOut);
    }
}

class NativeMidiOut2 extends MyMidiOut2 {
    MidiOut midiOut;
    
    fun void send(MidiMsg msg) {
        <<< "Native: ", msg.data1, msg.data2, msg.data3 >>>;
        midiOut.send(msg);
    }

    fun static NativeMidiOut2 create(MidiOut midiOut) {
        if (midiOut == null) {
            return null;
        }
        NativeMidiOut2 nativeMidiOut;
        midiOut @=> nativeMidiOut.midiOut; 
        return nativeMidiOut;
    }

}

fun MidiOut findMidiOut(string namePart) {
    for (int i; i < midi.moutCount; i++) {
        if (midi.mout[i].name().find(namePart) > -1) {
            return midi.mout[i];
        }
    }
}




// midiOut.send(128, 72, 0);
// midiOut.send(144, 72, 60);
// midiOut.send(176, 22, 0);
// midiOut.send(176, 20, 0);
midiOut.send(176, 50, 'A');
midiOut.send(176, 51, 'M');
midiOut.send(176, 52, 'A');
midiOut.send(176, 53, 'Z');
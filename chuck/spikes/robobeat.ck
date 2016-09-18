InitMidiFacade.instance @=> MidiFacade midi;
MidiDevices midiDevices;

midiDevices.SAMPLE_PAD => string OUTPUT_MIDI_NAME;
midiDevices.SAMPLE_PAD => string SAMPLE_PAD;
midiDevices.VMPK => string VMPK;

fun void sendMidi(MyMidiOut midiOut, int data1, int data2, float data3) {
    MidiMsg msgOut;
    data1 => msgOut.data1;
    data2 => msgOut.data2;
    data3 $ int => msgOut.data3;
    midiOut.send(msgOut);
}

class Effect {
    "dummy" => string monoGroup;
    fun void trigger(MyMidiOut midiOut, float velocity) {
    }
    fun void reTrigger(float velocity) {
    }
    fun void setControl(int control, int value) {

    } 
}


class MyMidiOut {
    fun void send(MidiMsg msg) {
        //this.send(msg);
    }
}


class FakeMidiOut extends MyMidiOut {
    Mandolin s => dac;
    
    fun void send(MidiMsg msg) {
        msg.data2 => Std.mtof => s.freq;
        msg.data3/127.0 => s.noteOn;
    }
}

class NoteSequencer extends Effect {
    int sequence[];
    dur timePerNote;
    "note" => monoGroup;
    time triggerTime;
    MyMidiOut @ midiOut;
    [0,2,4,5,7,9,11] @=> int scale[];
    int baseNote; 
    
    fun void trigger(MyMidiOut midiOut, float velocity) {
        <<< "Triggered " >>>;
        midiOut @=> this.midiOut;
        reTrigger(velocity);
        for(int i;i<sequence.cap();i++) {
            // if (now - triggerTime > 1::second) {
            //     break;
            // }
            sequence[i] => int note;
            <<< "Note: ", triggerTime, now, note >>>;
            if (note>=0) {
                note + baseNote => note;
                sendMidi(midiOut, 0x90, note, velocity); // note on
                // 20::ms => now;            
                sendMidi(midiOut, 0x80, note, 0x40);    // note off
            } else {
                20::ms => now;
            }
            timePerNote => now;
            me.yield(); // Allow parent to exit my shred.
        }
    }

    fun void reTrigger(float velocity) {
        now => triggerTime;
    }

    fun void setControl(int control, int value) {
        if (this.midiOut != null) {
            scale[scale.size() * value/200 ] => baseNote;
        }
    } 

    fun static NoteSequencer create(int sequence[], dur timePerNote) {
        NoteSequencer eff;
        sequence @=> eff.sequence;
        timePerNote => eff.timePerNote;
        return eff;
    }
}

FakeMidiOut midiOut;

// Abstract class
class Patch {
    string name;
    string inputMidiName;
    int instrumentNumber;
    Effect effectByNote[20];

    fun void run() {
        // findMidiOut(OUTPUT_MIDI_NAME) @=> MidiOut midiOut;
        Shred effectShredByMonoGroup[1];

        while (true) {
            midi.event => now;
            midi.event.msg @=> MidiMsg msg;
            msg.data1 => int data1;
            msg.data2 => int data2;
            msg.data3 => int data3;

            if ((midi.event.midiIn.name().find(inputMidiName) > -1) && (data1 == 144 || data1 == 153)) {
                Std.ftoa(data2, 0) => string note;
                effectByNote[note] @=> Effect effect;
                <<< "noteOn: ", midi.event.midiIn.name(), note, data3 >>>;
                if (effect != null) {
                    <<< "eff: ", effect.monoGroup>>>;
                    effectShredByMonoGroup[effect.monoGroup] @=> Shred existingShred;  
                    if (existingShred != null && !existingShred.done()) {
                     <<< "Exit Shred", existingShred>>>;
                     existingShred.exit();
                        // effect.reTrigger(data3);
                    } else {
                        <<< "Spork!" >>>;
                        spork ~ effect.trigger(midiOut, data3) @=>  effectShredByMonoGroup[effect.monoGroup];;
                    }
                }
            }

            if (data1 == 176) {
                for(int i; i < effectByNote.cap(); i++) {
                    effectByNote[i].setControl(data2, data3);
                }
            }
        }
    }
}


class Beat extends Patch {
    "Beat" => name;
    midiDevices.VMPK => inputMidiName;
    // midiDevices.MICRO_KEY => inputMidiName;
    42 => instrumentNumber;
    //NoteSequencer.create(_.repeated([-1, -1, 48, -1,-1, -1, 48, -1,-1, -1, 48, -1, -1, -1, 48, 48], 1000), 0.2::second) @=> NoteSequencer noteSeq;
    NoteSequencer.create([48], 0::second) @=> NoteSequencer noteSeq1;
    NoteSequencer.create([60], 0::second) @=> NoteSequencer noteSeq2;
    noteSeq1 @=> effectByNote["41"];
    noteSeq1 @=> effectByNote[0];
    noteSeq2 @=> effectByNote["40"];
    noteSeq2 @=> effectByNote[1];
}


fun MidiOut findMidiOut(string namePart) {
    for (int i; i < midi.moutCount; i++) {
        if (midi.mout[i].name().find(namePart) > -1) {
            return midi.mout[i];
        }
    }
}


Beat patch;

<<< "robobeat started" >>>;

patch.run(); 


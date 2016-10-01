InitMidiFacade.instance @=> MidiFacade midi;
MidiDevices midiDevices;

midiDevices.USB_MIDI_ADAPTER => string OUTPUT_MIDI_NAME;
midiDevices.SAMPLE_PAD => string SAMPLE_PAD;

class MyMidiOut {
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

class FakeMidiOut extends MyMidiOut {
    Mandolin s => dac;
    
    fun void send(MidiMsg msg) {
         if (msg.data1 == 144) {
            msg.data2 => Std.mtof => s.freq;
            msg.data3/127.0 => s.noteOn;
        } else if (msg.data1 == 128) {
            msg.data3/127.0 => s.noteOff;
        }
    }
}

FakeMidiOut mandolinMidiOut;


class MoogMidiOut extends MyMidiOut {
    Moog s => dac;
    
    fun void send(MidiMsg msg) {
        if (msg.data1 == 144) {
            msg.data2 => Std.mtof => s.freq;
            msg.data3/127.0 => s.noteOn;
        } else if (msg.data1 == 128) {
            msg.data3/127.0 => s.noteOff;
        }
    }
}

MoogMidiOut moogMidiOut;

class Sampler extends MyMidiOut {
    string filenames[128];
    SndBuf samples[128];

    me.dir() + "../media/samples/drums/kick.wav" @=> filenames[36];
    me.dir() + "../media/samples/drums/kick.wav" @=> filenames[35];
    me.dir() + "../media/samples/drums/snare.wav" @=> filenames[38];
    me.dir() + "../media/samples/drums/hihat.wav" @=> filenames[37];


    for(int i; i<filenames.size(); i++) {
        filenames[i] @=> string filename;
        if (filename.length()>0) {
            SndBuf buf => dac;
            filename => buf.read;
            buf @=> samples[i];
            0.0 => buf.gain;
        }
    }

    fun void send(MidiMsg msg) {
        if (msg.data1 != 144) {
            return;
        }
        samples[msg.data2] @=> SndBuf buf;
        // <<< "Play drum", now, msg.data2, filenames[msg.data2], buf.length() >>>;
        0 => buf.pos;
        1.0 => buf.gain;
        1.0 => buf.rate;
    }

}

Sampler sampler;
//sampler.send(144, 38, 100);

class NativeMidiOut extends MyMidiOut {
    MidiOut midiOut;
    
    fun void send(MidiMsg msg) {
        <<< "Native: ", msg.data1, msg.data2, msg.data3 >>>;
        midiOut.send(msg);
    }

    fun static NativeMidiOut create(MidiOut midiOut) {
        if (midiOut == null) {
            return null;
        }
        NativeMidiOut nativeMidiOut;
        midiOut @=> nativeMidiOut.midiOut; 
        return nativeMidiOut;
    }

}



class Effect {
    "dummy" => string monoGroup;
    Shred shred;

    fun void start(MyMidiOut midiOut, float velocity) {
        spork ~ trigger(midiOut, velocity) @=> shred;
    }
    
    fun void trigger(MyMidiOut midiOut, float velocity) {
    
    }
    
    fun void stop() {
        <<< "Stopping Effect">>>;
        shred.exit();
    }
}

class SweepDown extends Effect {
    int controlIndex;
    float minValue;
    
    fun void trigger(MyMidiOut midiOut,float velocity) {
        velocity => float value;
        while (value >= this.minValue) {
            midiOut.send(0xB0, controlIndex, value);
            <<< "SweepValue: ",controlIndex, value >>>;
            value - 1.0 - (velocity/50.0) => value;
            20::ms => now;
            me.yield(); // Allow parent to exit my shred.
        }
        midiOut.send(0xB0, controlIndex, minValue);
    }

    fun static SweepDown create(int controlIndex,float minValue) {
        SweepDown eff;
        minValue => eff.minValue;
        controlIndex => eff.controlIndex;
        Std.itoa(controlIndex) => eff.monoGroup;
        return eff;
    }
}

class ControlSequencer extends Effect {
    int sequence[];
    int lastValue;
    dur timePerNote;
    int controlIndex;
    "note" => monoGroup;
    
    fun void trigger(MyMidiOut midiOut, float velocity) {
        for(int i;i<sequence.cap();i++) {
            sequence[i] => int value;
            <<< "ControlSequencerValue: ", value >>>;
            midiOut.send(0xB0, controlIndex, value); // note on
            timePerNote => now;
            me.yield(); // Allow parent to exit my shred.
        }
        midiOut.send(0xB0, controlIndex, lastValue);
    }

    fun static ControlSequencer create(int sequence[], dur timePerNote, int controlIndex, int lastValue) {
        ControlSequencer eff;
        sequence @=> eff.sequence;
        lastValue @=> eff.lastValue;
        timePerNote => eff.timePerNote;
        controlIndex => eff.controlIndex;
        Std.itoa(controlIndex) => eff.monoGroup;
        return eff;
    }
}

class NoteSequencer extends Effect {
    int sequence[];
    dur timePerNote;
    "note" => monoGroup;
    
    fun void trigger(MyMidiOut midiOut, float velocity) {
        for(int i;i<sequence.cap();i++) {
            sequence[i] => int note;
            <<< "Note: ", note >>>;
            midiOut.send(0x90, note, 0x7f); // note on
            20::ms => now;            
            midiOut.send(0x80, note, 0x40);    // note off
            timePerNote => now;
            me.yield(); // Allow parent to exit my shred.
        }
    }

    fun static NoteSequencer create(int sequence[], dur timePerNote) {
        NoteSequencer eff;
        sequence @=> eff.sequence;
        timePerNote => eff.timePerNote;
        return eff;
    }

    fun static NoteSequencer create() {
        NoteSequencer eff;
        return eff;
    }
}

class MidiSequencer extends Effect {
    "note" => monoGroup;
    string filename;
    int loop;
    MyMidiOut myMidiOut;
    dur offset;
    float bpm;
    
    fun void trigger(MyMidiOut _midiOut, float velocity) {
        <<< "triggermidi">>>;
        if (myMidiOut == null) {
            _midiOut @=> myMidiOut;
        }
        MidiFileIn midiFileIn;
        MidiMsg msg;
        midiFileIn.open(filename);
        offset => now;
        do {
            while(midiFileIn.read(msg, 0))
            {
                if(msg.when > 0::second) {
                    // <<< "Wait MidiNote: ", msg.when >>>;
                    msg.when*120.0/bpm => now;
                    me.yield(); // Allow stop to exit my shred.
                }

                (msg.data1 & 0xF0) => int midiCommand;

                if((midiCommand == 144 || midiCommand == 128) && msg.data2 > 0) {
                    // <<< "Play MidiNote: ", msg.data2, msg.data3 >>>;
                    myMidiOut.send(msg.data1, msg.data2, msg.data3);
                }
            }
            midiFileIn.rewind();
        } while (loop);
        
        stopAllNotes();
        midiFileIn.close();
    }

    fun void stop() {
        <<< " Stopping MidiSequencer ">>>;
        stopAllNotes();
        shred.exit();
    }

    fun void stopAllNotes() {
        for (int i; i < 128; i++) {
            for (int i2;  i2 < 4; i2++) {
                myMidiOut.send(128, i, 0);
            }
        }
    }

    fun static MidiSequencer create(string filename, MyMidiOut midiOut, int loop, dur offset, float bpm) {
        MidiSequencer eff;
        filename => eff.filename;
        loop => eff.loop;
        midiOut @=> eff.myMidiOut;
        offset => eff.offset; 
        bpm => eff.bpm;
        return eff;
    }
}

class MultipleEffects extends Effect {
    "note" => monoGroup;
    Effect effects[];

    fun void trigger(MyMidiOut midiOut, float velocity) {
        <<<  "Trigger MultipleEffects:", effects.size() >>>;
        for (int i; i < effects.size(); i++) {
            effects[i].start(midiOut, velocity);
        }
        while (true) {
            0.1::second => now; 
        }
    }

    fun void stop() {
        <<< " Stopping children ">>>;
        for (int i; i < effects.size(); i++) {
            effects[i].stop();
        }
        shred.exit();
    }


    fun static MultipleEffects create(Effect effects[]) {
        MultipleEffects eff;
        effects @=> eff.effects;
        return eff;
    }


}


// Abstract class
class Patch {
    string name;
    string inputMidiName;
    midiDevices.STEP12 => string inputControlName;
    74 => int controlIndex;
    int instrumentNumber;
    Effect effectByNote[1];
    FakeMidiOut mandolin @=> MyMidiOut myMidiOut;

    fun void run() {
        MyMidiOut midiOut;
        if (myMidiOut == null) {
            NativeMidiOut.create(findMidiOut(OUTPUT_MIDI_NAME)) @=> midiOut;
            if (midiOut == null) {
                mandolinMidiOut @=> midiOut;
            }
        } else {
            myMidiOut @=> midiOut;
        }

        Effect @ effectByMonoGroup[1];

        while (true) {
            midi.event => now;
            midi.event.msg @=> MidiMsg msg;
            msg.data1 => int data1;
            msg.data2 => int data2;
            msg.data3 => int data3;

            if ((midi.event.midiIn.name().find(inputMidiName) > -1) && (data1 == 144 || data1 == 153)) {
                Std.ftoa(data2, 0) => string note;
                effectByNote[note] @=> Effect effect;
                <<< "noteOn: ", midi.event.midiIn.name(), note, effect, data3 >>>;
                if (effect != null) {
                    effectByMonoGroup[effect.monoGroup] @=> Effect playingEffect;  
                    if (playingEffect != null) {
                        <<< "Stop Effect", playingEffect >>>;
                        playingEffect.stop();
                    }
                    effect @=> effectByMonoGroup[effect.monoGroup];;
                    effect.start(midiOut, data3);
                }
            }

            if (midi.event.midiIn.name().find(inputControlName) > -1 && data1 == 176) {
                <<< "inputControl: ", midi.event.midiIn.name(), data1, data2, data3, controlIndex, midiOut >>>;
                midiOut.send(data1, controlIndex, data3);
            }
        }
    }
}

class Polly extends Patch {
    "Polly" => name;
    midiDevices.SAMPLE_PAD => inputMidiName;
    10 => instrumentNumber;
    SweepDown.create(MicroKorg.CUTOFF, 30) @=> effectByNote["51"];
    SweepDown.create(MicroKorg.CUTOFF, 30) @=> effectByNote["45"];

    _.repeated([78, 96, 114, 126], 2) @=> int SEMITONES[];
    ControlSequencer.create(SEMITONES, 30::ms, MicroKorg.OSC2_SEMITONE, 64) @=> effectByNote["49"];
    ControlSequencer.create(SEMITONES, 30::ms, MicroKorg.OSC2_SEMITONE, 64) @=> effectByNote["48"];
}

class Musikant extends Patch {
    "Musikant" => name;
    midiDevices.SAMPLE_PAD => inputMidiName;
    97 => instrumentNumber;
    SweepDown.create(MicroKorg.NOISE_LEVEL, 30) @=> effectByNote["51"];
    SweepDown.create(MicroKorg.NOISE_LEVEL, 30) @=> effectByNote["45"];

    _.repeated([78, 96, 114, 126], 2) @=> int SEMITONES[];
    ControlSequencer.create(SEMITONES, 30::ms, MicroKorg.OSC2_SEMITONE, 64) @=> effectByNote["49"];
    ControlSequencer.create(SEMITONES, 30::ms, MicroKorg.OSC2_SEMITONE, 64) @=> effectByNote["48"];
}

class Feinde extends Patch {
    "Feinde" => name;
    // midiDevices.USB_MIDI_ADAPTER => inputMidiName;
    midiDevices.VMPK => inputMidiName;
    123 => instrumentNumber;
    MidiSequencer.create(me.sourceDir() + "../media/feinde/drums-ref.mid", sampler, true, 0::ms, 130.0) @=> effectByNote["45"];
    NoteSequencer.create([45], 1::second) @=> effectByNote["57"];
}

class Messenger extends Patch {
    "Messenger" => name;
    // midiDevices.USB_MIDI_ADAPTER => inputMidiName;
    midiDevices.STEP12 => inputMidiName;
    96 => instrumentNumber;
    1 => controlIndex;
    MidiSequencer.create(me.sourceDir() + "../media/messenger/drums2.mid", sampler, true, 0::ms, 130) @=> effectByNote["50"];
    NoteSequencer.create() @=> effectByNote["52"];
    null => myMidiOut;
    
}

class Amazon extends Patch {
    "Amazon" => name;
    // midiDevices.MICRO_KEY => inputMidiName;
    midiDevices.USB_MIDI_ADAPTER => inputMidiName;
    // midiDevices.VMPK => inputMidiName;
    42 => instrumentNumber;

    _.repeated(_.concat([
        _.repeated([45, 57], 4),
        _.repeated([48, 60], 4),
        _.repeated([43, 55], 4),
        _.repeated([38, 50], 4)
    ]), 6) @=> int AMAZON_SEQ[];

    _.repeated([45, 47, 53, 57, 60, 67, 60, 57, 53, 47], 50) @=> int AMAZON_SEQ_RAND[];

    (60.0 / 150.0 * 1000.0 / 2.0)::ms => dur timePerNote;

    NoteSequencer.create(AMAZON_SEQ, timePerNote) @=> Effect seqEff;

    MidiSequencer.create(me.sourceDir() + "../media/amazon/drums.mid", sampler, true, 0::ms, 140) @=> Effect drums;
    MidiSequencer.create(me.sourceDir() + "../media/amazon/bass-short.mid", null, true, 20::ms, 140) @=> Effect bass;
    // MidiSequencer.create(me.sourceDir() + "../media/amazon/bass.mid", moogMidiOut, true) @=> Effect bass;
    MultipleEffects.create([bass, drums]) @=> Effect ref;

    ref @=> effectByNote["45"];
    drums @=> effectByNote["46"];
    NoteSequencer.create() @=> effectByNote["52"];
    NoteSequencer.create(AMAZON_SEQ_RAND, timePerNote) @=> effectByNote["36"];
    null => myMidiOut;
}


fun MidiOut findMidiOut(string namePart) {
    for (int i; i < midi.moutCount; i++) {
        if (midi.mout[i].name().find(namePart) > -1) {
            return midi.mout[i];
        }
    }
}


Polly  polly;
Feinde feinde;
Amazon amazon;
Musikant musikant;
Messenger messenger;
[polly, amazon, feinde, messenger] @=> Patch patches[];
messenger @=> Patch patch;

<<< "main started" >>>;

spork ~ patch.run() @=> Shred patchShred; 

// NativeMidiOut.create(findMidiOut(OUTPUT_MIDI_NAME)) @=> MyMidiOut midiOut;
// midiOut.send(176, 1, 10);

while (true) {
    midi.event => now;
    midi.event.msg @=> MidiMsg msg;
    msg.data1 => int data1;
    msg.data2 => int data2;
    msg.data3 => int data3;
    <<< "Midi Event:", midi.event.midiIn.name().find(SAMPLE_PAD), data1, data2, data3 >>>;
    if (midi.event.midiIn.name().find(OUTPUT_MIDI_NAME) >-1 && data1 == 192) {
        <<< "Changed instrument: ", data2 >>>;
        if (patchShred != null) {
            patchShred.exit();
            null @=> patchShred;
        }
        for(int patchId; patchId < patches.size(); patchId++) {
            if (patches[patchId].instrumentNumber == data2) {
                patches[patchId] @=> patch;
                spork ~ patch.run() @=> patchShred;
                <<< "Changed patch: ", patch.name>>>;
            }
        }
    }
}


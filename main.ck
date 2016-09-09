2::second => now;

MidiFacade midi;
MidiDevices midiDevices;

midiDevices.USB_MIDI_ADAPTER => string OUTPUT_MIDI_NAME;
midiDevices.SAMPLE_PAD => string SAMPLE_PAD;

fun void sendMidi(MidiOut midiOut, int data1, int data2, float data3) {
    MidiMsg msgOut;
    data1 => msgOut.data1;
    data2 => msgOut.data2;
    data3 $ int => msgOut.data3;
    midiOut.send(msgOut);
}

class Effect {
    "dummy" => string monoGroup;
    fun void trigger(MidiOut midiOut, float velocity) {
    }
}

class SweepDown extends Effect {
    int controlIndex;
    float minValue;
    
    fun void trigger(MidiOut midiOut,float velocity) {
        velocity => float value;
        while (value >= this.minValue) {
            sendMidi(midiOut, 0xB0, controlIndex, value);
            <<< "Value: ", value >>>;
            value - 2 => value;
            20::ms => now;
            me.yield(); // Allow parent to exit my shred.
        }
    }

    fun static SweepDown create(int controlIndex,float minValue) {
        SweepDown eff;
        minValue => eff.minValue;
        controlIndex => eff.controlIndex;
        Std.itoa(controlIndex) => eff.monoGroup;
        return eff;
    }
}

class NoteSequencer extends Effect {
    int sequence[];
    dur timePerNote;
    "note" => monoGroup;
    
    fun void trigger(MidiOut midiOut, float velocity) {
        for(int i;i<sequence.cap();i++) {
            //sendMidi(midiOut, 0xB0, controlIndex, value);
            sequence[i] => int value;
            <<< "Value: ", value >>>;
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
}

class Patch {
    string name;
    string inputMidiName;
    int instrumentNumber;
    Effect effectByNote[1];
    // Effect e1 @=> effectByNote["60"];
}

class Polly extends Patch {
    "Polly" => name;
    midiDevices.SAMPLE_PAD => inputMidiName;
    10 => instrumentNumber;
    SweepDown.create(MicroKorg.CUTOFF, 30) @=> effectByNote["51"];
}


fun MidiOut findMidiOut(string namePart) {
    for (int i; i < midi.moutCount; i++) {
        if (midi.mout[i].name().find(namePart) > -1) {
            return midi.mout[i];
        }
    }
}


Polly polly @=> Patch patch;
Shred effectShredByMonoGroup[1];
findMidiOut(OUTPUT_MIDI_NAME) @=> MidiOut midiOut;

while (true) {
    midi.event => now;
    midi.event.msg @=> MidiMsg msg;
    msg.data1 => int data1;
    msg.data2 => int data2;
    msg.data3 => int data3;
    <<< "hui", midi.event.midiIn.name().find(SAMPLE_PAD), data1, data2, data3 >>>;
    if ((midi.event.midiIn.name().find(SAMPLE_PAD) > -1) && (data1 == 144 || data1 == 153)) {
        Std.ftoa(data2, 0) => string note;
        patch.effectByNote[note] @=> Effect effect;
        <<< "MidiEvent!", midi.event.midiIn.name(), note, effect, data3 >>>;
        if (effect != null) {
            effectShredByMonoGroup[effect.monoGroup] @=> Shred existingShred;  
            if (existingShred != null) {
                // <<< "Exit Shred", existingShred>>>;
                existingShred.exit();
            }
            spork ~ effect.trigger(midiOut, data3) @=>  effectShredByMonoGroup[effect.monoGroup];;
        }
    }
}


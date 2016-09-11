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

class ControlSequencer extends Effect {
    int sequence[];
    dur timePerNote;
    int controlIndex;
    "note" => monoGroup;
    
    fun void trigger(MidiOut midiOut, float velocity) {
        for(int i;i<sequence.cap();i++) {
            sequence[i] => int value;
            <<< "Value: ", value >>>;
            sendMidi(midiOut, 0xB0, controlIndex, value); // note on
            timePerNote => now;
            me.yield(); // Allow parent to exit my shred.
        }
    }

    fun static ControlSequencer create(int sequence[], dur timePerNote, int controlIndex) {
        ControlSequencer eff;
        sequence @=> eff.sequence;
        timePerNote => eff.timePerNote;
        controlIndex => eff.controlIndex;
        return eff;
    }
}

class NoteSequencer extends Effect {
    int sequence[];
    dur timePerNote;
    "note" => monoGroup;
    
    fun void trigger(MidiOut midiOut, float velocity) {
        for(int i;i<sequence.cap();i++) {
            sequence[i] => int note;
            <<< "Note: ", note >>>;
            sendMidi(midiOut, 0x90, note, 0x7f); // note on
            20::ms => now;            
            sendMidi(midiOut, 0x80, note, 0x40);    // note off
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


fun int[] repeated(int in[], int repetions) {
    in.size()*repetions => int outSize;
    int out[ outSize];
    for(int i; i< outSize; i++) {
        in[i%in.size()] => out[i];
    }
    return out;
}

fun int[] concat(int in[][]) {
    int out[0];
    int iOut;
    for(int j; j< in.size(); j++) {
        out.size(out.size()+in[j].size());
        for(int i; i<in[j].size(); i++) {
            in[j][i] => out[iOut++];
        }
    }
    return out;
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
    SweepDown.create(MicroKorg.CUTOFF, 30) @=> effectByNote["45"];

    repeated([78, 96, 114, 126], 2) @=> int SEMITONES[];
    ControlSequencer.create(SEMITONES, 30::ms, MicroKorg.OSC2_SEMITONE) @=> effectByNote["49"];
    ControlSequencer.create(SEMITONES, 30::ms, MicroKorg.OSC2_SEMITONE) @=> effectByNote["48"];
}

class Amazon extends Patch {
    "Amazon" => name;
    midiDevices.USB_MIDI_ADAPTER => inputMidiName;
    42 => instrumentNumber;

    repeated(concat([
        repeated([45, 57], 4),
        repeated([48, 60], 4),
        repeated([43, 55], 4),
        repeated([38, 50], 4)
    ]), 6) @=> int AMAZON_SEQ[];

    repeated([45, 47, 53, 57, 60, 67, 60, 57, 53, 47], 50) @=> int AMAZON_SEQ_RAND[];

    (60.0 / 140.0 * 1000.0 / 2.0)::ms => dur timePerNote;

    NoteSequencer.create(AMAZON_SEQ, timePerNote) @=> effectByNote["45"];
    NoteSequencer.create([45], 1::second) @=> effectByNote["57"];
    NoteSequencer.create(AMAZON_SEQ_RAND, timePerNote) @=> effectByNote["51"];
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


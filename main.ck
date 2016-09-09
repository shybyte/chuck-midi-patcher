1::second => now;
MidiFacade midi;

while (true) {
    midi.event => now;
    <<< "MidiEvent!", midi.event.midiIn.name()>>>;
}


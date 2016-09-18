
class MidiEvent extends Event {
    MidiIn midiIn;
    MidiMsg msg;       
}

public class MidiFacade {
    MidiIn min[16];
    MidiOut mout[16];
    0 => int moutCount;
    MidiEvent event;

    fun void go( MidiIn min, int id )
    {
        MidiMsg msg;
        while( true )
        {
            min => now;
            while( min.recv( msg ) )
            {
                if (msg.data1 == 248 || (msg.data1 == 153 && msg.data3 == 0)) {
                    continue;
                }
                <<< "device", id, min.name(), ":", msg.data1, msg.data2, msg.data3 >>>;
                min @=> event.midiIn;
                msg.data1 => event.msg.data1;
                msg.data2 => event.msg.data2;
                msg.data3 => event.msg.data3;
                event.broadcast();
            }
        }
    }


    for( int i; i < min.cap(); i++ )
    {
        // no print err
        min[i].printerr( 0 );

        // open the device
        if( min[i].open( i ) )
        {
            min[i].name() => string name;
            <<< "midi in", i, "->", name, "->", "open: SUCCESS" >>>;
            if (name.find("RtMidi") == -1) {
                spork ~ go( min[i], i );
            }
        } else {
            break;
        }
    }


    for( int i; i < mout.cap(); i++ )
    {
        MidiOut midiOut;
        // no print err
        midiOut.printerr( 0 );

        // open the device
        if( midiOut.open( i ) )
        {
            <<< "midi out", i, "->", midiOut.name(), "->", "open: SUCCESS" >>>;
            midiOut @=> mout[moutCount++];
        } else {
            break;
        }
    }
}


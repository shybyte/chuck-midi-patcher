
class MidiEvent extends Event {
    MidiIn midiIn;
    MidiMsg msg;       
}

public class MidiFacade {
    MidiIn min[16];
    int devices;
    MidiEvent event;

    fun void go( MidiIn min, int id )
    {
        MidiMsg msg;
        while( true )
        {
            min => now;
            while( min.recv( msg ) )
            {
                <<< "device", id, ":", msg.data1, msg.data2, msg.data3 >>>;
                min @=> event.midiIn;
                msg @=> event.msg;
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
            <<< "device", i, "->", min[i].name(), "->", "open: SUCCESS" >>>;
            spork ~ go( min[i], i );
            devices++;
        }
        else break;
    }
}




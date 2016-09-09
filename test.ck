// declare regular array (capacity doesn't matter so much)
float foo[1];

// use as int-based array
2.5 => foo[0];

// use as associative array
4.0 => foo["yoyo"];

// access as associative (print)
<<< foo["yoyo"] >>>;

// access empty element
<<< foo["gaga"] >>>;  // -> should print 0.0


class Effect {
    fun void trigger() {
        <<< "Effect Start" >>>;
        1::second => now;
        <<< "Effect End" >>>;
    }
}

class Effect2 extends Effect{
    fun void trigger() {
        <<< "Effect 2 Start" >>>;
        1::second => now;
        <<< "Effect 2 End" >>>;
    }
}

Effect effectByNote[1];
Effect e1 @=> effectByNote["60"];
Effect2 e2 @=> effectByNote["62"];

effectByNote["62"].trigger();
public class InitMidiFacade {
    static MidiFacade @ instance;
}

2::second => now;
MidiFacade midi  @=> InitMidiFacade.instance;

while( true ) {
    1::second => now;
} 
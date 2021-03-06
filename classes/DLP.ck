public class DLP{ //data lowpass filter
    Step stp => LPF lp;
    10 => lp.freq;
    1 => lp.Q;
    0.0 => float data;
    0.0 => float val;
    samp => dur rate; //how much computation
    Shred updater;
    
    private void update(){
        while(rate => now){
            data => stp.next;
            lp.last() => val;
        }
    }
    
    fun void go(){
    	lp=>blackhole;
        spork~update() @=> updater;
    }
    
    fun void stop(){
    	lp=<blackhole;
        updater.exit();
    }
    
    fun float freq(){ return lp.freq(); }
    fun float freq(float f){
        f => lp.freq;
        return lp.freq();
    } 
}   
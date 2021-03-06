public class MidiLooper{
    
    MidiMsg msgs[0];
    MidiMsg dbMsg;
    int waitingForDownbeat;
    OscRecv orec;
    orec.event("/c,f")@=>OscEvent clockEvent;
    8=>int clockDiv;
    time delta;
    dur stopDur;
    int recording;
    int recordArmed;
    int muted;
    Shred playShred,stopShred, blinkRecShred, recordShred;
    MidiEvent curMsg;
    MidiOut mout;
    int ctrlCCs[3];
    Event downbeat;
    int clearFlag;
    6=>int recOnColor;
    7=>int recOffColor;
    37=>int clearOnColor;
    36=>int clearOffColor;
    4=>int muteColor;
    3=>int notMuteColor;
    0.375::second=>dur blinkDur;
    1=>int focus;
    dur dbDur;
    time dbPre;
    
    
    fun void init(){
    	0=>dbMsg.data1;
        orec.port(98765);
        orec.listen();
        spork~downbeatLoop();
    }

/*
    fun void colorSelect(MidiBroadcaster mB){
    	while(mB.mev=>now){
    		mB.mev.msg @=> MidiMsg msg;
    		if(msg.data1==0xB0){
    			if(msg.data2==79){
    				if(msg.data3<64)msg.data3+=>clearOffColor;
    				else msg.data3
    				*/
    
    fun void initControlButtons(MidiBroadcaster mB, MidiOut mout, int cc1, int cc2, int cc3){
        initRecButton(mB, mout, cc1);
        initClrButton(mB, mout, cc2);
        initMuteButton(mB, mout, cc3);
    }
    
    fun void initRecButton(MidiBroadcaster mB, MidiOut mout, int cc){
        spork~recButton(mB, mout, cc);
        cc=>ctrlCCs[0];
        MidiMsg msg;
        0x90=>msg.data1;
        cc=>msg.data2;
        recOffColor=>msg.data3;
        mout.send(msg);
    }    
    
    fun void initClrButton(MidiBroadcaster mB, MidiOut mout, int cc){
        spork~clrButton(mB, mout, cc);
        cc=>ctrlCCs[1];
        MidiMsg msg;
        0x90=>msg.data1;
        cc=>msg.data2;
        clearOffColor=>msg.data3;
        mout.send(msg);
    }
    
    fun void initMuteButton(MidiBroadcaster mB, MidiOut mout, int cc){
        spork~muteButton(mB, mout, cc);
        cc=>ctrlCCs[2];
        MidiMsg msg;
        0x90=>msg.data1;
        cc=>msg.data2;
        notMuteColor=>msg.data3;
        mout.send(msg);
    }
    
    fun void recButton(MidiBroadcaster mB, MidiOut mout, int cc){
        MidiMsg msg;
        while(mB.mev=>now){
        	if(focus){
            	mB.mev.msg @=> msg;
            	if(msg.data1 == 0x90 ){
                	if(msg.data2 == cc){
                    	if(recording){
                        	stop();
                        	blinkRecShred.exit();
                    	}
                    	else{ 
                        	record();
                        	blinkRecShred.exit();
                        	spork ~ blinkRec(mout,cc) @=> blinkRecShred;
                    	}
                	}
                }
            }
        }
    }

    fun void send(MidiOut mout,int d1,int d2,int d3){
    	MidiMsg msg;
    	d1=>msg.data1;
    	d2=>msg.data2;
    	d3=>msg.data3;
    	mout.send(msg);
    }
    	

    fun void lights(MidiOut mout){
    	send(mout,0x90,ctrlCCs[0],recOffColor);
    	send(mout,0x90,ctrlCCs[1],clearOffColor);
    	if(muted)
    		send(mout,0x90,ctrlCCs[2],muteColor);
    	else
    		send(mout,0x90,ctrlCCs[2],notMuteColor);
    }
    
    fun void blinkRec(MidiOut mout, int cc){
        MidiMsg msg;
        144=>msg.data1;
        cc=>msg.data2;
        while(true){
            recOnColor => msg.data3;
            if(focus)
            	mout.send(msg);
            blinkDur=>now;
            recOffColor => msg.data3;
            if(focus)
            	mout.send(msg);
            blinkDur=>now;
        }
    }
    
    fun void clrButton(MidiBroadcaster mB, MidiOut mout, int cc){
        MidiMsg msg;
        while(mB.mev=>now){
        	if(focus){
            	mB.mev.msg @=> msg;
            	if(msg.data2 == cc){
            		if(msg.data1 == 0x90 ){
                    	if(blinkRecShred.running())blinkRecShred.exit();
                        clear();
                        clearOnColor=>msg.data3;
                        mout.send(msg);
                	}else if(msg.data1 == 0x80){ 
                		0x90=>msg.data1;
                    	clearOffColor=>msg.data3;
                    	mout.send(msg);
                	}
            	}
        	}
        }
    }    

    fun void muteButton(MidiBroadcaster mB, MidiOut mout, int cc){
        MidiMsg msg;

        while(mB.mev=>now){
        	if(focus){
            	mB.mev.msg @=> msg;
            	if(msg.data1 == 0x90 ){
                	if(msg.data2 == cc){
                    	if(mute(!mute())){
                        	muteColor => msg.data3;
                        	mout.send(msg);
                    	}
                    	else{ 
                        	notMuteColor => msg.data3;
                        	mout.send(msg);
                    	}
                	}
            	}
        	}
    	}
	}

    fun void addMsg(MidiMsg msg){
    	if(focus){
        	if(msg.data1 == 0x90 | msg.data1 == 0x80){
            	if(!(msg.data2 == ctrlCCs[0] | msg.data2 == ctrlCCs[1] | msg.data2 == ctrlCCs[2] )){
                	//chout<=newMsg.data2<=IO.nl();
                	copyMsg(msg)@=>MidiMsg newMsg;
                	if(recording){
                    	now-delta=>newMsg.when;
                    	now=>delta;
                    	msgs<<newMsg;
                	}
            	}
        	}
        }
    }
    
    fun MidiMsg copyMsg(MidiMsg msg){
    	MidiMsg newMsg;
    	msg.data1=>newMsg.data1;
    	msg.data2=>newMsg.data2;
    	msg.data3=>newMsg.data3;
    	return newMsg;
    }

    fun void addDbMsg(MidiMsg msg){
    	now=>dbPre;
    	msg@=>dbMsg;
    }

    fun void record(){
        recordShred.exit();
        spork~_record()@=>recordShred;
    }

    fun void _record(){
    	1=>waitingForDownbeat;
        downbeat => now;
        0=>waitingForDownbeat;
        //chout<="Downbeat reached..."<=IO.nl();
        playShred.exit();
        msgs.clear();
        1=>recording;
        now=>delta;
        if(dbMsg.data1){
        	now-dbPre=>dbDur;
        	addMsg(dbMsg);
        	0=>dbMsg.data1;
        }
        else 0::samp=>dbDur;
    }

    fun void clear(){
        stopShred.exit();
        playShred.exit();
        msgs.clear();
        while(playShred.running())samp=>now;
        0=>recording;
    }

    fun int mute(){return muted;}
    fun int mute(int m){
        if(m)1=>muted;
        else 0=>muted;
        return muted;
    }

    fun void downbeatLoop(){
        while(clockEvent=>now){
            while(clockEvent.nextMsg()){
                clockEvent.getFloat()$int % (clockDiv)=>int i;
                if(!i){
                    downbeat.broadcast();
                }
            }
        }
    }

    fun void stop(){
        if(stopShred.running())stopShred.exit();
        spork~_stop()@=>stopShred;
    }

    fun void _stop(){
        downbeat => now;
        if(playShred.running())playShred.exit();
        if(recording){
            0=>recording;
            now-delta=>stopDur;
            //chout<="Playing..."<=IO.nl();
            spork~play()@=>playShred;
            //chout<=playShred.running()<=IO.nl();
        }
        while(samp=>now);
    }


    fun void play(){
        //chout<="Play function"<=IO.nl();
        //chout<=msgs.cap()<=IO.nl();
        while(true){
            for(int i;i<msgs.cap();i++){
                //chout<=msgs[i].when/samp<=IO.nl();
                msgs[i].when=>now;
                msgs[i]@=>curMsg.msg;
                //<<<curMsg.msg.data2>>>;
                if(!muted){
                    curMsg.broadcast();
                }
                if(clearFlag){
                    msgs.clear();
                    0=>clearFlag;
                    break;
                }
            }
            //stopDur=>now;
            downbeat=>now;
        }
    }
}

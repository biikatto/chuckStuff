Quicksort bs;
int a[];
bs.init(32)@=>a;
bs.audioMode(1);
bs.audioDelay(20::ms);
bs.shuffle(a);
bs.sort(a,1)@=>a;
bs.printArray(a);
public class _ {
    fun static int[] repeated(int in[], int repetions) {
        in.size()*repetions => int outSize;
        int out[ outSize];
        for(int i; i< outSize; i++) {
            in[i%in.size()] => out[i];
        }
        return out;
    }

    fun static int[] concat(int in[][]) {
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
}


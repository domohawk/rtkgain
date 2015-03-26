#include <stdlib.h>
#include <string.h>
#include <lvtk/plugin.hpp>
#include "lv2/lv2plug.in/ns/lv2core/lv2.h"
#include "rtkgain.h"

using namespace lvtk;

class RtkFil : public Plugin<RtkFil> {
public:
    RtkFil(double rate)
        : Plugin<RtkFil>(5) {
    }
    void run(uint32_t nframes) {
        float gain = *p(RTKGAIN_GAIN);
        for (uint32_t j=0; j<nframes; j++) {
            p(RTKGAIN_AUDIO_OUT_0)[j] = p(RTKGAIN_AUDIO_IN_0)[j] * gain;
            p(RTKGAIN_AUDIO_OUT_1)[j] = p(RTKGAIN_AUDIO_IN_1)[j] * gain;
        }
    }
};

static int my_desc_num = RtkFil::register_class("http://github.com/domohawk/lv2/rtkgain#rtkgain");

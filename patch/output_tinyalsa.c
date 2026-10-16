/*
 *  Squeezelite - lightweight headless squeezebox emulator
 *
 *  (c) Adrian Smith 2012-2015, triode1@btinternet.com
 *      Ralph Irving 2015-2021, ralph_irving@hotmail.com
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Output using TinyALSA with EVL real-time functions

#define _GNU_SOURCE
#include "squeezelite.h"

#if TINYALSA

#include <tinyalsa/asoundlib.h>
#include <sys/mman.h>
#include <malloc.h>
#include <math.h>
#include <evl/mutex.h>
#include <evl/thread.h>
#include <evl/sched.h>
#include <evl/evl.h>

/*
 * EVL real-time build: requires squeezelite.h mutex_type == struct evl_mutex.
 * The output thread attaches to EVL for real-time scheduling and uses
 * evl_usleep() for precise sleeps. TinyALSA calls remain in-band.
 */

#define MAX_DEVICE_LEN 128

static enum pcm_format fmts[] = {
	PCM_FORMAT_S32_LE, PCM_FORMAT_S24_LE,
	PCM_FORMAT_S24_3LE, PCM_FORMAT_S16_LE,
	PCM_FORMAT_INVALID
};

#if SL_LITTLE_ENDIAN
#define NATIVE_FORMAT PCM_FORMAT_S32_LE
#else
#define NATIVE_FORMAT PCM_FORMAT_S32_BE
#endif

static struct {
	char device[MAX_DEVICE_LEN + 1];
	unsigned int card;
	unsigned int device_num;
	char *ctl;
	char *mixer_ctl;
	enum pcm_format format;
#if DSD
	dsd_format outfmt;
	enum pcm_format pcmfmt;
#endif
	unsigned int buffer_size;
	unsigned int period_size;
	unsigned rate;
	bool mmap;
	bool reopen;
	u8_t *write_buf;
	const char *volume_mixer_name;
	bool mixer_linear;
	struct mixer_ctl *mixer_elem;
	struct mixer *mixer_handle;
	long mixer_min;
	long mixer_max;
} tinyalsa;

static struct pcm *pcmp = NULL;

extern int pcm_state(struct pcm *pcm);

extern u8_t *silencebuf;
#if DSD
extern u8_t *silencebuf_dsd;
#endif

static log_level loglevel;

static bool running = true;

/* rt_priority stored for the output thread to set its own EVL scheduling */
static unsigned output_rt_priority;

extern struct outputstate output;
extern struct buffer *outputbuf;

/* EVL mutex wrappers - mutex_type must be struct evl_mutex in squeezelite.h */
#define LOCK   evl_lock_mutex(&outputbuf->mutex)
#define UNLOCK evl_unlock_mutex(&outputbuf->mutex)

static void parse_card_device(const char *device, unsigned int *card, unsigned int *dev) {
	*card = 0;
	*dev = 0;
	if (!device) return;
	if (sscanf(device, "hw:%u,%u", card, dev) == 2) return;
	if (sscanf(device, "hw:%u", card) == 1) return;
	if (sscanf(device, "%u,%u", card, dev) == 2) return;
	if (sscanf(device, "%u", card) == 1) return;
}

static char *ctl4device(const char *device) {
	char *ctl = NULL;

	if (!strncmp(device, "hw:", 3))
		ctl = strdup(device);
	else if (!strncmp(device, "plughw:", 7))
		ctl = strdup(device + 4);

	if (ctl) {
		char *comma;
		if ((comma = strrchr(ctl, ',')))
			*comma = '\0';
	} else {
		ctl = strdup(device);
	}

	return ctl;
}

void list_devices(void) {
	printf("Output devices (TinyALSA):\n");
	FILE *f = fopen("/proc/asound/cards", "r");
	if (f) {
		char line[256];
		while (fgets(line, sizeof(line), f)) {
			printf("  %s", line);
		}
		fclose(f);
	} else {
		printf("  hw:0,0\n");
	}
	printf("\n");
}

void list_mixers(const char *output_device) {
	unsigned int card = 0, dev = 0;
	parse_card_device(output_device, &card, &dev);

	struct mixer *handle = mixer_open(card);
	if (!handle) {
		LOG_ERROR("unable to open mixer for card %u", card);
		return;
	}

	printf("Volume controls for %s (card %u):\n", output_device, card);
	unsigned int num_ctls = mixer_get_num_ctls(handle);
	for (unsigned int i = 0; i < num_ctls; i++) {
		struct mixer_ctl *ctl = mixer_get_ctl(handle, i);
		if (ctl) {
			printf("   %s (%s)\n", mixer_ctl_get_name(ctl), mixer_ctl_get_type_string(ctl));
		}
	}
	printf("\n");

	mixer_close(handle);
}

#define MINVOL_DB 72

static void set_mixer(bool setmax, float ldB, float rdB) {
	if (!tinyalsa.mixer_elem) return;

	long range = tinyalsa.mixer_max - tinyalsa.mixer_min;
	long lraw, rraw;

	if (setmax) {
		lraw = rraw = tinyalsa.mixer_max;
	} else if (tinyalsa.mixer_linear) {
		lraw = (long)((ldB > -MINVOL_DB ? MINVOL_DB + floor(ldB) : 0) / MINVOL_DB * range) + tinyalsa.mixer_min;
		rraw = (long)((rdB > -MINVOL_DB ? MINVOL_DB + floor(rdB) : 0) / MINVOL_DB * range) + tinyalsa.mixer_min;
	} else {
		float lpct = (ldB > -MINVOL_DB) ? (MINVOL_DB + ldB) / MINVOL_DB : 0.0f;
		float rpct = (rdB > -MINVOL_DB) ? (MINVOL_DB + rdB) / MINVOL_DB : 0.0f;
		lpct = (lpct < 0.0f) ? 0.0f : (lpct > 1.0f) ? 1.0f : lpct;
		rpct = (rpct < 0.0f) ? 0.0f : (rpct > 1.0f) ? 1.0f : rpct;
		lraw = (long)(lpct * range) + tinyalsa.mixer_min;
		rraw = (long)(rpct * range) + tinyalsa.mixer_min;
	}

	unsigned int num_values = mixer_ctl_get_num_values(tinyalsa.mixer_elem);
	if (num_values > 0) {
		mixer_ctl_set_value(tinyalsa.mixer_elem, 0, (int)lraw);
		if (num_values > 1) {
			mixer_ctl_set_value(tinyalsa.mixer_elem, 1, (int)rraw);
		}
	}
}

void set_volume(unsigned left, unsigned right) {
	if (!tinyalsa.volume_mixer_name) {
		LOCK;
		output.gainL = left;
		output.gainR = right;
		UNLOCK;
		return;
	}

	LOCK;
	output.gainL = FIXED_ONE;
	output.gainR = FIXED_ONE;
	UNLOCK;

	float ldB = 20 * log10f(left  / 65536.0F);
	float rdB = 20 * log10f(right / 65536.0F);
	set_mixer(false, ldB, rdB);
}

static void tinyalsa_close(void) {
	if (pcmp) {
		pcm_close(pcmp);
		pcmp = NULL;
	}
}

bool test_open(const char *device, unsigned rates[], bool userdef_rates) {
	unsigned int card = 0, dev = 0;
	parse_card_device(device, &card, &dev);

	struct pcm_config config;
	memset(&config, 0, sizeof(config));
	config.channels = 2;
	config.rate = 44100;
	config.period_size = 1024;
	config.period_count = 4;

	struct pcm *pcm = NULL;
	bool success = false;
	enum pcm_format *fmt = fmts;

	while (*fmt != PCM_FORMAT_INVALID) {
		config.format = *fmt;
		pcm = pcm_open(card, dev, PCM_OUT, &config);
		if (pcm && pcm_is_ready(pcm)) {
			success = true;
			pcm_close(pcm);
			break;
		}
		if (pcm) {
			pcm_close(pcm);
			pcm = NULL;
		}
		fmt++;
	}

	if (!success) {
		struct pcm_params *params = pcm_params_get(card, dev, PCM_OUT);
		if (params) {
			success = true;
			pcm_params_free(params);
		}
	}

	if (!success) {
		LOG_ERROR("test_open failed for device %s (card %u, dev %u)", device, card, dev);
		return false;
	}

	if (!userdef_rates) {
		unsigned ref[] TEST_RATES;
		unsigned i, ind = 0;
		struct pcm_params *params = pcm_params_get(card, dev, PCM_OUT);
		if (params) {
			unsigned int min_rate = pcm_params_get_min(params, PCM_PARAM_RATE);
			unsigned int max_rate = pcm_params_get_max(params, PCM_PARAM_RATE);
			for (i = 0; ref[i]; ++i) {
				if (ref[i] >= min_rate && ref[i] <= max_rate) {
					rates[ind++] = ref[i];
				}
			}
			pcm_params_free(params);
		} else {
			for (i = 0; ref[i]; ++i) {
				rates[ind++] = ref[i];
			}
		}
	}

	return success;
}

static bool pcm_probe(const char *device) {
	unsigned int card = 0, dev = 0;
	parse_card_device(device, &card, &dev);

	struct pcm_config config;
	memset(&config, 0, sizeof(config));
	config.channels = 2;
	config.rate = 44100;
	config.period_size = 1024;
	config.period_count = 4;

	struct pcm *pcm = NULL;
	enum pcm_format *fmt = fmts;
	while (*fmt != PCM_FORMAT_INVALID) {
		config.format = *fmt;
		pcm = pcm_open(card, dev, PCM_OUT, &config);
		if (pcm && pcm_is_ready(pcm)) {
			pcm_close(pcm);
			return true;
		}
		if (pcm) pcm_close(pcm);
		fmt++;
	}

	struct pcm_params *params = pcm_params_get(card, dev, PCM_OUT);
	if (params) {
		pcm_params_free(params);
		return true;
	}

	return false;
}

/* Try to open PCM with a given set of flags; returns true on success. */
static bool try_pcm_open(unsigned int card, unsigned int dev,
                         unsigned int flags, struct pcm_config *config) {
	if (pcmp) {
		pcm_close(pcmp);
		pcmp = NULL;
	}
	pcmp = pcm_open(card, dev, flags, config);
	if (pcmp && pcm_is_ready(pcmp))
		return true;
	if (pcmp) {
		pcm_close(pcmp);
		pcmp = NULL;
	}
	return false;
}

#if DSD
static int tinyalsa_open(const char *device, unsigned sample_rate, unsigned alsa_buffer, unsigned alsa_period, dsd_format outfmt) {
#else
static int tinyalsa_open(const char *device, unsigned sample_rate, unsigned alsa_buffer, unsigned alsa_period) {
#endif
	if (pcmp) tinyalsa_close();

	tinyalsa.rate = 0;
#if DSD
	tinyalsa.outfmt = PCM;
#endif
	tinyalsa.period_size = 0;
	strncpy(tinyalsa.device, device, MAX_DEVICE_LEN);
	tinyalsa.device[MAX_DEVICE_LEN] = '\0';

	LOG_INFO("opening device %s at sample rate %u (TinyALSA EVL)", device, sample_rate);

	parse_card_device(device, &tinyalsa.card, &tinyalsa.device_num);

	struct pcm_config config;
	memset(&config, 0, sizeof(config));
	config.channels = 2;
	config.rate = sample_rate;

	unsigned int period_size, period_count;
	if (alsa_period < 50) {
		period_count = alsa_period ? alsa_period : 4;
		if (alsa_buffer < 500) {
			unsigned int total_frames = (sample_rate * alsa_buffer) / 1000;
			period_size = total_frames / period_count;
		} else {
			period_size = alsa_buffer / period_count;
		}
	} else {
		period_size = alsa_period;
		if (alsa_buffer < 500) {
			unsigned int total_frames = (sample_rate * alsa_buffer) / 1000;
			period_count = total_frames / period_size;
		} else {
			period_count = alsa_buffer / period_size;
		}
	}
	if (period_size > 16 && (period_size % 16 != 0))
		period_size = (period_size / 16) * 16;
	if (period_size == 0) period_size = 1024;
	if (period_count == 0) period_count = 4;

	config.period_size  = period_size;
	config.period_count = period_count;
	config.start_threshold = period_size;
	config.stop_threshold  = period_size * period_count;

#if DSD
	switch (outfmt) {
	case DSD_U8:      tinyalsa.format = PCM_FORMAT_S8;      break;
	case DSD_U16_LE:  tinyalsa.format = PCM_FORMAT_S16_LE;  break;
	case DSD_U16_BE:  tinyalsa.format = PCM_FORMAT_S16_BE;  break;
	case DSD_U32_LE:  tinyalsa.format = PCM_FORMAT_S32_LE;  break;
	case DSD_U32_BE:  tinyalsa.format = PCM_FORMAT_S32_BE;  break;
	case DOP_S24_LE:  tinyalsa.format = PCM_FORMAT_S24_LE;  break;
	case DOP_S24_3LE: tinyalsa.format = PCM_FORMAT_S24_3LE; break;
	default:          tinyalsa.format = tinyalsa.pcmfmt;    break;
	}
#endif

	enum pcm_format *fmt = (tinyalsa.format != PCM_FORMAT_INVALID) ? &tinyalsa.format : fmts;
	do {
		config.format = *fmt;

		/* Try: OOB + mmap → OOB no-mmap → in-band + mmap → in-band no-mmap */
		bool opened = false;
		if (tinyalsa.mmap) {
			opened = try_pcm_open(tinyalsa.card, tinyalsa.device_num,
			                      PCM_OUT | PCM_OOB | PCM_MMAP, &config);
			if (!opened) {
				opened = try_pcm_open(tinyalsa.card, tinyalsa.device_num,
				                      PCM_OUT | PCM_OOB, &config);
				if (opened) tinyalsa.mmap = false;
			}
			if (!opened) {
				opened = try_pcm_open(tinyalsa.card, tinyalsa.device_num,
				                      PCM_OUT | PCM_MMAP, &config);
			}
			if (!opened) {
				opened = try_pcm_open(tinyalsa.card, tinyalsa.device_num,
				                      PCM_OUT, &config);
				if (opened) tinyalsa.mmap = false;
			}
		} else {
			opened = try_pcm_open(tinyalsa.card, tinyalsa.device_num,
			                      PCM_OUT | PCM_OOB, &config);
			if (!opened)
				opened = try_pcm_open(tinyalsa.card, tinyalsa.device_num,
				                      PCM_OUT, &config);
		}

		if (opened) {
			tinyalsa.format = *fmt;
			LOG_INFO("opened device %u,%u format: %d sample rate: %u mmap: %u",
				tinyalsa.card, tinyalsa.device_num, tinyalsa.format, sample_rate, tinyalsa.mmap);
			break;
		}

		if (tinyalsa.format != PCM_FORMAT_INVALID) {
			LOG_ERROR("unable to open audio device with requested format %d", tinyalsa.format);
			return -1;
		}

		++fmt;
		if (*fmt == PCM_FORMAT_INVALID) {
			LOG_ERROR("unable to open audio device with any supported format");
			return -1;
		}
	} while (*fmt != PCM_FORMAT_INVALID);

	switch (tinyalsa.format) {
	case PCM_FORMAT_S32_LE:  output.format = S32_LE;  break;
	case PCM_FORMAT_S24_LE:  output.format = S24_LE;  break;
	case PCM_FORMAT_S24_3LE: output.format = S24_3LE; break;
	case PCM_FORMAT_S16_LE:  output.format = S16_LE;  break;
#if DSD
	case PCM_FORMAT_S32_BE:  output.format = U32_BE;  break;
	case PCM_FORMAT_S16_BE:  output.format = U16_BE;  break;
	case PCM_FORMAT_S8:      output.format = U8;       break;
#endif
	default: break;
	}

	tinyalsa.period_size = config.period_size;
	tinyalsa.buffer_size = config.period_size * config.period_count;

	LOG_INFO("buffer: %u period: %u -> buffer size: %u period size: %u",
		alsa_buffer, alsa_period, tinyalsa.buffer_size, tinyalsa.period_size);

	output.start_frames = tinyalsa.buffer_size;

	if (!tinyalsa.mmap && tinyalsa.format != NATIVE_FORMAT) {
		if (tinyalsa.write_buf) {
			free(tinyalsa.write_buf);
			tinyalsa.write_buf = NULL;
		}
		tinyalsa.write_buf = malloc(tinyalsa.buffer_size * BYTES_PER_FRAME);
		if (!tinyalsa.write_buf) {
			LOG_ERROR("unable to malloc write_buf");
			return -1;
		}
	}

	tinyalsa.rate = sample_rate;
#if DSD
	tinyalsa.outfmt = outfmt;
#endif

	return 0;
}

static int _write_frames(frames_t out_frames, bool silence, s32_t gainL, s32_t gainR,
						 s32_t cross_gain_in, s32_t cross_gain_out, s32_t **cross_ptr) {

	void *areas = NULL;
	unsigned int offset = 0;
	unsigned int alsa_frames = (unsigned int)out_frames;
	void *outputptr = NULL;
	s32_t *inputptr;
	int err;

	if (likely(tinyalsa.mmap)) {
		if (unlikely((err = pcm_mmap_begin(pcmp, &areas, &offset, &alsa_frames)) < 0)) {
			LOG_WARN("error from pcm_mmap_begin: %d", err);
			return -1;
		}
		out_frames = (frames_t)alsa_frames;
	}

	if (likely(!silence)) {
		if (unlikely(output.fade == FADE_ACTIVE && output.fade_dir == FADE_CROSS && *cross_ptr)) {
			_apply_cross(outputbuf, out_frames, cross_gain_in, cross_gain_out, cross_ptr);
		}
	}

	inputptr = (s32_t *)(silence ? silencebuf : outputbuf->readp);

	IF_DSD(
		if (output.outfmt != PCM) {
			if (silence) {
				inputptr = (s32_t *)silencebuf_dsd;
			}
			if (output.outfmt == DOP || output.outfmt == DOP_S24_LE || output.outfmt == DOP_S24_3LE)
				update_dop((u32_t *)inputptr, out_frames, output.invert && !silence);
			else if (output.invert && !silence)
				dsd_invert((u32_t *)inputptr, out_frames);
		}
	)

	if (likely(tinyalsa.mmap || tinyalsa.format != NATIVE_FORMAT)) {
		outputptr = tinyalsa.mmap ?
			((u8_t *)areas + pcm_frames_to_bytes(pcmp, offset)) :
			tinyalsa.write_buf;

		if (likely(tinyalsa.format == NATIVE_FORMAT && gainL == FIXED_ONE && gainR == FIXED_ONE)) {
			memcpy(outputptr, inputptr, out_frames * BYTES_PER_FRAME);
		} else {
			_scale_and_pack_frames(outputptr, inputptr, out_frames, gainL, gainR, output.format);
		}
	} else {
		outputptr = (void *)inputptr;

#if DSD
		if (likely(!silence && output.outfmt == PCM) && (gainL != FIXED_ONE || gainR != FIXED_ONE)) {
			_apply_gain(outputbuf, out_frames, gainL, gainR);
		}
#else
		if (likely(!silence) && (gainL != FIXED_ONE || gainR != FIXED_ONE)) {
			_apply_gain(outputbuf, out_frames, gainL, gainR);
		}
#endif
	}

	if (likely(tinyalsa.mmap)) {
		int w = pcm_mmap_commit(pcmp, offset, out_frames);
		if (unlikely(w < 0 || w != (int)out_frames)) {
			LOG_WARN("mmap_commit error: %d", w);
			return -1;
		}
	} else {
		int w = pcm_writei(pcmp, outputptr, out_frames);
		if (unlikely(w < 0)) {
			LOG_WARN("writei error: %d, preparing pcm", w);
			pcm_prepare(pcmp);
			return -1;
		}
		if (unlikely(w != (int)out_frames)) {
			LOG_WARN("writei only wrote %d of %u", w, (unsigned)out_frames);
		}
		out_frames = w;
	}

	return (int)out_frames;
}

static void *output_thread(void *arg) {
	bool start = true;
	bool output_off = (output.state == OUTPUT_OFF);
	bool probe_device = (arg != NULL);
	unsigned mmap_start_fail_cnt = 0;

	/* Attach this thread to EVL for real-time scheduling */
	pthread_setname_np(pthread_self(), "sqzl-output");
	int efd = evl_attach_self("squeezelite-output");
	if (efd < 0) {
		LOG_INFO("evl_attach_self failed: %s", strerror(-efd));
	} else if (output_rt_priority > 0) {
		struct evl_sched_attrs attrs = {
			.sched_policy   = SCHED_FIFO,
			.sched_priority = (int)output_rt_priority,
		};
		if (evl_set_schedattr(efd, &attrs) < 0) {
			LOG_INFO("unable to set EVL sched FIFO: %s", strerror(errno));
		}
	}

	while (running) {

		/* disabled output - player is off */
		while (unlikely(output_off)) {
			usleep(100000);
			LOCK;
			output_off = (output.state == OUTPUT_OFF);
			UNLOCK;
			if (!running) return 0;
		}

		/* wait until device returns */
		if (unlikely(probe_device)) {
			while (!pcm_probe(output.device)) {
				usleep(5000000);
			}
			probe_device = false;
		}

		/* Check if device open / rate switch is needed.
		 * LOCK is held only to snapshot the rate fields; tinyalsa_open()
		 * itself is called outside the lock (matching output_alsa.c pattern)
		 * so the long open sequence does not stall the decode thread. */
#if DSD
		if (unlikely(!pcmp || tinyalsa.rate != output.current_sample_rate || tinyalsa.outfmt != output.outfmt)) {
#else
		if (unlikely(!pcmp || tinyalsa.rate != output.current_sample_rate)) {
#endif

			LOG_INFO("open output device: %s", output.device);
			LOCK;

			if (tinyalsa.reopen) {
#if DSD
				tinyalsa_open(output.device, output.current_sample_rate, output.buffer, output.period, output.outfmt);
#else
				tinyalsa_open(output.device, output.current_sample_rate, output.buffer, output.period);
#endif
			}
#if DSD
			if (!!tinyalsa_open(output.device, output.current_sample_rate, output.buffer, output.period, output.outfmt)) {
#else
			if (!!tinyalsa_open(output.device, output.current_sample_rate, output.buffer, output.period)) {
#endif
				output.error_opening = true;
				UNLOCK;
				usleep(5000000);
				continue;
			}
			output.error_opening = false;
			start = true;
			mmap_start_fail_cnt = 0;
			UNLOCK;
		}

		int st = pcm_state(pcmp);

		if (unlikely(st == PCM_STATE_XRUN)) {
			LOG_INFO("XRUN");
			pcm_prepare(pcmp);
			start = true;
			continue;
		}

		int avail = tinyalsa.mmap ? pcm_mmap_avail(pcmp) : (int)tinyalsa.period_size;

		if (unlikely(avail < 0)) {
			LOG_WARN("avail update error: %d, preparing pcm", avail);
			pcm_prepare(pcmp);
			start = true;
			continue;
		}

		if (avail < (int)tinyalsa.period_size) {
			if (start) {
				if (likely(tinyalsa.mmap)) {
					/* Only call pcm_start if hardware is not already running.
					 * pcm_wait can return early for EVL OOB threads without
					 * the device actually stopping; setting start=true in that
					 * case causes pcm_start to fail with EBUSY and spin. */
					int cur_st = pcm_state(pcmp);
					if (cur_st != PCM_STATE_RUNNING) {
						if (pcm_start(pcmp) < 0) {
							mmap_start_fail_cnt++;
							LOG_WARN("pcm_start failed attempt %u (state=%d): %s",
								mmap_start_fail_cnt, cur_st, pcm_get_error(pcmp));
							if (mmap_start_fail_cnt >= 3) {
								LOG_INFO("mmap pcm_start failed %u times, switching to non-mmap", mmap_start_fail_cnt);
								tinyalsa.mmap = false;
								tinyalsa_close();
								mmap_start_fail_cnt = 0;
							} else {
								pcm_prepare(pcmp);
								usleep(10000);
							}
							continue;
						}
						mmap_start_fail_cnt = 0;
					}
					/* hardware is running (auto-started or just started) */
				}
				start = false;
			} else {
				usleep(10000);
				if (pcm_wait(pcmp, 1000) <= 0) {
					/* only mark for restart if device is not already running;
					 * pcm_wait can return early for EVL OOB threads without
					 * the device actually stopping */
					if (pcm_state(pcmp) != PCM_STATE_RUNNING) {
						LOG_INFO("pcm wait timeout/error");
						pcm_prepare(pcmp);
						start = true;
					}
				}
			}
			continue;
		}

		/* restrict avail to sensible limits */
		avail = tinyalsa.mmap
			? min(avail, (int)tinyalsa.buffer_size)
			: min(avail, (int)tinyalsa.period_size);

		if (unlikely(avail == 0)) {
			usleep(10000);
			continue;
		}

		LOCK;

		if (unlikely(output.state == OUTPUT_OFF)) {
			UNLOCK;
			LOG_INFO("disabling output");
			tinyalsa_close(); /* sets pcmp = NULL */
			output_off = true;

			continue;
		}

		/* pcm_get_delay() returns frames of latency, or negative on error.
		 * TinyALSA returns a plain long - not POSIX errno - so we treat any
		 * negative value as "not available" and fall back to a buffer-size
		 * estimate.  output.updated must always be refreshed here so that
		 * LMS time-sync is accurate even when delay is unknown. */
		long delay = pcm_get_delay(pcmp);
		if (unlikely(delay < 0)) {
			/* driver does not support pcm_get_delay; estimate from buffer */
			output.device_frames = tinyalsa.buffer_size;
		} else {
			output.device_frames = (unsigned int)delay;
		}
		output.updated           = evl_gettime_ms();
		output.frames_played_dmp = output.frames_played;

		bool idle = (output.state == OUTPUT_STOPPED);
		frames_t wrote = _output_frames((frames_t)avail);

		UNLOCK;

		if (unlikely(!wrote)) {
			usleep(10000);
		} else if (idle) {
			/* throttle silence writes in STOPPED state - mmap commits are
			 * non-blocking so without this the EVL RT thread spins at
			 * full CPU while filling the ring buffer with silence */
			usleep(10000);
		}

		/* non-mmap: manual pcm_start after first successful write if
		 * the driver does not auto-start via start_threshold */
		if (unlikely(start) && !tinyalsa.mmap && wrote > 0) {
			int cur_st = pcm_state(pcmp);
			if (cur_st != PCM_STATE_RUNNING) {
				if (pcm_start(pcmp) < 0) {
					LOG_WARN("non-mmap pcm_start failed (state=%d): %s", cur_st, pcm_get_error(pcmp));
				} else {
					LOG_INFO("non-mmap pcm_start succeeded (state was %d)", cur_st);
				}
			}
			start = false;
		}
	}

	return 0;
}

int mixer_init_tinyalsa(const char *device, const char *mixer, int mixer_index) {
	unsigned int card = 0, dev = 0;
	parse_card_device(device, &card, &dev);

	tinyalsa.mixer_handle = mixer_open(card);
	if (!tinyalsa.mixer_handle) {
		LOG_ERROR("open error for mixer card %u", card);
		return -1;
	}

	if (mixer_index > 0) {
		tinyalsa.mixer_elem = mixer_get_ctl_by_name_and_index(tinyalsa.mixer_handle, mixer, mixer_index);
	} else {
		tinyalsa.mixer_elem = mixer_get_ctl_by_name(tinyalsa.mixer_handle, mixer);
	}

	if (!tinyalsa.mixer_elem) {
		LOG_ERROR("error find selem %s", mixer);
		mixer_close(tinyalsa.mixer_handle);
		tinyalsa.mixer_handle = NULL;
		return -1;
	}

	tinyalsa.mixer_min = mixer_ctl_get_range_min(tinyalsa.mixer_elem);
	tinyalsa.mixer_max = mixer_ctl_get_range_max(tinyalsa.mixer_elem);

	return 0;
}

static pthread_t thread;

void output_init_tinyalsa(log_level level, const char *device, unsigned output_buf_size, char *params,
		unsigned rates[], unsigned rate_delay, unsigned rt_priority, unsigned idle,
		char *mixer_device, char *volume_mixer, bool mixer_unmute, bool mixer_linear) {

	unsigned alsa_buffer = ALSA_BUFFER_TIME;
	unsigned alsa_period = ALSA_PERIOD_COUNT;
	char *alsa_sample_fmt = NULL;
	bool alsa_mmap = true;
	bool alsa_reopen = false;

	char *volume_mixer_name  = next_param(volume_mixer, ',');
	char *volume_mixer_index = next_param(NULL, ',');

	char *t = next_param(params, ':');
	char *c = next_param(NULL, ':');
	char *s = next_param(NULL, ':');
	char *m = next_param(NULL, ':');
	char *r = next_param(NULL, ':');

	if (t) alsa_buffer     = atoi(t);
	if (c) alsa_period     = atoi(c);
	if (s) alsa_sample_fmt = s;
	if (m) alsa_mmap       = atoi(m);
	if (r) alsa_reopen     = atoi(r);

	loglevel = level;

	LOG_INFO("init output tinyalsa");

	memset(&output, 0, sizeof(output));

	tinyalsa.mmap         = alsa_mmap;
	tinyalsa.write_buf    = NULL;
#if DSD
	tinyalsa.pcmfmt = PCM_FORMAT_INVALID;
#else
	tinyalsa.format = PCM_FORMAT_INVALID;
#endif
	tinyalsa.reopen       = alsa_reopen;
	tinyalsa.mixer_handle = NULL;
	tinyalsa.ctl          = ctl4device(device);
	tinyalsa.mixer_ctl    = mixer_device ? ctl4device(mixer_device) : tinyalsa.ctl;
	tinyalsa.volume_mixer_name = volume_mixer_name;
	tinyalsa.mixer_linear = mixer_linear;

	output.format       = 0;
	output.buffer       = alsa_buffer;
	output.period       = alsa_period;
	output.start_frames = 0;
	output.write_cb     = &_write_frames;
	output.rate_delay   = rate_delay;

	if (alsa_sample_fmt) {
#if DSD
		if (!strcmp(alsa_sample_fmt, "32"))    tinyalsa.pcmfmt = PCM_FORMAT_S32_LE;
		if (!strcmp(alsa_sample_fmt, "24"))    tinyalsa.pcmfmt = PCM_FORMAT_S24_LE;
		if (!strcmp(alsa_sample_fmt, "24_3"))  tinyalsa.pcmfmt = PCM_FORMAT_S24_3LE;
		if (!strcmp(alsa_sample_fmt, "16"))    tinyalsa.pcmfmt = PCM_FORMAT_S16_LE;
#else
		if (!strcmp(alsa_sample_fmt, "32"))    tinyalsa.format = PCM_FORMAT_S32_LE;
		if (!strcmp(alsa_sample_fmt, "24"))    tinyalsa.format = PCM_FORMAT_S24_LE;
		if (!strcmp(alsa_sample_fmt, "24_3"))  tinyalsa.format = PCM_FORMAT_S24_3LE;
		if (!strcmp(alsa_sample_fmt, "16"))    tinyalsa.format = PCM_FORMAT_S16_LE;
#endif
	}

	LOG_INFO("requested alsa_buffer: %u alsa_period: %u format: %s mmap: %u",
		output.buffer, output.period, alsa_sample_fmt ? alsa_sample_fmt : "any", tinyalsa.mmap);

	output_init_common(level, device, output_buf_size, rates, idle);

	if (volume_mixer_name) {
		if (mixer_init_tinyalsa(tinyalsa.mixer_ctl, tinyalsa.volume_mixer_name,
				volume_mixer_index ? atoi(volume_mixer_index) : 0) < 0) {
			LOG_ERROR("Initialization of mixer failed, reverting to software volume");
			tinyalsa.mixer_handle = NULL;
			tinyalsa.volume_mixer_name = NULL;
		}
	}
	if (mixer_unmute && tinyalsa.volume_mixer_name) {
		set_mixer(true, 0, 0);
		tinyalsa.volume_mixer_name = NULL;
	}

	/* Lock all current and future memory pages to prevent page faults in RT */
	if (mlockall(MCL_CURRENT | MCL_FUTURE) == -1) {
		LOG_INFO("unable to lock memory: %s", strerror(errno));
	} else {
		LOG_INFO("memory locked");
	}

#ifdef __GLIBC__
	mallopt(M_TRIM_THRESHOLD, -1);
	mallopt(M_MMAP_MAX, 0);
#endif

	touch_memory(silencebuf, MAX_SILENCE_FRAMES * BYTES_PER_FRAME);
	touch_memory(outputbuf->buf, outputbuf->size);

	/* Store rt_priority for the output thread to set EVL scheduling */
	output_rt_priority = rt_priority;

	pthread_attr_t attr;
	pthread_attr_init(&attr);
	if (rt_priority > 0) {
		struct sched_param sp = { .sched_priority = (int)rt_priority };
		pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
		pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
		pthread_attr_setschedparam(&attr, &sp);
	}
	pthread_attr_setstacksize(&attr, PTHREAD_STACK_MIN + OUTPUT_THREAD_STACK_SIZE);
	if (pthread_create(&thread, &attr, output_thread, rates[0] ? "probe" : NULL)) {
		pthread_attr_setinheritsched(&attr, PTHREAD_INHERIT_SCHED);
		pthread_create(&thread, &attr, output_thread, rates[0] ? "probe" : NULL);
	}
	pthread_attr_destroy(&attr);
}

void output_close_tinyalsa(void) {
	LOG_INFO("close output tinyalsa");

	LOCK;
	running = false;
	UNLOCK;

	pthread_join(thread, NULL);

	if (tinyalsa.write_buf) free(tinyalsa.write_buf);
	if (tinyalsa.ctl) free(tinyalsa.ctl);
	if (tinyalsa.mixer_ctl && tinyalsa.mixer_ctl != tinyalsa.ctl) free(tinyalsa.mixer_ctl);
	if (tinyalsa.mixer_handle) mixer_close(tinyalsa.mixer_handle);

	output_close_common();
}

#endif // TINYALSA
